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

  // [修改] 增加 level 和 currentXp 参数
  Future<void> saveData({
    required int hp,
    required int maxHp, // 也要存 MaxHp，因为升级会涨上限
    required int gold,
    required int level, // [新增]
    required int currentXp, // [新增]
    required bool hasCross,
    required List<Task> tasks,
  }) async {
    await _prefs.setInt('hp', hp);
    await _prefs.setInt('maxHp', maxHp); // [新增]
    await _prefs.setInt('gold', gold);
    await _prefs.setInt('level', level); // [新增]
    await _prefs.setInt('currentXp', currentXp); // [新增]
    await _prefs.setBool('hasResurrectionCross', hasCross);
    await _prefs.setString('tasks', Task.encode(tasks));
  }

  // [修改] 读取更多数据
  Map<String, dynamic> loadData() {
    final int hp = _prefs.getInt('hp') ?? 100;
    final int maxHp = _prefs.getInt('maxHp') ?? 100; // [新增]
    final int gold = _prefs.getInt('gold') ?? 0;
    final int level = _prefs.getInt('level') ?? 1; // [新增] 默认为1级
    final int currentXp = _prefs.getInt('currentXp') ?? 0; // [新增]
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
