import 'package:flutter/material.dart';

class PlayerStatusCard extends StatelessWidget {
  final int level;
  final int currentHp;
  final int maxHp;
  final int gold;

  // 装备状态
  final bool hasResurrectionCross;
  final bool hasSword;
  final bool hasShield;

  const PlayerStatusCard({
    super.key,
    required this.level,
    required this.currentHp,
    required this.maxHp,
    required this.gold,
    required this.hasResurrectionCross,
    required this.hasSword,
    required this.hasShield,
  });

  @override
  Widget build(BuildContext context) {
    double hpPercentage = maxHp == 0 ? 0 : currentHp / maxHp;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E), // 深色背景
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔥 第一行：等级 | 血条 | 金币
          Row(
            children: [
              // 等级 (蓝色胶囊)
              _buildCapsule(Icons.shield, "Lv.$level", Colors.blueAccent),

              const SizedBox(width: 12),

              // 血条
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "HP",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$currentHp/$maxHp",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: hpPercentage,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFF00FFC2), // 荧光绿，更像游戏血条
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 金币 (金色胶囊)
              _buildCapsule(
                Icons.monetization_on_rounded,
                "$gold",
                Colors.amber,
              ),
            ],
          ),

          // 🔥 第二行：装备栏 (复刻商店样式)
          if (hasResurrectionCross || hasSword || hasShield) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  "已装备",
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 12),

                // 勇者铁剑 (模仿商店：蓝色背景 + 剑图标)
                // 注意：Icons.colorize 是吸管，但在很多教程里常被当作简单的剑替身，或者你可以换成 Icons.handyman
                if (hasSword)
                  _buildShopIcon(
                    Icons.colorize,
                    Colors.blue.shade100,
                    Colors.blue,
                    "勇者铁剑",
                  ),

                // 木质盾牌 (模仿商店：棕色背景 + 盾图标)
                if (hasShield)
                  _buildShopIcon(
                    Icons.security,
                    Colors.brown.shade100,
                    Colors.brown,
                    "木质盾牌",
                  ),

                // 复活十字架 (模仿商店：粉色背景 + 十字图标)
                if (hasResurrectionCross)
                  _buildShopIcon(
                    Icons.local_hospital,
                    Colors.pink.shade100,
                    Colors.pink,
                    "复活十字架",
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 辅助：顶部胶囊样式
  Widget _buildCapsule(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 辅助：复刻商店图标样式
  Widget _buildShopIcon(
    IconData icon,
    Color bgColor,
    Color iconColor,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor, // 浅色背景
          borderRadius: BorderRadius.circular(8), // 方形圆角，像 APP 图标
        ),
        child: Icon(
          icon,
          color: iconColor, // 深色图标
          size: 18,
        ),
      ),
    );
  }
}
