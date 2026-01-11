import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'login_screen.dart';

// 引入模型
import '../models/item.dart';
import '../models/task.dart';

// 引入组件和服务
import '../widgets/shake_widget.dart';
import '../widgets/game_dialogs.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_tile.dart';
import '../widgets/shop_page.dart';
import '../widgets/status_header.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../widgets/boss_stage.dart'; // 别忘了引入

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  // --- 状态变量 ---
  int currentHp = 100;
  int maxHp = 100;
  int gold = 0;
  bool _showDamageFlash = false;

  final Map<String, bool> _sectionExpandedState = {
    "进行中": true, // 默认展开
    "已过期": true, // 默认展开
    "已完成": false, // 默认收起
  };
  final GlobalKey<BossStageState> _bossKey = GlobalKey<BossStageState>();

  // 虽然我们现在直接查背包，但这个变量保留用于 UI 显示（比如头部状态栏的小图标）
  bool hasResurrectionCross = false;
  bool hasSword = false;
  bool hasShield = false;

  // 🔥 [新增] 全局背包列表，确保逻辑能随时访问最新数据
  List<InventoryItem> inventory = [];

  int level = 1;
  int currentXp = 0;
  int get maxXp => level * 100;

  List<Task> tasks = [];

  // --- 控制器 ---
  Timer? _timer;
  int _selectedIndex = 0;
  late ConfettiController _controllerLeft;
  late ConfettiController _controllerRight;
  late AnimationController _shakeController;

  // 防止重复处理 Game Over 的锁
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
        // 定时检查任务过期和惩罚
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
    // 注意：这里我们不同步 inventory，因为 inventory 以服务端为准
    ApiService().syncStats(level, gold, currentXp, currentHp, maxHp);
  }

  Future<void> _loadData() async {
    // 1. 加载本地数据 (快速显示)
    final data = StorageService().loadData();

    // 2. 加载网络数据
    final apiTasks = await ApiService().fetchTasks();
    final apiStats = await ApiService().fetchStats();
    final apiInventory = await ApiService().fetchInventory(); // 获取背包

    if (!mounted) return;

    setState(() {
      // --- 更新属性 ---
      if (apiStats != null) {
        level = apiStats['level'];
        gold = apiStats['gold'];
        currentXp = apiStats['xp'];
        currentHp = apiStats['hp'];
        maxHp = apiStats['max_hp'];
      } else {
        currentHp = data['hp'];
        maxHp = data['maxHp'];
        gold = data['gold'];
        level = data['level'];
        currentXp = data['currentXp'];
      }

      // --- 🔥 [关键] 更新背包数据到类变量 ---
      this.inventory = apiInventory;

      // --- 检查十字架 (用于 UI 显示) ---
      bool foundCross = false;
      bool foundSword = false; // 新增
      bool foundShield = false;
      for (var item in apiInventory) {
        // 1. 检查复活十字架 (逻辑不变，只要有就显示，不需要穿戴)
        if (item.item.effectType == 'RESURRECT' && item.quantity > 0) {
          foundCross = true;
        }

        // 2. 检查剑 (必须是 已装备 + 攻击类)
        if (item.isEquipped && item.item.effectType == 'GOLD_BOOST') {
          foundSword = true;
        }

        // 3. 检查盾 (必须是 已装备 + 防御类)
        if (item.isEquipped && item.item.effectType == 'DMG_REDUCE') {
          foundShield = true;
        }
      }

      // 更新状态
      hasResurrectionCross = foundCross;
      hasSword = foundSword; // 新增
      hasShield = foundShield; // 新增

      // --- 更新任务 ---
      if (apiTasks.isNotEmpty) {
        tasks = apiTasks;
      } else {
        tasks = data['tasks'];
      }
    });
  }

  // --- 核心逻辑：检查过期与惩罚 ---
  void _checkOverdueAndPunish() async {
    // 1. 安全检查
    if (_isGameOverProcessing) return;

    bool hasChanged = false;

    // 2. 遍历检查过期任务
    for (var task in tasks) {
      if (!task.isDone && _isOverdue(task.deadline)) {
        if (!task.punished) {
          task.punished = true;
          hasChanged = true;
          // 发送给后端扣血
          await ApiService().updateTask(task);
        }
      }
    }

    // 3. 只有状态改变了，才去拉取结果
    if (hasChanged) {
      final oldHp = currentHp;

      // 拉取最新血量和背包
      await _loadData();

      // 4. 受伤反馈
      if (currentHp < oldHp) {
        AudioService().playDamage();
        // HapticFeedback.heavyImpact();
        // _shakeController.forward();
        _bossKey.currentState?.attack();
        // 🔥 [新增] 屏幕闪红！
        setState(() => _showDamageFlash = true);

        // 300毫秒后消失，模拟瞬间受伤的感觉
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _showDamageFlash = false);
          }
        });

        if (mounted) {
          final damage = oldHp - currentHp;

          // 🔥 修复 Bug：动态检查是否装备了盾牌
          // 假设盾牌的 effectType 是 'DEFENSE'，请根据你数据库实际情况调整
          bool hasShield = inventory.any(
            (inv) => inv.isEquipped && inv.item.effectType == 'DMG_REDUCE',
          );

          // 根据是否有盾牌，显示不同的文字
          String message = "⚠️ 任务过期！受到 $damage 点伤害";
          if (hasShield) {
            message += " (护盾已生效)"; // 只有装备了才加这句
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message), // 使用动态生成的文字
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // 5. 💀 死亡判定 (修复版)
      if (currentHp <= 0) {
        _timer?.cancel(); // 暂停计时器防止重复触发

        // 🔥 [修复] 直接在背包里找复活道具，不依赖 bool 变量
        InventoryItem? revivalItem;
        try {
          revivalItem = inventory.firstWhere(
            (inv) =>
                (inv.item.effectType == 'REVIVE' || inv.item.name == '复活十字架') &&
                inv.quantity > 0,
          );
        } catch (e) {
          revivalItem = null;
        }

        if (revivalItem != null) {
          // 🎉 找到了复活道具
          print("触发复活流程，道具: ${revivalItem.item.name}");
          _triggerResurrection(revivalItem);
        } else {
          // 💀 没道具，真死了
          print("无复活道具，Game Over");
          _handleGameOver();
        }
      }
    }
  }

  // --- 弹窗逻辑 ---

  // 1. 弹出复活询问窗
  void _triggerResurrection(InventoryItem item) {
    _isGameOverProcessing = true; // 锁定

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
              _handleGameOver(); // 放弃复活
            },
            child: const Text("放弃", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // 执行复活
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

  // 2. 🔥 [修复] 真正执行复活的函数 (你之前报错缺少的函数)
  Future<void> _useReviveItem(InventoryItem item) async {
    // 显示加载圈
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 调用 API 消耗物品
      // 注意：这里调用 useItem，假设后端逻辑是：使用复活币 -> 扣数量 -> 回满血
      await ApiService().useItem(item.id);

      // 重新拉取数据 (验证血量是否恢复)
      await _loadData();

      // 关闭加载圈
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (currentHp > 0) {
        // 复活成功！
        setState(() {
          _isGameOverProcessing = false; // 解锁
        });
        _startTimer(); // 恢复心跳

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✨ 奇迹发生了！英雄已复活！"),
              backgroundColor: Colors.amber,
            ),
          );
        }
      } else {
        // 如果后端 useItem 没回血，尝试调用备用的 resurrect 接口 (如果你的逻辑是分开的)
        // await ApiService().resurrect(); ... (根据实际情况调整)
        throw "道具已使用，但生命值未恢复，请检查后端逻辑";
      }
    } catch (e) {
      // 异常处理
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      print("复活出错: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 复活失败: $e")));
        // 失败后还是得结束游戏
        _handleGameOver();
      }
    }
  }

  // 3. 处理彻底的游戏结束
  void _handleGameOver() {
    _timer?.cancel();
    _isGameOverProcessing = true;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => GameOverDialog(
        onRestart: () async {
          // 这里可以加一个 ApiService().resetGame() 告诉后端重置

          setState(() {
            currentHp = 100;
            maxHp = 100;
            gold = 0;
            level = 1;
            currentXp = 0;
            hasResurrectionCross = false;
            tasks.clear(); // 或者保留任务，看你需求
            _isGameOverProcessing = false;
          });

          _saveData();
          _startTimer();

          // 如果需要的话，重新从后端拉一遍初始数据
          // await _loadData();
        },
      ),
    );
  }

  // --- 其他辅助函数 (保持原样) ---

  void _checkLevelUp() {
    // 这个方法改名为 _handleLevelUp 更好，对应 onChestTap
    // 如果你之前的参数名叫 onChestTap: _checkLevelUp，请修改这里的内容

    AudioService().playSuccess(); // 点击宝箱的音效

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
            // 宝箱打开的图标
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 60),
            const SizedBox(height: 16),
            // 显示下个等级
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // 关闭弹窗

              // 🔥 [核心] 在这里执行真正的数据升级
              setState(() {
                level++; // 等级 +1
                currentXp = currentXp - maxXp; // 扣除升级经验
                if (currentXp < 0) currentXp = 0;

                // 属性提升
                maxHp += 10;
                currentHp = maxHp; // 升级回满血

                // 播放庆祝彩带
                _controllerLeft.play();
                _controllerRight.play();
                AudioService().playLevelUp();
              });

              // 保存并同步数据
              _saveData();

              // 🔥 召唤新 Boss
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
    // 1. 拦截已完成任务
    if (task.isDone) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚫 任务完成后不可撤销！"),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.grey,
        ),
      );
      setState(() {
        task.isDone = true;
      });
      return;
    }

    // 2. 拦截过期任务
    if (task.deadline != null) {
      final due = DateTime.parse(task.deadline!);
      if (DateTime.now().isAfter(due) && !task.isDone) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🚫 任务已过期，无法操作")));
        return;
      }
    }

    // 3. 核心逻辑
    if (!task.isDone) {
      int reward = task.reward; // 🔥 确保这里的数值是你想要的单次伤害

      // --- 💀 情况 A: 击杀 Boss (经验溢出) ---
      if (currentXp + reward >= maxXp) {
        // 3.1 视觉上加满经验
        setState(() {
          currentXp += reward;
        });
        AudioService().playSuccess();

        // 3.2 播放死亡动画 -> 变宝箱
        _bossKey.currentState?.die();

        // 3.3 手动更新任务状态
        setState(() {
          task.isDone = true;
          if (task.id != null) {
            NotificationService().cancelNotification(task.id!);
          }
        });

        // 3.4 告诉后端任务完成
        await ApiService().updateTask(task);
        _saveData();

        // 🛑🛑🛑 [核心修复点] 🛑🛑🛑
        // 必须在这里 RETURN！强制结束函数！
        // 这样才不会执行下面的 _loadData()，从而防止直接弹出升级窗
        return;
      }
      // --- ⚔️ 情况 B: 普通攻击 (经验未满) ---
      else {
        setState(() {
          currentXp += reward;
        });
        AudioService().playSuccess();

        // 🔥 [修复数值不一致]
        // 之前你写的是 hit(100)，现在改成 hit(reward)
        // 这样显示的红字就是 -50 了
        _bossKey.currentState?.hit(reward);
      }
    }

    // --- 下面的代码只有在 [普通攻击] 时才会运行 ---

    final int oldLevel = level;

    setState(() {
      task.isDone = !task.isDone;
      if (task.isDone && task.id != null) {
        NotificationService().cancelNotification(task.id!);
      }
    });

    final success = await ApiService().updateTask(task);

    if (!success) {
      if (mounted) {
        setState(() => task.isDone = !task.isDone);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("⚠️ 同步失败，请检查网络")));
      }
    } else {
      await _loadData(); // 刷新数据

      // 普通升级检测（防止意外情况）
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

  // --- 增删改查 UI 方法 (保持原样) ---

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
              if (deadline != null) {
                NotificationService().scheduleNotification(
                  task.id!,
                  title,
                  deadline,
                );
              }
            }
            // 这里建议也调用一下 API 更新
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
            // 乐观 UI 更新
            int tempId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final tempTask = Task(
              id: tempId,
              title: title,
              deadline: deadline?.toIso8601String(),
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

              if (deadline != null) {
                NotificationService().scheduleNotification(
                  serverTask.id!,
                  title,
                  deadline,
                );
              }
            }
          },
        );
      },
    );
  }

  Future<void> _testBackendConnection() async {
    try {
      print("测试连接...");
      await ApiService().fetchTasks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ 后端连接成功")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 连接失败: $e")));
      }
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

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("退出登录"),
        content: const Text("确定要退出当前账号吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("退出", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService().clearAll();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // 判断是否过期
  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      return DateTime.now().isAfter(DateTime.parse(dateStr));
    } catch (e) {
      return false;
    }
  }

  // --- 构建 UI ---

  Widget _buildHomePage() {
    // 简单的任务分类逻辑
    final List<Task> overdue = [];
    final List<Task> active = [];
    final List<Task> completed = [];

    final now = DateTime.now();

    for (var task in tasks) {
      if (task.isDone) {
        completed.add(task);
      } else if (_isOverdue(task.deadline)) {
        overdue.add(task);
      } else {
        active.add(task);
      }
    }

    // 排序
    int sortTime(Task a, Task b) {
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    }

    active.sort(sortTime);
    overdue.sort(sortTime);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80, top: 16),
      children: [
        BossStage(
          key: _bossKey,
          level: level,
          currentXp: currentXp,
          maxXp: maxXp,
          onChestTap: _checkLevelUp,
        ),
        StatusHeader(
          currentHp: currentHp,
          maxHp: maxHp,
          gold: gold,
          level: level,
          currentXp: currentXp,
          maxXp: maxXp,
          hasResurrectionCross: hasResurrectionCross,
          hasSword: hasSword,
          hasShield: hasShield,
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
    // 确保 Map 里有初始值
    if (!_sectionExpandedState.containsKey(title)) {
      _sectionExpandedState[title] = initiallyExpanded;
    }

    bool isExpanded = _sectionExpandedState[title]!;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent, // 去掉原本的分割线
      ),
      child: ExpansionTile(
        key: PageStorageKey(title), // 保持滚动状态
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),

        // 🔥 核心修改：自定义 Title 样式
        title: Row(
          children: [
            // 1. 左侧垂直色条
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8), // 间距
            // 2. 标题文字
            Text(
              title,
              style: TextStyle(
                color: Colors.black87, // 标题统一用深色，显得更干净
                fontWeight: FontWeight.bold,
                fontSize: 15,
                decoration: isDoneSection ? TextDecoration.lineThrough : null,
                decorationColor: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),

            // 3. 数字徽标 (胶囊样式)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1), // 浅灰色背景
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

            // 4. 撑开空间，把箭头挤到最右边
            const Spacer(),

            // 5. 自定义箭头图标
            Icon(
              isExpanded
                  ? Icons
                        .keyboard_arrow_down_rounded // 展开时：向下
                  : Icons.keyboard_arrow_left_rounded, // 合并时：向左 (按你要求)
              // P.S. 如果想要常规风格，这里通常用 keyboard_arrow_right_rounded
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),

        // 隐藏原本自带的旋转箭头
        trailing: const SizedBox.shrink(),

        onExpansionChanged: (expanded) {
          // 确保这一帧绘制完再刷新数据，避免冲突
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _sectionExpandedState[title] = expanded;
              });
            }
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

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? '任务战场' : '补给商店'),
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
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  onPressed: _handleLogout,
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      // 1. 最外层是震动组件 (保持不变)
      body: ShakeWidget(
        controller: _shakeController,
        // 2. 这里的 Stack 用来叠加图层 (保持不变)
        child: Stack(
          children: [
            // 第一层：页面主要内容
            SafeArea(
              child: _selectedIndex == 0
                  ? _buildHomePage()
                  : ShopPage(gold: gold, onRefreshData: _loadData),
            ),

            // 第二层：左边彩带
            Align(
              alignment: Alignment.bottomLeft,
              child: ConfettiWidget(
                confettiController: _controllerLeft,
                blastDirection: -pi / 3,
                numberOfParticles: 30,
                shouldLoop: false,
              ),
            ),

            // 第三层：右边彩带
            Align(
              alignment: Alignment.bottomRight,
              child: ConfettiWidget(
                confettiController: _controllerRight,
                blastDirection: -pi * 2 / 3,
                numberOfParticles: 30,
                shouldLoop: false,
              ),
            ),

            // 🔥 [新增] 第四层：全屏受伤红闪 (一定要放在最后，才能盖住所有内容)
            IgnorePointer(
              // IgnorePointer 确保这层颜色不会阻挡你点击下面的按钮
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), // 渐变时间
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  // 如果 _showDamageFlash 为 true，显示半透明红色
                  // 否则显示透明
                  color: _showDamageFlash
                      ? Colors.red.withOpacity(0.3) // 30% 透明度的血色
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
        onTap: (index) => setState(() => _selectedIndex = index),
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
        ],
      ),
    );
  }
}
