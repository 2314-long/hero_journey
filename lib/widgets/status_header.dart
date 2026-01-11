import 'package:flutter/material.dart';

class StatusHeader extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final int gold;
  final int level;
  final int currentXp;
  final int maxXp;
  final bool hasResurrectionCross;
  final bool hasSword;
  final bool hasShield;

  const StatusHeader({
    super.key,
    required this.currentHp,
    required this.maxHp,
    required this.gold,
    required this.level,
    required this.currentXp,
    required this.maxXp,
    required this.hasResurrectionCross,
    this.hasSword = false,
    this.hasShield = false,
  });

  // ✨ 调整后的图标构建器：更大、更清晰
  Widget _buildStatusIcon(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8), // 间距加大，不显得拥挤
      padding: const EdgeInsets.all(6), // 背景圈大一点
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15), // 背景稍微淡一点，突出图标
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.2), // 加个淡淡的边框，更有质感
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        size: 20, // 🔥 从 14 改为 20，清晰度大幅提升
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- 第一行：等级 + 状态图标 + 金币 ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧：等级胶囊 + 状态图标栏
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
                children: [
                  // 等级胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Lv.$level",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // 等级文字也稍微大一点点
                      ),
                    ),
                  ),

                  // 🔥 图标区：不需要 SizedBox，margin 已经处理了间距
                  if (hasResurrectionCross)
                    _buildStatusIcon(
                      Icons.health_and_safety,
                      const Color(0xFFE040FB),
                    ), // 紫色更亮一点

                  if (hasSword)
                    _buildStatusIcon(
                      Icons.colorize,
                      const Color(0xFF40C4FF),
                    ), // 蓝色更亮一点

                  if (hasShield)
                    _buildStatusIcon(
                      Icons.security,
                      const Color(0xFFFFAB40),
                    ), // 橙色更亮一点
                ],
              ),

              // 右侧：金币
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 20, // 金币图标也同步放大
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$gold",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // 金币文字也同步放大
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24), // 间距稍微拉大，更透气
          // --- 第二行：HP 条 ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        color: Colors.white.withOpacity(0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "HP",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "$currentHp / $maxHp",
                    style: TextStyle(
                      color: Colors.white.withOpacity(1.0),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6), // 圆角加大
                child: LinearProgressIndicator(
                  value: maxHp > 0 ? currentHp / maxHp : 0,
                  backgroundColor: Colors.black.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    currentHp < maxHp * 0.3
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF00E676),
                  ),
                  minHeight: 10, // 进度条稍微加粗
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- 第三行：XP 条 ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: Colors.white.withOpacity(0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "XP",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "$currentXp / $maxXp",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: maxXp > 0 ? currentXp / maxXp : 0,
                  backgroundColor: Colors.black.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4DD0E1),
                  ),
                  minHeight: 8, // 进度条稍微加粗
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
