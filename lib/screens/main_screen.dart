import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

// 引入组件
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
  // 状态变量
  int currentHp = 100;
  int maxHp = 100;
  int gold = 0;
  bool hasResurrectionCross = false;

  int level = 1;
  int currentXp = 0;
  int get maxXp => level * 100;

  List<Task> tasks = [];

  // 控制器
  Timer? _timer;
  int _selectedIndex = 0;
  late ConfettiController _controllerLeft;
  late ConfettiController _controllerRight;
  late AnimationController _shakeController;

  // 🚀 [修复核心] 防止死亡弹窗无限触发的标记
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

    // 🚀 [修复 1] 启动定时器逻辑封装
    _startTimer();
  }

  // 🚀 [修复 2] 优化的定时器启动方法
  void _startTimer() {
    _timer?.cancel(); // 防止重复启动
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // ❌ 绝对不要在这里直接写 setState(() {})
        // 只有逻辑判断需要更新时，才在内部调用 setState
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

  // 👇 把原来的 void 改成 Future<void>，这样才能被 await
  Future<void> _loadData() async {
    final data = StorageService().loadData();
    final apiTasks = await ApiService().fetchTasks();
    final apiStats = await ApiService().fetchStats();

    if (!mounted) return;

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
      } else {
        tasks = data['tasks'];
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

  // 🚀 [修复] 增加 async 关键字，以便调用 API
  void _checkOverdueAndPunish() async {
    // 如果正在处理游戏结束，或者已经挂了且没复活甲，就停止计算
    if (_isGameOverProcessing || (currentHp <= 0 && !hasResurrectionCross)) {
      return;
    }

    bool hasChanged = false;
    bool tookDamage = false;

    for (var task in tasks) {
      // 判断是否过期
      if (!task.isDone && _isOverdue(task.deadline)) {
        // 如果还没被惩罚过
        if (!task.punished) {
          currentHp -= 10;
          if (currentHp < 0) currentHp = 0;

          task.punished = true; // 本地标记为已惩罚
          hasChanged = true;
          tookDamage = true;

          // 👇👇👇 核心修复 1：立刻告诉服务器 "这个任务已经罚过了" 👇👇👇
          // 这样下次登录时，服务器返回的 is_punished 就是 true，不会再进这个 if 了
          await ApiService().updateTask(task);
        }
      }
    }

    // 只有数据真正改变时，才刷新界面
    if (hasChanged) {
      _saveData(); // 保存到本地

      // 👇👇👇 核心修复 2：同步被扣掉的血量 (HP) 到服务器 👇👇👇
      ApiService().syncStats(level, gold, currentXp, currentHp, maxHp);

      if (mounted) {
        setState(() {}); // 刷新 UI
      }

      if (tookDamage) {
        AudioService().playDamage();
        HapticFeedback.heavyImpact();
        _shakeController.forward();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("⚠️ 任务过期！受到伤害！"),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // 死亡逻辑
      if (currentHp <= 0) {
        if (hasResurrectionCross) {
          _triggerResurrection();
        } else {
          _handleGameOver();
        }
      }
    }
  }

  void _handleGameOver() {
    _timer?.cancel(); // 🛑 立即停止定时器
    _isGameOverProcessing = true; // 🔒 锁定状态

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => GameOverDialog(
        onRestart: () {
          // 重置游戏数据
          setState(() {
            currentHp = 100;
            maxHp = 100;
            gold = 0;
            level = 1;
            currentXp = 0;
            hasResurrectionCross = false;
            _isGameOverProcessing = false; // 🔓 解锁状态
          });
          _saveData();
          _startTimer(); // ▶️ 重新启动定时器
        },
      ),
    );
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
    // 1. 🚫 过期校验 (保留)
    if (task.deadline != null) {
      final due = DateTime.parse(task.deadline!);
      if (DateTime.now().isAfter(due) && !task.isDone) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🚫 任务已过期，无法操作")));
        return;
      }
    }

    // 2. 🎵 播放音效 (保留)
    if (!task.isDone) {
      AudioService().playSuccess();
    }

    // 🔥【关键步骤 A】记录操作前的旧等级
    final int oldLevel = level;

    // 3. 🔄 乐观更新 UI (只改状态，不改数值)
    setState(() {
      task.isDone = !task.isDone;

      // 取消提醒 (保留)
      if (task.isDone && task.id != null) {
        NotificationService().cancelNotification(task.id!);
      }
    });

    // 4. ☁️ 发送给后端
    final success = await ApiService().updateTask(task);

    if (!success) {
      // ❌ 失败回滚
      if (mounted) {
        setState(() {
          task.isDone = !task.isDone; // 撤销操作
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("⚠️ 同步失败，请检查网络")));
      }
    } else {
      // ✅ 成功后

      // 🔥【关键步骤 B】必须加 await！等后端计算好的数据回来
      await _loadData();

      // 🔥【关键步骤 C】比对等级，触发特效
      if (level > oldLevel) {
        // 1. 播放升级音效
        AudioService().playLevelUp();

        // 2. 播放彩带动画 (你的控制器变量)
        _controllerLeft.play();
        _controllerRight.play();

        // 3. 弹出升级对话框 (复用你已有的组件)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LevelUpDialog(level: level),
        );
      }

      // ⚠️ 注意：不要再调用 ApiService().syncStats(...) 了，
      // 因为 _loadData 刚把正确的数据拉下来，你再 sync 会把旧数据覆盖回去。
      _saveData(); // 仅保存到本地缓存即可
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
            // 1. 先用临时 ID 在本地显示（为了UI即时反馈）
            // 这里的 ID 是时间戳，比如 1767692947
            int tempId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final tempTask = Task(
              id: tempId,
              title: title,
              deadline: deadline?.toIso8601String(),
            );

            setState(() {
              tasks.add(tempTask);
            });

            // 2. 发送给后端，并等待返回真正的 Task
            final serverTask = await ApiService().createTask(
              title,
              deadline?.toIso8601String(),
            );

            if (serverTask != null && mounted) {
              // ✅ 关键修复：用真正的服务器任务替换掉本地的临时任务
              setState(() {
                // 找到刚才那个临时任务，把它删了
                tasks.removeWhere((t) => t.id == tempId);
                // 把服务器返回的（带正确ID的）任务加进来
                tasks.add(serverTask);
              });

              _saveData(); // 保存正确的 ID 到本地缓存

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("☁️ 已同步到云端"),
                  duration: Duration(seconds: 1),
                ),
              );

              // 重新设置提醒（使用真正的 ID）
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
    // 你的后端地址，注意真机调试时不要用 localhost
    final url = Uri.parse('http://10.0.2.2:8080/api/v1/tasks');
    try {
      print("测试连接...");
      await ApiService().fetchTasks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ 后端连接成功")));
      }
    } catch (e) {
      print(e);
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text("确认删除"),
            content: const Text("确定要放弃这个挑战吗？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消", style: TextStyle(color: Colors.grey)),
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

  // 👇👇👇 [新增] 处理退出登录逻辑 👇👇👇
  void _handleLogout() async {
    // 1. 弹出确认框 (防止手滑)
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
      // 2. 清除本地所有缓存 (Token + 游戏数据)
      await StorageService().clearAll();

      if (mounted) {
        // 3. 跳转回登录页，并清空路由栈 (让用户按返回键回不来)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 这里的 false 表示删掉之前所有的页面记录
        );
      }
    }
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

      if (task.deadline == null || task.deadline!.isEmpty) {
        noDate.add(task);
        continue;
      }

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
        noDate.add(task);
      }
    }

    int sortTime(Task a, Task b) => a.deadline!.compareTo(b.deadline!);

    try {
      overdue.sort(sortTime);
    } catch (e) {}
    try {
      today.sort(sortTime);
    } catch (e) {}
    try {
      tomorrow.sort(sortTime);
    } catch (e) {}
    try {
      future.sort(sortTime);
    } catch (e) {}

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
                onConfirmDelete: _confirmDelete,
                onDelete: () => _performDelete(task),
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
      _timer?.cancel(); // 安全起见
      _isGameOverProcessing = false;
    });
    _saveData();
    _startTimer(); // 重启
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("🔄 开发模式：状态已重置")));
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
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ), // 红色图标醒目一点
                  tooltip: "退出登录",
                  onPressed: _handleLogout,
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
                      onRefreshData: () {
                        // 购买成功后，重新加载数据（同步金币余额）
                        _loadData();
                      },
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
