import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class ApiService {
  // 模拟器访问电脑的固定地址
  static const String baseUrl = 'http://10.0.2.2:8080';

  // 1. 获取任务列表 (GET)
  Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tasks'));

      if (response.statusCode == 200) {
        // 解码 JSON
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = jsonDecode(decodedBody);
        final List<dynamic> tasksJson = data['data'];

        // 把 List<JSON> 转换成 List<Task>
        return tasksJson.map((json) => Task.fromJson(json)).toList();
      } else {
        print("❌ 获取任务失败: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("💥 网络错误: $e");
      return [];
    }
  }

  // 2. 创建新任务 (POST)
  Future<bool> createTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(task.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("💥 创建任务失败: $e");
      return false;
    }
  }

  // 3. 更新任务 (PUT)
  Future<bool> updateTask(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/${task.id}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(task.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("💥 更新失败: $e");
      return false;
    }
  }

  // 4. 删除任务 (DELETE)
  Future<bool> deleteTask(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/tasks/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print("💥 删除失败: $e");
      return false;
    }
  }
}
