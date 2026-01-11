import 'dart:convert';

class Task {
  int? id; // 后端数据库的 ID
  String title;
  String? deadline; // 允许为空
  bool isDone;
  bool punished;
  int reward;

  Task({
    this.id,
    required this.title,
    this.deadline,
    this.isDone = false,
    this.punished = false,
    this.reward = 100,
  });

  // 1. 从后端 JSON 解析 (核心修复点)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'] ?? "未命名任务",

      // 👇👇👇 核心修复 👇👇👇
      // 逻辑：如果 deadline 是 null 或者是空字符串 ""，就统统视为 null
      deadline: (json['deadline'] as String?)?.isNotEmpty == true
          ? json['deadline']
          : null,

      // 👆👆👆 修复结束 👆👆👆
      isDone: json['is_done'] ?? false,
      punished: json['is_punished'] ?? false,
      reward: json['reward'] ?? 100,
    );
  }

  // 2. 序列化 (存本地缓存用)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline,
      'is_done': isDone,
      'is_punished': punished,
    };
  }

  // 3. 列表编解码工具
  static String encode(List<Task> tasks) => json.encode(
    tasks.map<Map<String, dynamic>>((task) => task.toJson()).toList(),
  );

  static List<Task> decode(String tasks) =>
      (json.decode(tasks) as List<dynamic>)
          .map<Task>((item) => Task.fromJson(item))
          .toList();
}
