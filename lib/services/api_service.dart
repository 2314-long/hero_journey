import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class ApiService {
  // 1. 基础配置
  // 注意：现在的 API 都有了 /api/v1 前缀
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // 内存里存一个 token，方便随用随取
  static String? _token;

  // 2. 初始化：启动时检查有没有存过的 Token
  Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    print("🔑 初始化 Token: $_token");
    return _token != null;
  }

  // Helper: 获取带 Token 的 Header
  Map<String, String> get _headers => {
    "Content-Type": "application/json",
    // 如果有 token，就加上 Bearer 前缀；否则就不加 (比如登录注册时)
    if (_token != null) "Authorization": "Bearer $_token",
  };

  // --- 🔐 认证模块 (Auth) ---

  // 登录
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _token = data['token']; // 拿到通行证

        // 持久化保存 (下次打开不用登录)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        return true;
      }
    } catch (e) {
      print("💥 登录失败: $e");
    }
    return false;
  }

  // 注册
  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("💥 注册失败: $e");
      return false;
    }
  }

  // 登出
  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // --- 📋 任务模块 (Task) ---
  // 注意：URL 变了，且不再需要手动传 user_id (后端自己会从 Token 里取)

  Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // 注意：后端返回结构是 {"data": [...]}
        final List<dynamic> list = data['data'];
        return list.map((json) => Task.fromJson(json)).toList();
      }
    } catch (e) {
      print("💥 获取任务失败: $e");
    }
    return [];
  }

  Future<bool> createTask(String title, String? deadline) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: _headers,
        body: jsonEncode({"title": title, "deadline": deadline}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTask(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/${task.id}'),
        headers: _headers,
        body: jsonEncode(task.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- 🛡️ 属性模块 (Stats) ---

  Future<Map<String, dynamic>?> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("💥 $e");
    }
    return null;
  }

  Future<void> syncStats(int level, int gold, int xp, int hp, int maxHp) async {
    try {
      await http.put(
        // 注意：后端改成了 PUT
        Uri.parse('$baseUrl/stats'),
        headers: _headers,
        body: jsonEncode({
          "level": level,
          "gold": gold,
          "xp": xp,
          "hp": hp,
          "max_hp": maxHp,
        }),
      );
    } catch (e) {
      print("💥 $e");
    }
  }
}
