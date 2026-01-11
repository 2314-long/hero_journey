import 'package:flutter/material.dart';
import 'dart:async'; // 🔥 [新增] 需要引入 async 库来使用 Timer

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
  State<BossStage> createState() => BossStageState();
}

class BossStageState extends State<BossStage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Widget> _damagePopups = [];

  // 🔥 [新增] 用来控制是否显示受伤图片的状态
  bool _isHurt = false;
  // 🔥 [新增] 用来控制受伤状态恢复的定时器
  Timer? _hurtTimer;

  @override
  void initState() {
    super.initState();
    // 震动动画控制器
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
    // 🔥 [新增] 销毁页面时一定要取消定时器，防止内存泄漏
    _hurtTimer?.cancel();
    super.dispose();
  }

  // 受击方法
  void hit(int damage) {
    // 1. 重置定时器：如果上一次受伤还没恢复，先取消掉，重新开始计时
    _hurtTimer?.cancel();

    // 2. 切换状态：立刻变成受伤状态 (换图)
    setState(() {
      _isHurt = true;
    });

    // 3. 播放震动动画
    _controller.forward().then((_) => _controller.reverse());

    // 4. 添加伤害飘字 (逻辑不变)
    final key = UniqueKey();
    final popup = Positioned(
      key: key,
      top: 20,
      right: 20 + (damage % 10).toDouble(),
      child: DamageText(
        value: damage,
        onDone: () {
          if (mounted) {
            setState(() {
              _damagePopups.removeWhere((element) => element.key == key);
            });
          }
        },
      ),
    );
    setState(() {
      _damagePopups.add(popup);
    });

    // 5. 🔥 [新增] 设置定时器：800毫秒后变回普通状态
    // 这里的 800ms 要和下面 DamageText 的动画时间差不多匹配
    _hurtTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isHurt = false; // 变回帅气龙
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int monsterCurrentHp = widget.maxXp - widget.currentXp;
    if (monsterCurrentHp < 0) monsterCurrentHp = 0;
    double hpPercentage = monsterCurrentHp / widget.maxXp;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
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
          SizedBox(
            height: 120,
            width: 120,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 龙的图片 (底层)
                GestureDetector(
                  onTap: () => hit(10), // 点击测试
                  child: Transform.rotate(
                    angle: _controller.value,
                    // 🔥 [核心修改] 根据 _isHurt 状态切换图片路径
                    child: Image.asset(
                      _isHurt
                          ? 'assets/images/boss_dragon_hurt.png' // 受伤时的图片
                          : 'assets/images/boss_dragon.png', // 平时的图片
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      // 添加一个简单的淡入淡出动画，让切换不那么生硬
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: child,
                            );
                          },
                    ),
                  ),
                ),
                // 所有的飘字 (顶层)
                ..._damagePopups,
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 血条部分保持不变
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
                  value: hpPercentage,
                  backgroundColor: Colors.black38,
                  color: Colors.redAccent,
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

// 伤害飘字组件 (稍微调整了动画时间，让它更快一点，配合换图)
class DamageText extends StatefulWidget {
  final int value;
  final VoidCallback onDone;

  const DamageText({super.key, required this.value, required this.onDone});

  @override
  State<DamageText> createState() => _DamageTextState();
}

class _DamageTextState extends State<DamageText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    // 🔥 [微调] 动画时间从 800 改为 700ms，更紧凑
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));

    _position =
        Tween<Offset>(
          begin: const Offset(0, 0),
          end: const Offset(0, -60),
        ).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Curves.easeOutBack,
          ), // 用 easeOutBack 会有Q弹的感觉
        );

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) => Transform.translate(
        offset: _position.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Text(
            "-${widget.value}",
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 32, // 字体加大了一点
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  blurRadius: 5,
                  color: Colors.black,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
