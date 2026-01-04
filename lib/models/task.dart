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

  static String encode(List<Task> tasks) =>
      json.encode(tasks.map((e) => e.toMap()).toList());
  static List<Task> decode(String tasksJson) =>
      (json.decode(tasksJson) as List<dynamic>)
          .map((e) => Task.fromMap(e))
          .toList();
}
