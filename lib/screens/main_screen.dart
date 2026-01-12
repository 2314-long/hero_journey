import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'login_screen.dart';

// Import Models
import '../models/item.dart';
import '../models/task.dart';

// Import Widgets and Services
import '../widgets/shake_widget.dart';
import '../widgets/game_dialogs.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_tile.dart';
import '../widgets/shop_page.dart';
// import '../widgets/status_header.dart'; // Deprecated
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart'; // InventoryItem should be available here or in models

import '../widgets/battle_header.dart';
import 'profile_screen.dart'; // 🔥 Ensure lib/screens/profile_screen.dart exists!

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  // --- State Variables ---
  int currentHp = 100;
  int maxHp = 100;
  int gold = 0;
  bool _showDamageFlash = false;

  // 🔥 [New] Avatar URL
  String avatarUrl = "";

  final Map<String, bool> _sectionExpandedState = {
    "进行中": true,
    "已过期": true,
    "已完成": false,
  };

  // 🔥 Key for BattleHeader
  final GlobalKey<BattleHeaderState> _bossKey = GlobalKey<BattleHeaderState>();

  bool hasResurrectionCross = false;
  bool hasSword = false;
  bool hasShield = false;

  // Inventory list
  List<InventoryItem> inventory = [];

  int level = 1;
  int currentXp = 0;
  int get maxXp => level * 100;

  List<Task> tasks = [];

  // --- Controllers ---
  Timer? _timer;
  int _selectedIndex = 0;
  late ConfettiController _controllerLeft;
  late ConfettiController _controllerRight;
  late AnimationController _shakeController;

  bool _isGameOverProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    NotificationService().requestPermissions();

    _controllerLeft = ConfettiController(duration: const Duration(seconds: 1));
    _controllerRight = ConfettiController(duration: const Duration(seconds: 1));

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkOverdueAndPunish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controllerLeft.dispose();
    _controllerRight.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _saveData() {
    StorageService().saveData(
      hp: currentHp,
      maxHp: maxHp,
      gold: gold,
      level: level,
      currentXp: currentXp,
      hasCross: hasResurrectionCross,
      tasks: tasks,
    );
    ApiService().syncStats(level, gold, currentXp, currentHp, maxHp);
  }

  Future<void> _loadData() async {
    // 1. 加载本地数据
    final data = StorageService().loadData();

    // 2. 加载网络数据
    final apiTasks = await ApiService().fetchTasks();
    final apiStats = await ApiService().fetchStats();
    final apiInventory = await ApiService().fetchInventory();

    if (!mounted) return;

    setState(() {
      // --- 更新属性 ---
      if (apiStats != null) {
        level = apiStats['level'];
        gold = apiStats['gold'];
        currentXp = apiStats['xp'];
        currentHp = apiStats['hp'];
        maxHp = apiStats['max_hp'];
        avatarUrl = apiStats['avatar_url'] ?? "";
      } else {
        currentHp = data['hp'];
        maxHp = data['maxHp'];
        gold = data['gold'];
        level = data['level'];
        currentXp = data['currentXp'];
      }

      // --- 更新背包 ---
      this.inventory = apiInventory;

      bool foundCross = false;
      bool foundSword = false;
      bool foundShield = false;

      print("📦 --- 开始检查背包 (共 ${apiInventory.length} 个物品) ---");
      for (var item in apiInventory) {
        // 打印每个物品的信息，方便调试
        print(
          "物品: ${item.item.name}, 效果: ${item.item.effectType}, 数量: ${item.quantity}, 已装备: ${item.isEquipped}",
        );

        // 🔥 1. 严格判断 RESURRECT
        if (item.item.effectType == 'RESURRECT' && item.quantity > 0) {
          foundCross = true;
          print("✅ 找到复活十字架！");
        }

        // 2. 剑 (攻击类 + 已装备)
        if (item.isEquipped && item.item.effectType == 'GOLD_BOOST') {
          foundSword = true;
        }

        // 3. 盾 (防御类 + 已装备)
        if (item.isEquipped && item.item.effectType == 'DMG_REDUCE') {
          foundShield = true;
        }
      }
      print(
        "📦 --- 背包检查结束: Cross=$foundCross, Sword=$foundSword, Shield=$foundShield ---",
      );

      hasResurrectionCross = foundCross;
      hasSword = foundSword;
      hasShield = foundShield;

      // --- 更新任务 ---
      if (apiTasks.isNotEmpty) {
        tasks = apiTasks;
      } else {
        tasks = data['tasks'];
      }
    });
  }

  void _checkOverdueAndPunish() async {
    if (_isGameOverProcessing) return;
    bool hasChanged = false;

    for (var task in tasks) {
      if (!task.isDone && _isOverdue(task.deadline)) {
        if (!task.punished) {
          task.punished = true;
          hasChanged = true;
          await ApiService().updateTask(task);
        }
      }
    }

    if (hasChanged) {
      final oldHp = currentHp;
      await _loadData();

      if (currentHp < oldHp) {
        AudioService().playDamage();
        _bossKey.currentState?.attack();
        setState(() => _showDamageFlash = true);

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showDamageFlash = false);
        });

        if (mounted) {
          final damage = oldHp - currentHp;
          bool hasShield = inventory.any(
            (inv) => inv.isEquipped && inv.item.effectType == 'DMG_REDUCE',
          );
          String message = "⚠️ 任务过期！受到 $damage 点伤害";
          if (hasShield) message += " (护盾已生效)";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      if (currentHp <= 0) {
        _timer?.cancel();
        InventoryItem? revivalItem;
        try {
          revivalItem = inventory.firstWhere(
            (inv) =>
                (inv.item.effectType == 'RESURRECT' ||
                    inv.item.name == '复活十字架') &&
                inv.quantity > 0,
          );
        } catch (e) {
          revivalItem = null;
        }

        if (revivalItem != null) {
          _triggerResurrection(revivalItem);
        } else {
          _handleGameOver();
        }
      }
    }
  }

  void _triggerResurrection(InventoryItem item) {
    _isGameOverProcessing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("英雄倒下了..."),
        content: Text("检测到背包中有【${item.item.name}】，是否消耗 1 个进行复活？"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleGameOver();
            },
            child: const Text("放弃", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _useReviveItem(item);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
            ),
            child: const Text("立即复活"),
          ),
        ],
      ),
    );
  }

  Future<void> _useReviveItem(InventoryItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ApiService().useItem(item.id);
      await _loadData();
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (currentHp > 0) {
        setState(() => _isGameOverProcessing = false);
        _startTimer();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✨ 奇迹发生了！英雄已复活！"),
              backgroundColor: Colors.amber,
            ),
          );
      } else {
        throw "道具已使用，但生命值未恢复";
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 复活失败: $e")));
        _handleGameOver();
      }
    }
  }

  void _handleGameOver() {
    _timer?.cancel();
    _isGameOverProcessing = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => GameOverDialog(
        onRestart: () async {
          setState(() {
            currentHp = 100;
            maxHp = 100;
            gold = 0;
            level = 1;
            currentXp = 0;
            hasResurrectionCross = false;
            tasks.clear();
            _isGameOverProcessing = false;
          });
          _saveData();
          _startTimer();
        },
      ),
    );
  }

  void _checkLevelUp() {
    AudioService().playSuccess();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.indigo.shade900,
        title: const Center(
          child: Text(
            "🎉 升级！",
            style: TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 60),
            const SizedBox(height: 16),
            Text(
              "恭喜提升到 Lv.${level + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "生命上限 +10\nHP 已完全恢复",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                level++;
                currentXp = currentXp - maxXp;
                if (currentXp < 0) currentXp = 0;
                maxHp += 10;
                currentHp = maxHp;
                _controllerLeft.play();
                _controllerRight.play();
                AudioService().playLevelUp();
              });
              _saveData();
              _bossKey.currentState?.spawn();
            },
            child: const Text(
              "太棒了！",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void toggleTask(Task task) async {
    if (task.isDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚫 任务完成后不可撤销！"),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.grey,
        ),
      );
      setState(() => task.isDone = true);
      return;
    }
    if (task.deadline != null) {
      if (DateTime.now().isAfter(DateTime.parse(task.deadline!)) &&
          !task.isDone) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🚫 任务已过期，无法操作")));
        return;
      }
    }

    if (!task.isDone) {
      int reward = task.reward;
      if (currentXp + reward >= maxXp) {
        setState(() => currentXp += reward);
        AudioService().playSuccess();
        _bossKey.currentState?.die();
        setState(() {
          task.isDone = true;
          if (task.id != null)
            NotificationService().cancelNotification(task.id!);
        });
        await ApiService().updateTask(task);
        _saveData();
        return;
      } else {
        setState(() => currentXp += reward);
        AudioService().playSuccess();
        _bossKey.currentState?.hit(reward);
      }
    }

    final int oldLevel = level;
    final bool oldDoneState = task.isDone;
    final int oldXp = currentXp;
    final int oldHp = currentHp;

    setState(() {
      task.isDone = !task.isDone;
      if (task.isDone && task.id != null)
        NotificationService().cancelNotification(task.id!);
    });

    final success = await ApiService().updateTask(task);

    if (!success) {
      if (mounted) {
        setState(() {
          task.isDone = oldDoneState;
          currentXp = oldXp;
          currentHp = oldHp;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("⚠️ 同步失败，请检查网络")));
      }
    } else {
      await _loadData();
      if (level > oldLevel) {
        AudioService().playLevelUp();
        _controllerLeft.play();
        _controllerRight.play();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LevelUpDialog(level: level),
        );
      }
      _saveData();
    }
  }

  void _editTask(Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
          initialTitle: task.title,
          initialDeadline: (task.deadline == null || task.deadline!.isEmpty)
              ? null
              : DateTime.parse(task.deadline!),
          onSubmit: (title, deadline) {
            setState(() {
              task.title = title;
              task.deadline = deadline?.toIso8601String();
            });
            if (task.id != null) {
              NotificationService().cancelNotification(task.id!);
              if (deadline != null)
                NotificationService().scheduleNotification(
                  task.id!,
                  title,
                  deadline,
                );
            }
            ApiService().updateTask(task);
            _saveData();
          },
        );
      },
    );
  }

  void _addTask() {
    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
          onSubmit: (title, deadline) async {
            int tempId = DateTime.now().millisecondsSinceEpoch;
            final tempTask = Task(
              id: tempId,
              title: title,
              deadline: deadline?.toIso8601String(),
              reward: 100,
            );
            setState(() => tasks.add(tempTask));
            final serverTask = await ApiService().createTask(
              title,
              deadline?.toIso8601String(),
            );

            if (serverTask != null && mounted) {
              setState(() {
                tasks.removeWhere((t) => t.id == tempId);
                tasks.add(serverTask);
              });
              _saveData();
              if (deadline != null)
                NotificationService().scheduleNotification(
                  serverTask.id!,
                  title,
                  deadline,
                );
            } else {
              if (mounted) {
                setState(() => tasks.removeWhere((t) => t.id == tempId));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("❌ 创建失败，请检查网络")));
              }
            }
          },
        );
      },
    );
  }

  Future<void> _testBackendConnection() async {
    try {
      await ApiService().fetchTasks();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ 后端连接成功")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 连接失败: $e")));
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("确认删除"),
            content: const Text("确定要放弃这个挑战吗？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("删除"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _performDelete(Task task) async {
    setState(() => tasks.remove(task));
    if (task.id != null) {
      NotificationService().cancelNotification(task.id!);
      await ApiService().deleteTask(task.id!);
    }
    _saveData();
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      return DateTime.now().isAfter(DateTime.parse(dateStr));
    } catch (e) {
      return false;
    }
  }

  void _showDebugResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("调试"),
        content: const Text("重置为 Lv.1 状态？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                level = 1;
                currentHp = 100;
                maxHp = 100;
                currentXp = 0;
                _isGameOverProcessing = false;
                _startTimer();
              });
              _saveData();
            },
            child: const Text("重置"),
          ),
        ],
      ),
    );
  }

  // --- 🔥 [Modified] Battle Page Widget ---
  Widget _buildBattlePage() {
    final List<Task> overdue = [];
    final List<Task> active = [];
    final List<Task> completed = [];

    for (var task in tasks) {
      if (task.isDone)
        completed.add(task);
      else if (_isOverdue(task.deadline))
        overdue.add(task);
      else
        active.add(task);
    }

    int sortTime(Task a, Task b) {
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    }

    active.sort(sortTime);
    overdue.sort(sortTime);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80, top: 0),
      children: [
        BattleHeader(
          key: _bossKey,
          level: level,
          currentHp: currentHp,
          maxHp: maxHp,
          gold: gold,
          hasResurrectionCross: hasResurrectionCross,
          hasSword: hasSword,
          hasShield: hasShield,
          currentXp: currentXp,
          maxXp: maxXp,
          onChestTap: _checkLevelUp,

          // 🔥 [New] Pass Avatar URL
          avatarUrl: avatarUrl,

          // 🔥 [New] Tap to switch to Profile Tab
          onAvatarTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        ),

        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(
              child: Text("暂无任务，快去创建吧！", style: TextStyle(color: Colors.grey)),
            ),
          ),

        if (active.isNotEmpty)
          _buildExpansionSection("进行中", active, Colors.blue),
        if (overdue.isNotEmpty)
          _buildExpansionSection(
            "已过期",
            overdue,
            Colors.red,
            initiallyExpanded: true,
          ),
        if (completed.isNotEmpty)
          _buildExpansionSection(
            "已完成",
            completed,
            Colors.green,
            isDoneSection: true,
            initiallyExpanded: false,
          ),
      ],
    );
  }

  Widget _buildExpansionSection(
    String title,
    List<Task> sectionTasks,
    Color color, {
    bool isDoneSection = false,
    bool initiallyExpanded = true,
  }) {
    if (!_sectionExpandedState.containsKey(title))
      _sectionExpandedState[title] = initiallyExpanded;
    bool isExpanded = _sectionExpandedState[title]!;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(title),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        title: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                decoration: isDoneSection ? TextDecoration.lineThrough : null,
                decorationColor: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${sectionTasks.length}",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_left_rounded,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
        trailing: const SizedBox.shrink(),
        onExpansionChanged: (expanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              setState(() => _sectionExpandedState[title] = expanded);
          });
        },
        children: sectionTasks
            .map(
              (task) => TaskTile(
                task: task,
                onToggle: () => toggleTask(task),
                onConfirmDelete: _confirmDelete,
                onDelete: () => _performDelete(task),
                onEdit: () => _editTask(task),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 [Core] Three Main Pages
    final List<Widget> pages = [
      // 0: Battle Page
      _buildBattlePage(),

      // 1: Shop Page
      ShopPage(gold: gold, onRefreshData: _loadData),

      // 2: Profile Page
      ProfileScreen(currentAvatarUrl: avatarUrl),
    ];

    String appBarTitle = "任务战场";
    if (_selectedIndex == 1) appBarTitle = "补给商店";
    if (_selectedIndex == 2) appBarTitle = "个人中心";

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.cloud_sync_rounded),
                  onPressed: _testBackendConnection,
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: _showDebugResetDialog,
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: ShakeWidget(
        controller: _shakeController,
        child: Stack(
          children: [
            SafeArea(child: pages[_selectedIndex]),
            Align(
              alignment: Alignment.bottomLeft,
              child: ConfettiWidget(
                confettiController: _controllerLeft,
                blastDirection: -pi / 3,
                numberOfParticles: 30,
                shouldLoop: false,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: ConfettiWidget(
                confettiController: _controllerRight,
                blastDirection: -pi * 2 / 3,
                numberOfParticles: 30,
                shouldLoop: false,
              ),
            ),
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _showDamageFlash
                      ? Colors.red.withOpacity(0.3)
                      : Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _addTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text("新挑战"),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 0) _loadData();
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline_rounded),
            activeIcon: Icon(Icons.check_circle_rounded),
            label: "挑战",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            activeIcon: Icon(Icons.storefront_rounded),
            label: "商店",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: "我的",
          ),
        ],
      ),
    );
  }
}
