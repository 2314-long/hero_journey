import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 引入组件 (注意路径变成了 ../)
import '../widgets/shake_widget.dart';
import '../widgets/game_dialogs.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_tile.dart';
import '../widgets/shop_page.dart';
import '../widgets/status_header.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int currentHp = 100;
  int maxHp = 100;
  int gold = 0;
  bool hasResurrectionCross = false;

  int level = 1;
  int currentXp = 0;
  int get maxXp => level * 100;

  List<Task> tasks = [];

  Timer? _timer;
  int _selectedIndex = 0;

  late ConfettiController _controllerLeft;
  late ConfettiController _controllerRight;
  late AnimationController _shakeController;

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

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkOverdueAndPunish();
        setState(() {});
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
    // 顺便同步云端属性
    ApiService().syncStats(level, gold, currentXp, currentHp, maxHp);
  }

  void _loadData() async {
    final data = StorageService().loadData();
    final apiTasks = await ApiService().fetchTasks();
    final apiStats = await ApiService().fetchStats(); // 同步属性

    setState(() {
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
      hasResurrectionCross = data['hasResurrectionCross'];

      if (apiTasks.isNotEmpty) {
        tasks = apiTasks;
        print("✅ 已从服务器加载 ${tasks.length} 个任务");
      } else {
        tasks = data['tasks'];
        print("⚠️ 服务器未连接，使用本地缓存");
      }
    });
  }

  void _checkLevelUp() {
    if (currentXp >= maxXp) {
      AudioService().playLevelUp();
      _controllerLeft.play();
      _controllerRight.play();

      currentXp -= maxXp;
      level++;
      maxHp += 10;
      currentHp = maxHp;
      _saveData();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => LevelUpDialog(level: level),
      );
    }
  }

  void _checkOverdueAndPunish() {
    bool hasChanged = false;
    bool tookDamage = false;

    for (var task in tasks) {
      if (!task.isDone && _isOverdue(task.deadline)) {
        if (!task.punished) {
          currentHp -= 10;
          if (currentHp < 0) currentHp = 0;
          task.punished = true;
          hasChanged = true;
          tookDamage = true;
        }
      }
    }

    if (hasChanged) {
      _saveData();
      if (tookDamage) {
        AudioService().playDamage();
        HapticFeedback.heavyImpact();
        _shakeController.forward();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("⚠️ 任务过期！受到伤害！"),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (currentHp <= 0) {
        if (hasResurrectionCross) {
          _triggerResurrection();
        } else {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => GameOverDialog(
              onRestart: () {
                setState(() {
                  currentHp = 100;
                  maxHp = 100;
                  gold = 0;
                  level = 1;
                  currentXp = 0;
                  hasResurrectionCross = false;
                });
                _saveData();
              },
            ),
          );
        }
      }
    }
  }

  void _triggerResurrection() {
    setState(() {
      currentHp = (maxHp / 2).floor();
      hasResurrectionCross = false;
    });
    _saveData();
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => const ResurrectionDialog(),
    );
  }

  void toggleTask(Task task) async {
    if (_isOverdue(task.deadline)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚫 任务已失效"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      task.isDone = !task.isDone;

      if (task.isDone) {
        AudioService().playSuccess();
        gold += 10;
        int xpGain = 50;
        currentXp += xpGain;
        _checkLevelUp();
        if (task.id != null) {
          NotificationService().cancelNotification(task.id!);
        }
      } else {
        gold -= 10;
        currentXp -= 50;
        if (gold < 0) gold = 0;
        if (currentXp < 0) currentXp = 0;
      }
    });
    await ApiService().updateTask(task);
    _saveData();
  }

  // 编辑任务逻辑
  void _editTask(Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
          initialTitle: task.title,
          // 🚀 [修复 1] 只有当 deadline 不为 null 且 不为空字符串 时才解析
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
            int taskId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final newTask = Task(
              id: taskId,
              title: title,
              deadline: deadline?.toIso8601String(),
            );

            setState(() {
              tasks.add(newTask);
            });

            final success = await ApiService().createTask(
              title,
              deadline?.toIso8601String(),
            );

            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("☁️ 已同步到云端"),
                  duration: Duration(seconds: 1),
                ),
              );
            }
            _saveData();

            if (deadline != null) {
              NotificationService().scheduleNotification(
                taskId,
                title,
                deadline,
              );
            }
          },
        );
      },
    );
  }

  Future<void> _testBackendConnection() async {
    final url = Uri.parse('http://10.0.2.2:8080/api/v1/tasks'); // 注意加上 api/v1
    try {
      // ... (测试逻辑可以简化，主要逻辑已经在 loadData 里了)
      print("测试连接...");
      await ApiService().fetchTasks();
    } catch (e) {
      print(e);
    }
  }

  void _deleteTask(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("确认删除"),
        content: const Text("确定要放弃这个挑战吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => tasks.remove(task));
              if (task.id != null) {
                NotificationService().cancelNotification(task.id!);
                await ApiService().deleteTask(task.id!);
              }
              _saveData();
            },
            child: const Text("删除"),
          ),
        ],
      ),
    );
  }

  void _buyItem(String name, int price, Function effect) {
    if (gold >= price) {
      setState(() {
        gold -= price;
        effect();
      });
      _saveData();
      AudioService().playBuy();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("已购买 $name!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("金币不足！"),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return false;
    }
    try {
      return DateTime.now().isAfter(DateTime.parse(dateStr));
    } catch (e) {
      print("日期解析失败: $dateStr");
      return false;
    }
  }

  Widget _buildHomePage() {
    final List<Task> overdue = [];
    final List<Task> today = [];
    final List<Task> tomorrow = [];
    final List<Task> future = [];
    final List<Task> noDate = [];
    final List<Task> completed = [];

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final tomorrowEnd = todayEnd.add(const Duration(days: 1));

    for (var task in tasks) {
      if (task.isDone) {
        completed.add(task);
        continue;
      }

      // 🚀 [修复 2] 这里必须同时检查 null 和 isEmpty (空字符串)
      if (task.deadline == null || task.deadline!.isEmpty) {
        noDate.add(task);
        continue;
      }

      // 现在下面的 deadline 肯定是合法的字符串了
      if (_isOverdue(task.deadline)) {
        overdue.add(task);
        continue;
      }

      try {
        final date = DateTime.parse(task.deadline!);
        if (date.isBefore(todayEnd)) {
          today.add(task);
        } else if (date.isBefore(tomorrowEnd)) {
          tomorrow.add(task);
        } else {
          future.add(task);
        }
      } catch (e) {
        // 如果万一解析失败，放进待办
        noDate.add(task);
      }
    }

    int sortTime(Task a, Task b) => a.deadline!.compareTo(b.deadline!);
    int sortId(Task a, Task b) => b.id!.compareTo(a.id!);

    // ... (排序逻辑省略，保持不变) ...
    try {
      overdue.sort(sortTime);
    } catch (e) {}
    try {
      today.sort(sortTime);
    } catch (e) {}
    // ...

    return ListView(
      padding: const EdgeInsets.only(bottom: 80, top: 16),
      children: [
        StatusHeader(
          currentHp: currentHp,
          maxHp: maxHp,
          gold: gold,
          level: level,
          currentXp: currentXp,
          maxXp: maxXp,
          hasResurrectionCross: hasResurrectionCross,
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "暂无任务\n快去发布一个挑战吧！",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          ),
        if (today.isNotEmpty)
          _buildExpansionSection("今天", today, Theme.of(context).primaryColor),
        if (tomorrow.isNotEmpty)
          _buildExpansionSection("明天", tomorrow, Colors.orange),
        if (future.isNotEmpty)
          _buildExpansionSection("以后", future, Colors.indigoAccent),
        if (noDate.isNotEmpty)
          _buildExpansionSection("待办", noDate, Colors.blueGrey),
        if (overdue.isNotEmpty)
          _buildExpansionSection(
            "已过期",
            overdue,
            Colors.redAccent,
            initiallyExpanded: false,
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
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        childrenPadding: EdgeInsets.zero,
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDoneSection ? Colors.grey : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${sectionTasks.length}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        children: sectionTasks
            .map(
              (task) => TaskTile(
                task: task,
                onToggle: () => toggleTask(task),
                onDelete: () => _deleteTask(task),
                onEdit: () => _editTask(task),
              ),
            )
            .toList(),
      ),
    );
  }

  void _debugResetLevel() {
    setState(() {
      level = 1;
      currentXp = 0;
      maxHp = 100;
      currentHp = 100;
    });
    _saveData();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("🔄 开发模式：等级已重置")));
  }

  void _showDebugResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🛠️ 开发调试"),
        content: const Text("确定要将等级重置为 Lv.1 吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _debugResetLevel();
            },
            child: const Text("确定重置", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: ShakeWidget(
        controller: _shakeController,
        child: Stack(
          children: [
            SafeArea(
              child: _selectedIndex == 0
                  ? _buildHomePage()
                  : ShopPage(
                      gold: gold,
                      currentHp: currentHp,
                      maxHp: maxHp,
                      hasResurrectionCross: hasResurrectionCross,
                      onBuyHealth: () {
                        if (currentHp >= maxHp) return;
                        _buyItem("小型血瓶", 50, () {
                          currentHp += 20;
                          if (currentHp > maxHp) currentHp = maxHp;
                        });
                      },
                      onBuyCross: () {
                        if (hasResurrectionCross) return;
                        _buyItem(
                          "复活十字架",
                          100,
                          () => hasResurrectionCross = true,
                        );
                      },
                      onBuyCoffee: () => _buyItem("咖啡", 10, () {}),
                    ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: ConfettiWidget(
                confettiController: _controllerLeft,
                blastDirection: -pi / 3,
                emissionFrequency: 0.01,
                numberOfParticles: 30,
                maxBlastForce: 60,
                minBlastForce: 30,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: ConfettiWidget(
                confettiController: _controllerRight,
                blastDirection: -pi * 2 / 3,
                emissionFrequency: 0.01,
                numberOfParticles: 30,
                maxBlastForce: 60,
                minBlastForce: 30,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _addTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                "新挑战",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
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
      ),
    );
  }
}
