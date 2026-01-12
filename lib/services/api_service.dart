import 'dart:convert';
import 'package:http/http.dart' as http;
// 移除对 shared_preferences 的直接引用，统一走 StorageService
// import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/item.dart';
import 'storage_service.dart';
import 'package:flutter/material.dart'; // 需要 Material 路由
import '../utils/global_keys.dart'; // 引入全局 Key
import '../screens/login_screen.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';

class ApiService {
  // 1. 基础配置
  // Android 模拟器用 10.0.2.2，真机调试请换成电脑局域网 IP
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';
  // 真机URL,会根据网络变化
  // static const String baseUrl = "http://10.82.169.168:8080/api/v1";

  // 移除 static _token 和 init()，因为我们现在每次都从 StorageService 读，保证最新
  // 移除 Map<String, String> get _headers ...

  // ✅ [核心修复] 统一获取请求头的方法
  // 每次调用都去读取最新的 Token，防止 Token 过期或为空
  Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService().getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // --- 🔐 认证模块 (Auth) ---

  // 登录
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {"Content-Type": "application/json"}, // 登录不需要 Token
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        // 防止中文乱码
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String token = data['token'];

        // ✅ 统一使用 StorageService 保存
        await StorageService().saveToken(token);
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
        headers: {"Content-Type": "application/json"}, // 注册不需要 Token
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
    await StorageService().removeToken();
  }

  // --- 📋 任务模块 (Task) ---

  // 获取任务列表
  Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks'),
        headers: await _getHeaders(), // ✅ 使用统一的 headers
      );
      _checkAndHandleError(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => Task.fromJson(json)).toList();
      } else {
        print("获取任务失败: ${response.statusCode}");
      }
    } catch (e) {
      print("解析任务出错: $e");
    }
    return [];
  }

  Future<Task?> createTask(String title, String? deadline) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: await _getHeaders(), // ✅ 使用统一的 headers
        body: jsonEncode({'title': title, 'deadline': deadline}),
      );
      _checkAndHandleError(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Task.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        print("创建任务失败: ${response.body}");
      }
    } catch (e) {
      print("创建任务异常: $e");
    }
    return null;
  }

  Future<bool> updateTask(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/${task.id}'),
        headers: await _getHeaders(), // ✅ 修复：之前这里用了 _headers 导致没 Token
        body: jsonEncode(task.toJson()),
      );
      _checkAndHandleError(response);
      return response.statusCode == 200;
    } catch (e) {
      print("更新任务失败: $e");
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: await _getHeaders(), // ✅ 修复
      );
      _checkAndHandleError(response);
      return response.statusCode == 200;
    } catch (e) {
      print("删除任务失败: $e");
      return false;
    }
  }

  // --- 🛡️ 属性模块 (Stats) ---

  Future<Map<String, dynamic>?> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: await _getHeaders(), // ✅ 修复
      );
      _checkAndHandleError(response);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print("💥 获取属性失败: $e");
    }
    return null;
  }

  Future<void> syncStats(int level, int gold, int xp, int hp, int maxHp) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/stats'),
        headers: await _getHeaders(), // ✅ 修复
        body: jsonEncode({
          "level": level,
          "gold": gold,
          "xp": xp,
          "hp": hp,
          "max_hp": maxHp,
        }),
      );
    } catch (e) {
      print("💥 同步属性失败: $e");
    }
  }

  // --- 🛍️ 商店与背包模块 ---

  // 1. 获取商店商品列表
  Future<List<Item>> fetchShopItems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop'),
        headers: await _getHeaders(), // ✅ 简化代码
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => Item.fromJson(json)).toList();
      }
    } catch (e) {
      print("加载商店失败: $e");
    }
    return []; // 失败返回空列表，防止报错
  }

  // 2. 购买物品
  Future<String?> buyItem(int itemId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/buy'),
        headers: await _getHeaders(), // ✅ 简化代码
        body: jsonEncode({'item_id': itemId}),
      );
      _checkAndHandleError(response);

      if (response.statusCode == 200) {
        return null; // ✅ 成功
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return body['error']?.toString() ?? "购买失败";
      }
    } catch (e) {
      return "请求错误: $e";
    }
  }

  // 返回 InventoryItem 对象列表
  // 获取背包 (修复版：兼容 列表 和 Map 两种返回格式)
  Future<List<InventoryItem>> fetchInventory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory'),
        headers: await _getHeaders(),
      );
      _checkAndHandleError(response);

      if (response.statusCode == 200) {
        // 防止中文乱码
        final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));

        List<dynamic> listData = [];

        // 🔍 修复逻辑在这里：自动判断后端返回的是哪种格式
        if (data is List) {
          // 情况 1: 后端直接返回数组 [...]
          listData = data;
        } else if (data is Map && data['items'] != null) {
          // 情况 2: 后端返回对象 { "items": [...] }
          listData = data['items'];
        }

        // 开始转换模型
        if (listData.isNotEmpty) {
          return listData.map((e) => InventoryItem.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("获取背包失败: $e");
    }
    return []; // 失败或为空时返回空数组
  }

  // 4. 装备/卸下物品
  Future<bool> toggleEquip(int inventoryId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventory/equip'),
        headers: await _getHeaders(), // ✅ 简化代码
        body: jsonEncode({'inventory_id': inventoryId}),
      );
      _checkAndHandleError(response);
      return response.statusCode == 200;
    } catch (e) {
      print("装备操作失败: $e");
      return false;
    }
  }

  // 5. 使用物品 (药水)
  Future<String?> useItem(int inventoryId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventory/use'),
        headers: await _getHeaders(), // ✅ 简化代码
        body: jsonEncode({'inventory_id': inventoryId}),
      );
      _checkAndHandleError(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['message'];
      }
    } catch (e) {
      print("使用物品失败: $e");
    }
    return null;
  }

  // ✝️ 复活请求
  Future<bool> resurrect() async {
    try {
      final response = await http.post(
        // 👇 注意：这里要和 main.go 里的路径对应，是 /resurrect
        Uri.parse('$baseUrl/resurrect'),
        headers: await _getHeaders(),
      );
      _checkAndHandleError(response);

      if (response.statusCode == 200) {
        return true;
      } else {
        print("复活失败: ${response.body}");
        return false;
      }
    } catch (e) {
      print("复活失败: $e");
      return false;
    }
  }

  // 🔥 [新增] 全局错误拦截器
  // 作用：检查 Token 是否过期，如果过期则踢人下线
  void _checkAndHandleError(http.Response response) {
    if (response.statusCode == 401) {
      print("🚨 拦截到 401 Unauthorized，Token 已失效，正在强制退出...");

      // 1. 清除本地存储的旧 Token
      StorageService().clearAll();

      // 2. 使用全局 Key 强制跳转回登录页
      // pushAndRemoveUntil 会清空路由栈，防止用户按返回键回到旧页面
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // 3. 抛出异常，打断后续逻辑 (防止代码继续解析错误的 JSON)
      throw Exception("登录已过期，请重新登录");
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    try {
      var uri = Uri.parse('$baseUrl/profile/avatar/upload');
      var request = http.MultipartRequest('POST', uri);

      // 添加 Token
      final token = await StorageService().getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // 添加文件
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar', // 后端接收的字段名
          imageFile.path,
        ),
      );

      // 发送
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['avatar_url']; // 返回后端给的新 URL
      } else {
        print("上传失败: ${response.body}");
      }
    } catch (e) {
      print("上传出错: $e");
    }
    return null;
  }
}
