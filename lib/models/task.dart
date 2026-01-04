import 'dart:convert';

class Task {
  int? id; // [新增] 专门用来存通知ID
  String title;
  String? deadline;
  bool isDone;
  bool punished;

  Task({
    this.id, // [新增]
    required this.title,
    this.deadline,
    this.isDone = false,
    this.punished = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // [新增]
      'title': title,
      'deadline': deadline,
      'isDone': isDone,
      'punished': punished,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'], // [新增]
      title: map['title'],
      deadline: map['deadline'],
      isDone: map['isDone'] ?? false,
      punished: map['punished'] ?? false,
    );
  }
  // [新增] 从 JSON 数据变成 Task 对象 (服务端 -> App)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isDone: json['is_done'] ?? false,
      deadline: json['deadline'],
      // 注意：目前 Go 后端还没有存 punished 字段，这里先给默认值 false
      punished: false,
    );
  }

  static String encode(List<Task> tasks) =>
      json.encode(tasks.map((e) => e.toMap()).toList());
  static List<Task> decode(String tasksJson) =>
      (json.decode(tasksJson) as List<dynamic>)
          .map((e) => Task.fromMap(e))
          .toList();
  // 在 Task 类里面添加这个方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_done': isDone, // 注意：这里要和 Go 的 json tag 对应 (is_done)
      'deadline': deadline,
    };
  }
}
