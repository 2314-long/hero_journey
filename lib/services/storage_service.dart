import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ----------------------------------------------------------------
  // 👇👇👇 新增：Token 管理 (解决报错的关键) 👇👇👇
  // ----------------------------------------------------------------

  // 1. 保存 Token (登录成功时调用)
  Future<void> saveToken(String token) async {
    await _prefs.setString('auth_token', token);
  }

  // 2. 获取 Token (API 请求时调用)
  Future<String?> getToken() async {
    return _prefs.getString('auth_token');
  }

  // 3. 删除 Token (退出登录时调用)
  Future<void> removeToken() async {
    await _prefs.remove('auth_token');
  }

  // 彻底清除所有数据 (退出登录专用)
  Future<void> clearAll() async {
    await _prefs.clear(); // 这会把 token, gold, tasks 全部删掉，干干净净
  }

  // [修改] 增加 level 和 currentXp 参数
  Future<void> saveData({
    required int hp,
    required int maxHp,
    required int gold,
    required int level,
    required int currentXp,
    required bool hasCross,
    required List<Task> tasks,
  }) async {
    await _prefs.setInt('hp', hp);
    await _prefs.setInt('maxHp', maxHp);
    await _prefs.setInt('gold', gold);
    await _prefs.setInt('level', level);
    await _prefs.setInt('currentXp', currentXp);
    await _prefs.setBool('hasResurrectionCross', hasCross);
    await _prefs.setString('tasks', Task.encode(tasks));
  }

  // [修改] 读取更多数据
  Map<String, dynamic> loadData() {
    final int hp = _prefs.getInt('hp') ?? 100;
    final int maxHp = _prefs.getInt('maxHp') ?? 100;
    final int gold = _prefs.getInt('gold') ?? 0;
    final int level = _prefs.getInt('level') ?? 1;
    final int currentXp = _prefs.getInt('currentXp') ?? 0;
    final bool hasCross = _prefs.getBool('hasResurrectionCross') ?? false;

    List<Task> tasks = [];
    final String? tasksJson = _prefs.getString('tasks');
    if (tasksJson != null) {
      try {
        tasks = Task.decode(tasksJson);
      } catch (e) {
        tasks = [];
      }
    }

    return {
      'hp': hp,
      'maxHp': maxHp,
      'gold': gold,
      'level': level,
      'currentXp': currentXp,
      'hasResurrectionCross': hasCross,
      'tasks': tasks,
    };
  }
}
