import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 📒 小本本：用来记录正在运行的倒计时
  // Key 是任务ID，Value 是那个 Timer 对象
  final Map<int, Timer> _activeTimers = {};

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidImplementation?.requestNotificationsPermission();
  }

  // 安排通知
  Future<void> scheduleNotification(
    int id,
    String title,
    DateTime deadline,
  ) async {
    // 1. 如果这个任务之前有旧的闹钟，先取消掉（防止重复）
    cancelNotification(id);

    final DateTime now = DateTime.now();
    if (deadline.isBefore(now)) return;

    // 2. 提前提醒逻辑
    const int earlyReminderMinutes = 5; // 提前5分钟提醒
    DateTime remindTime = deadline.subtract(
      const Duration(minutes: earlyReminderMinutes),
    );

    if (remindTime.isBefore(now)) {
      remindTime = now.add(const Duration(seconds: 3)); // 紧急任务立即响
    }

    final Duration diff = remindTime.difference(now);
    print("🚀 [通知服务] 任务ID:$id 已受理，将在 ${diff.inSeconds} 秒后响铃");

    // 3. 启动 Timer，并存入小本本
    Timer timer = Timer(diff, () async {
      print("⏰ 任务ID:$id 时间到！发送通知...");

      // 发送通知
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'hero_urgent_v3', // 再次升级ID
            '紧急任务提醒',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          );

      await flutterLocalNotificationsPlugin.show(
        id,
        '⏳ 任务即将过期！',
        '只剩最后不足 $earlyReminderMinutes 分钟了！快去完成 "$title"！',
        const NotificationDetails(android: androidPlatformChannelSpecifics),
      );

      // 响完之后，把自己从小本本里删掉
      _activeTimers.remove(id);
    });

    // 存起来！
    _activeTimers[id] = timer;
  }

  // 👇👇👇 新增：取消通知的方法 👇👇👇
  void cancelNotification(int id) {
    if (_activeTimers.containsKey(id)) {
      _activeTimers[id]?.cancel(); // 停止倒计时
      _activeTimers.remove(id); // 撕掉这一页
      print("🛑 [通知服务] 已取消任务ID:$id 的闹钟");
    }
  }

  // 清空所有
  void cancelAll() {
    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();
    flutterLocalNotificationsPlugin.cancelAll();
  }
}
