import 'package:flutter/material.dart';
import 'dart:async';

class BossStage extends StatefulWidget {
  final int level;
  final int currentXp;
  final int maxXp;
  // 🔥 回调：当点击宝箱时触发
  final VoidCallback? onChestTap;

  const BossStage({
    super.key,
    required this.level,
    required this.currentXp,
    required this.maxXp,
    this.onChestTap,
  });

  @override
  State<BossStage> createState() => BossStageState();
}

class BossStageState extends State<BossStage> with TickerProviderStateMixin {
  // 动画控制器
  late AnimationController _shakeCtrl;
  late AnimationController _attackCtrl;
  late Animation<double> _attackScale;

  // 🔥 [核心] 死亡动画控制器
  late AnimationController _deathCtrl;
  late Animation<double> _deathScale;
  late Animation<double> _deathOpacity;

  final List<Widget> _damagePopups = [];
  bool _isHurt = false;
  Timer? _hurtTimer;
  bool _isAttacking = false;

  // 🔥 [核心] 是否显示宝箱
  bool _showChest = false;

  @override
  void initState() {
    super.initState();
    // 1. 震动 (挨打)
    _shakeCtrl =
        AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
          lowerBound: 0.0,
          upperBound: 0.1,
        )..addListener(() {
          setState(() {});
        });

    // 2. 攻击 (咬人)
    _attackCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _attackScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.6), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _attackCtrl, curve: Curves.easeInOut));

    // 3. 🔥 [核心] 死亡动画 (缩小 + 透明)
    _deathCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _deathScale = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _deathCtrl, curve: Curves.easeInBack));
    _deathOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _deathCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _attackCtrl.dispose();
    _deathCtrl.dispose(); // 记得销毁
    _hurtTimer?.cancel();
    super.dispose();
  }

  // 🔥 [核心功能] Boss 死亡 -> 变宝箱
  void die() {
    if (_showChest) return;

    // 播放死亡动画
    _deathCtrl.forward().then((_) {
      if (mounted) {
        setState(() {
          _showChest = true; // 动画播完，显示宝箱
        });
        // 重置动画状态，为下次出生做准备
        _deathCtrl.reset();
      }
    });
  }

  // 🔥 [核心功能] 新 Boss 出生 (升级后调用)
  void spawn() {
    setState(() {
      _showChest = false;
      _damagePopups.clear();
      _isHurt = false;
      _isAttacking = false;
    });
    // 出生特效：震动一下
    _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());
  }

  // 玩家打 Boss
  void hit(int damage) {
    if (_isAttacking || _showChest) return; // 攻击中或宝箱状态不能打

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
    if (_showChest) return;
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

  // 染色逻辑 (你的完美版修复)
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

    if (level < 10) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.green, BlendMode.modulate),
        child: rawImage,
      );
    } else if (level < 20) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.cyanAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
    } else if (level < 30) {
      return rawImage;
    } else if (level < 40) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.redAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
    } else if (level < 50) {
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
    } else if (level < 60) {
      // 🌈 彩龙修复版：modulate 模式
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
        blendMode: BlendMode.modulate, // 修复背景框问题
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1.5,
            1.5,
            1.5,
            0,
            0,
            1.5,
            1.5,
            1.5,
            0,
            0,
            1.5,
            1.5,
            1.5,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: rawImage,
        ),
      );
    } else {
      // ⚪ 白龙修复版
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

  String _getBossTitle() {
    if (_showChest) return "🎉 关卡完成！点击宝箱领取奖励";
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
    int monsterCurrentHp = _showChest ? 0 : (widget.maxXp - widget.currentXp);
    if (monsterCurrentHp < 0) monsterCurrentHp = 0;
    double hpPercentage = widget.maxXp == 0
        ? 0
        : monsterCurrentHp / widget.maxXp;

    String currentImage;
    if (_isAttacking) {
      currentImage = 'assets/images/boss_dragon_attack.png';
    } else if (_isHurt) {
      currentImage = 'assets/images/boss_dragon_hurt.png';
    } else {
      currentImage = 'assets/images/boss_dragon.png';
    }

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
        // 🔥 移除了边框，保持无边框设计
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
                // 🔥 [核心逻辑] 根据状态切换：宝箱 还是 龙
                _showChest
                    ? GestureDetector(
                        onTap: widget.onChestTap, // 点击触发回调
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.5, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: Image.asset(
                            'assets/images/chest.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => hit(10),
                        child: FadeTransition(
                          // 死亡淡出
                          opacity: _deathOpacity,
                          child: ScaleTransition(
                            // 死亡缩小
                            scale: _deathScale,
                            child: ScaleTransition(
                              scale: _attackScale,
                              child: Transform.rotate(
                                angle: _shakeCtrl.value,
                                child: _buildDragonWithColor(currentImage),
                              ),
                            ),
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

// 伤害飘字组件 (保持不变)
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
