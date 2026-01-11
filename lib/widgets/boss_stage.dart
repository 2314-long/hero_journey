import 'package:flutter/material.dart';

class BossStage extends StatefulWidget {
  final int level;
  final int currentXp;
  final int maxXp;

  const BossStage({
    super.key,
    required this.level,
    required this.currentXp,
    required this.maxXp,
  });

  @override
  State<BossStage> createState() => _BossStageState();
}

class _BossStageState extends State<BossStage>
    with SingleTickerProviderStateMixin {
  // 动画控制器，用于制作怪物“受伤抖动”的效果
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
          lowerBound: 0.0,
          upperBound: 0.1,
        )..addListener(() {
          setState(() {});
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 外部调用这个方法，怪物就会抖动
  void hit() {
    _controller.forward().then((_) => _controller.reverse());
  }

  @override
  Widget build(BuildContext context) {
    // 计算怪物剩余血量百分比
    // 逻辑：你的 XP 越多，怪物血越少
    // Monster HP = (Total XP - Current XP)
    int monsterCurrentHp = widget.maxXp - widget.currentXp;
    if (monsterCurrentHp < 0) monsterCurrentHp = 0;

    double hpPercentage = monsterCurrentHp / widget.maxXp;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // 给战场一个深色背景，营造氛围
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.indigo.shade900, Colors.deepPurple.shade900],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. 关卡标题 (Level)
          Text(
            "第 ${widget.level} 关 - 恶龙巢穴",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // 2. 怪物主体 (带抖动动画)
          GestureDetector(
            onTap: hit, // 点击测试动画
            child: Transform.rotate(
              angle: _controller.value, // 简单的旋转抖动
              child: SizedBox(
                height: 120,
                width: 120,
                // 这里暂时用一个像素风恶龙的网络图片
                // 之后我们可以把图片存到 assets 文件夹里
                child: Image.asset(
                  'assets/images/boss_dragon.png', // 确保文件名和你放入的一致
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none, // 如果是像素画，加这个会更清晰
                  errorBuilder: (context, error, stackTrace) {
                    // 如果还是加载不出来，显示这个红色图标方便调试
                    return const Icon(
                      Icons.bug_report,
                      size: 80,
                      color: Colors.red,
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. 怪物血条 (Boss HP)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Boss HP",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "$monsterCurrentHp / ${widget.maxXp}",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: hpPercentage, // 剩余血量
                  backgroundColor: Colors.black38,
                  color: Colors.redAccent, // 怪物血条通常是红色的
                  minHeight: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
