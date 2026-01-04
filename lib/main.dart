import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';

// 组件引用
import 'widgets/shake_widget.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/add_task_dialog.dart';
import 'widgets/task_tile.dart';
import 'widgets/shop_page.dart';
import 'widgets/status_header.dart';

import 'models/task.dart';
import 'services/notification_service.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await StorageService().init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const HeroApp());
}

class HeroApp extends StatelessWidget {
  const HeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color(0xFF6C63FF);

    return MaterialApp(
      title: 'Hero Journey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: const Color(0xFFF4F6FC),
          primary: seedColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FC),
        appBarTheme: AppBarTheme(
          backgroundColor: seedColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: seedColor,
          unselectedItemColor: Colors.grey.shade400,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(color: Colors.transparent),
        expansionTileTheme: const ExpansionTileThemeData(
          shape: Border(),
          collapsedShape: Border(),
        ),
        // 全局输入框样式 (为了保持一致性)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

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
  }

  void _loadData() {
    final data = StorageService().loadData();
    setState(() {
      currentHp = data['hp'];
      maxHp = data['maxHp'];
      gold = data['gold'];
      level = data['level'];
      currentXp = data['currentXp'];
      hasResurrectionCross = data['hasResurrectionCross'];
      tasks = data['tasks'];
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

  void toggleTask(Task task) {
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
    _saveData();
  }

  // [新增] 编辑任务逻辑
  void _editTask(Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
          // 传入当前任务的信息
          initialTitle: task.title,
          initialDeadline: task.deadline == null
              ? null
              : DateTime.parse(task.deadline!),
          onSubmit: (title, deadline) {
            setState(() {
              task.title = title;
              task.deadline = deadline?.toIso8601String();
            });
            // 重新设置通知
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
          onSubmit: (title, deadline) {
            int taskId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            setState(() {
              tasks.add(
                Task(
                  id: taskId,
                  title: title,
                  deadline: deadline?.toIso8601String(),
                ),
              );
            });

            if (deadline != null) {
              NotificationService().scheduleNotification(
                taskId,
                title,
                deadline,
              );
            }
            _saveData();
          },
        );
      },
    );
  }

  // [修改] 删除任务逻辑：增加确认弹窗
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
            onPressed: () {
              Navigator.pop(context); // 关掉确认框
              // 执行真正的删除
              if (task.id != null) {
                NotificationService().cancelNotification(task.id!);
              }
              setState(() => tasks.remove(task));
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

  bool _isOverdue(String? dateStr) =>
      dateStr == null ? false : DateTime.now().isAfter(DateTime.parse(dateStr));

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

      if (task.deadline == null) {
        noDate.add(task);
        continue;
      }

      if (_isOverdue(task.deadline)) {
        overdue.add(task);
        continue;
      }

      final date = DateTime.parse(task.deadline!);
      if (date.isBefore(todayEnd)) {
        today.add(task);
      } else if (date.isBefore(tomorrowEnd)) {
        tomorrow.add(task);
      } else {
        future.add(task);
      }
    }

    int sortTime(Task a, Task b) => a.deadline!.compareTo(b.deadline!);
    int sortId(Task a, Task b) => b.id!.compareTo(a.id!);

    overdue.sort(sortTime);
    today.sort(sortTime);
    tomorrow.sort(sortTime);
    future.sort(sortTime);
    noDate.sort(sortId);
    completed.sort(sortId);

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
          _buildExpansionSection(
            "今天",
            today,
            Theme.of(context).primaryColor,
            initiallyExpanded: true,
          ),
        if (tomorrow.isNotEmpty)
          _buildExpansionSection(
            "明天",
            tomorrow,
            Colors.orange,
            initiallyExpanded: true,
          ),
        if (future.isNotEmpty)
          _buildExpansionSection(
            "以后",
            future,
            Colors.indigoAccent,
            initiallyExpanded: true,
          ),
        if (noDate.isNotEmpty)
          _buildExpansionSection(
            "待办",
            noDate,
            Colors.blueGrey,
            initiallyExpanded: true,
          ),
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
                onDelete: () => _deleteTask(task), // [修改] 这里会触发确认弹窗
                onEdit: () => _editTask(task), // [新增] 编辑回调
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🔄 开发模式：等级已重置"),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                  tooltip: "开发调试：重置等级",
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
                        if (currentHp >= maxHp) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("满血不需要喝药！"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _buyItem("小型血瓶", 50, () {
                          currentHp += 20;
                          if (currentHp > maxHp) currentHp = maxHp;
                        });
                      },
                      onBuyCross: () {
                        if (hasResurrectionCross) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("你已经拥有复活十字架了！"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _buyItem("复活十字架", 100, () {
                          hasResurrectionCross = true;
                        });
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
                  Colors.yellowAccent,
                ],
                createParticlePath: (size) {
                  final path = Path();
                  if (Random().nextBool()) {
                    path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
                  } else {
                    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
                  }
                  return path;
                },
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
                  Colors.cyanAccent,
                ],
                createParticlePath: (size) {
                  final path = Path();
                  if (Random().nextBool()) {
                    path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
                  } else {
                    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
                  }
                  return path;
                },
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
              elevation: 4,
              highlightElevation: 8,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
