import 'package:flutter/material.dart';

class StatusHeader extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final int gold;
  final int level;
  final int currentXp;
  final int maxXp;
  final bool hasResurrectionCross;

  const StatusHeader({
    super.key,
    required this.currentHp,
    required this.maxHp,
    required this.gold,
    required this.level,
    required this.currentXp,
    required this.maxXp,
    this.hasResurrectionCross = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      // 使用 Card 组件，自动应用 main.dart 里定义的圆角和阴影
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      elevation: 8, // 更高的层级，让它浮起来
      shadowColor: colorScheme.primary.withOpacity(0.3),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // 现代感的核心：漂亮的蓝紫色渐变背景
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.tertiary, // 使用主题中的第三色构建渐变
            ],
          ),
        ),
        child: Column(
          children: [
            // --- 第一行：等级、金币 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // 等级徽章
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "Lv.$level",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (hasResurrectionCross) ...[
                      const SizedBox(width: 12),
                      Tooltip(
                        message: "复活十字架生效中",
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade800.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.amberAccent,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // 金币显示
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$gold",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- 血条部分 ---
            _buildProgressBar(
              context: context,
              label: "HP",
              value: currentHp,
              maxValue: maxHp,
              color: currentHp < (maxHp * 0.3)
                  ? Colors.redAccent
                  : const Color(0xFF4ADE80), // 现代感的绿色
              icon: Icons.favorite_rounded,
            ),

            const SizedBox(height: 12),

            // --- 经验条部分 ---
            _buildProgressBar(
              context: context,
              label: "XP",
              value: currentXp,
              maxValue: maxXp,
              color: Colors.lightBlueAccent,
              icon: Icons.bolt_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // 封装一个构建进度条的组件
  Widget _buildProgressBar({
    required BuildContext context,
    required String label,
    required int value,
    required int maxValue,
    required Color color,
    required IconData icon,
  }) {
    double percentage = maxValue > 0 ? value / maxValue : 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            Text(
              "$value / $maxValue",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 更粗、更圆润的进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 14, // 增加高度
            child: LinearProgressIndicator(
              value: percentage,
              color: color,
              // 背景色使用半透明白色
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ),
      ],
    );
  }
}
