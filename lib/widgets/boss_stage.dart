import 'package:flutter/material.dart';
import 'dart:async';

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

class BossStageState extends State<BossStage> with TickerProviderStateMixin {
  // 动画控制器
  late AnimationController _shakeCtrl;
  late AnimationController _attackCtrl;
  late Animation<double> _attackScale;

  final List<Widget> _damagePopups = [];
  bool _isHurt = false;
  Timer? _hurtTimer;
  bool _isAttacking = false;

  @override
  void initState() {
    super.initState();
    // 1. 震动控制器 (挨打)
    _shakeCtrl =
        AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
          lowerBound: 0.0,
          upperBound: 0.1,
        )..addListener(() {
          setState(() {});
        });

    // 2. 攻击控制器 (咬人) - 时长 2 秒
    _attackCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // 3. 攻击动作：猛扑 -> 悬停(最久) -> 缩回
    _attackScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.6), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _attackCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _attackCtrl.dispose();
    _hurtTimer?.cancel();
    super.dispose();
  }

  // 玩家打 Boss
  void hit(int damage) {
    if (_isAttacking) return; // 霸体

    _hurtTimer?.cancel();
    setState(() => _isHurt = true);
    _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());

    final key = UniqueKey();
    final popup = Positioned(
      key: key,
      top: 20,
      right: 20 + (damage % 10).toDouble(),
      child: DamageText(
        value: damage,
        onDone: () {
          if (mounted)
            setState(() => _damagePopups.removeWhere((e) => e.key == key));
        },
      ),
    );
    setState(() => _damagePopups.add(popup));

    _hurtTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isHurt = false);
    });
  }

  // Boss 打玩家
  void attack() {
    _hurtTimer?.cancel();
    _attackCtrl.reset();

    setState(() {
      _isHurt = false;
      _isAttacking = true;
    });

    _attackCtrl.forward().then((_) {
      if (mounted) {
        setState(() {
          _isAttacking = false;
        });
      }
    });
  }

  // 🔥 [核心功能] 根据等级给龙“染色”
  // 🔥 [修复版] 去掉了会导致报错的 const
  Widget _buildDragonWithColor(String imagePath) {
    int level = widget.level;
    Widget rawImage = Image.asset(
      imagePath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );

    // 1. 🟢 绿龙 (Lv 1-9)
    if (level < 10) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.green, BlendMode.modulate),
        child: rawImage,
      );
    }
    // 2. 🔵 蓝龙 (Lv 10-19)
    else if (level < 20) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.cyanAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
    }
    // 3. 🟣 紫龙 (Lv 20-29)
    else if (level < 30) {
      return rawImage;
    }
    // 4. 🔴 红龙 (Lv 30-39)
    else if (level < 40) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.redAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
    }
    // 5. ⚫ 黑龙 (Lv 40-49)
    else if (level < 50) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.modulate),
          child: rawImage,
        ),
      );
    }
    // 6. 🌈 彩龙 (Lv 50-59)
    else if (level < 60) {
      return ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            tileMode: TileMode.mirror,
          ).createShader(bounds);
        },
        // 🔥 核心修改：改为 modulate (乘法)
        // 它可以完美保留透明背景，彻底消除那个方形色块！
        blendMode: BlendMode.modulate,

        // 配合修改：先把龙变成“高亮灰白”，作为底色
        // 这样彩虹色叠上去才会鲜艳，同时保留黑色阴影细节
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1.5, 1.5, 1.5, 0, 0, // R 提亮
            1.5, 1.5, 1.5, 0, 0, // G 提亮
            1.5, 1.5, 1.5, 0, 0, // B 提亮
            0, 0, 0, 1, 0, // Alpha 不变
          ]),
          child: rawImage,
        ),
      );
    }
    // 7. ⚪ 白龙 (Lv 60+)
    else {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          1.2,
          1.2,
          1.2,
          0,
          30,
          1.2,
          1.2,
          1.2,
          0,
          30,
          1.2,
          1.2,
          1.2,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: rawImage,
      );
    }
  }

  // 获取 Boss 称号
  String _getBossTitle() {
    if (widget.level < 10) return "第 ${widget.level} 关 - 剧毒绿龙";
    if (widget.level < 20) return "第 ${widget.level} 关 - 冰霜蓝龙";
    if (widget.level < 30) return "第 ${widget.level} 关 - 虚空紫龙";
    if (widget.level < 40) return "第 ${widget.level} 关 - 烈焰红龙";
    if (widget.level < 50) return "第 ${widget.level} 关 - 深渊黑龙";
    if (widget.level < 60) return "第 ${widget.level} 关 - 元素彩龙";
    return "第 ${widget.level} 关 - 光辉白龙";
  }

  @override
  Widget build(BuildContext context) {
    int monsterCurrentHp = widget.maxXp - widget.currentXp;
    if (monsterCurrentHp < 0) monsterCurrentHp = 0;
    double hpPercentage = monsterCurrentHp / widget.maxXp;

    String currentImage;
    if (_isAttacking) {
      currentImage = 'assets/images/boss_dragon_attack.png';
    } else if (_isHurt) {
      currentImage = 'assets/images/boss_dragon_hurt.png';
    } else {
      currentImage = 'assets/images/boss_dragon.png';
    }

    // 🔥 修复点：最外层是纯净的 Container，背景色绝对不会变绿
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
            _getBossTitle(),
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
                GestureDetector(
                  onTap: () => hit(10),
                  child: ScaleTransition(
                    scale: _attackScale,
                    child: Transform.rotate(
                      angle: _shakeCtrl.value,
                      // 🔥 修复点：只给龙的图片这一小块区域上色
                      child: _buildDragonWithColor(currentImage),
                    ),
                  ),
                ),
                ..._damagePopups,
              ],
            ),
          ),

          const SizedBox(height: 10),
          // 血条
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

// 伤害飘字组件
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
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));

    _position = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -60),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

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
              fontSize: 32,
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
