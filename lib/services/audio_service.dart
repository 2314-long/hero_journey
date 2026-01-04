import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // 单例模式
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  // 通用的播放方法
  Future<void> _playSound(String fileName) async {
    try {
      // stop() 确保如果上一个音效还没播完，被打断直接播新的（适合快节奏操作）
      await _player.stop();
      await _player.play(AssetSource('audio/$fileName'));
    } catch (e) {
      print("🔇 音效播放失败: $e (可能文件不存在)");
    }
  }

  // --- 暴露给外部的方法 ---

  // 1. 完成任务 / 金币到账
  void playSuccess() => _playSound('success.mp3');

  // 2. 升级
  void playLevelUp() => _playSound('levelup.mp3');

  // 3. 受伤 / 扣血
  void playDamage() => _playSound('damage.mp3');

  // 4. 花钱 / 购买
  void playBuy() => _playSound('money.mp3');
}
