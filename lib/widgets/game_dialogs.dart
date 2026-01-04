import 'package:flutter/material.dart';

// --- 1. 升级弹窗 ---
class LevelUpDialog extends StatelessWidget {
  final int level;

  const LevelUpDialog({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Center(
        child: Text(
          "🎉 升级啦！",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.keyboard_double_arrow_up_rounded,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          Text(
            "恭喜提升到 Lv.$level",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "❤️ 生命上限 +10\n✨ HP 已完全恢复",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
      actions: [
        Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text("太棒了！", style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.only(bottom: 24),
    );
  }
}

// --- 2. 复活弹窗 ---
class ResurrectionDialog extends StatelessWidget {
  const ResurrectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.purple),
          SizedBox(width: 8),
          Text("复活生效！"),
        ],
      ),
      content: const Text("你受到了致命伤害，但复活十字架替你挡下了一劫！\nHP 已恢复至 50。"),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context),
          child: const Text("继续战斗"),
        ),
      ],
    );
  }
}

// --- 3. 游戏结束弹窗 ---
class GameOverDialog extends StatelessWidget {
  final VoidCallback onRestart; // 接收一个回调函数

  const GameOverDialog({super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            Icons.dangerous_outlined,
            color: Theme.of(context).colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text("GAME OVER"),
        ],
      ),
      content: const Text("生命耗尽，英雄倒下了...\n\n一切将重新开始。别灰心，下次会更好！"),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            Navigator.pop(context); // 先关弹窗
            onRestart(); // 再执行重启逻辑
          },
          child: const Text("重新开始旅程"),
        ),
      ],
      actionsPadding: const EdgeInsets.all(24),
    );
  }
}
