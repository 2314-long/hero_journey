import 'dart:convert';

class Task {
  int? id; // 后端数据库的 ID
  String title;
  String? deadline; // 允许为空
  bool isDone;
  bool punished; // 本地逻辑字段，不需要后端存

  Task({
    this.id,
    required this.title,
    this.deadline,
    this.isDone = false,
    this.punished = false,
  });

  // 1. 从后端 JSON 解析 (核心修复点)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'], // 对应后端的 json:"id"
      title: json['title'] ?? "未命名任务", // 对应 json:"title"
      deadline: json['deadline'], // 对应 json:"deadline"
      isDone: json['is_done'] ?? false, // 对应 json:"is_done"
      // punished 字段后端没存，默认为 false
      punished: false,
    );
  }

  // 2. 序列化 (存本地缓存用)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline,
      'is_done': isDone,
      'punished': punished,
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
