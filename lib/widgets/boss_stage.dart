import 'package:flutter/material.dart';
import 'dart:async';

class BossStage extends StatefulWidget {
  final int level;
  final int currentXp;
  final int maxXp;
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
  late AnimationController _shakeCtrl;
  late AnimationController _attackCtrl;
  late Animation<double> _attackScale;
  late AnimationController _deathCtrl;
  late Animation<double> _deathScale;
  late Animation<double> _deathOpacity;

  final List<Widget> _damagePopups = [];
  bool _isHurt = false;
  Timer? _hurtTimer;
  bool _isAttacking = false;
  bool _showChest = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl =
        AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
          lowerBound: 0.0,
          upperBound: 0.1,
        )..addListener(() {
          setState(() {});
        });
    _attackCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _attackScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.6), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _attackCtrl, curve: Curves.easeInOut));
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
    _deathCtrl.dispose();
    _hurtTimer?.cancel();
    super.dispose();
  }

  void die() {
    if (_showChest) return;
    _deathCtrl.forward().then((_) {
      if (mounted) {
        setState(() => _showChest = true);
        _deathCtrl.reset();
      }
    });
  }

  void spawn() {
    setState(() {
      _showChest = false;
      _damagePopups.clear();
      _isHurt = false;
      _isAttacking = false;
    });
    _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());
  }

  void hit(int damage) {
    if (_isAttacking || _showChest) return;
    _hurtTimer?.cancel();
    setState(() => _isHurt = true);
    _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());

    final key = UniqueKey();
    final popup = Positioned(
      key: key,
      top: 20,
      right: 40 + (damage % 10).toDouble(),
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

  void attack() {
    if (_showChest) return;
    _hurtTimer?.cancel();
    _attackCtrl.reset();
    setState(() {
      _isHurt = false;
      _isAttacking = true;
    });
    _attackCtrl.forward().then((_) {
      if (mounted) setState(() => _isAttacking = false);
    });
  }

  // ... 颜色逻辑保持不变 (省略部分代码，请保留你原来的 _buildDragonWithColor) ...
  Widget _buildDragonWithColor(String imagePath) {
    int level = widget.level;
    Widget rawImage = Image.asset(
      imagePath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );
    if (level < 10)
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.green, BlendMode.modulate),
        child: rawImage,
      );
    else if (level < 20)
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.cyanAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
    else if (level < 30)
      return rawImage;
    else if (level < 40)
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.redAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
    else if (level < 50)
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
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
    else if (level < 60)
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
          ],
        ).createShader(bounds),
        blendMode: BlendMode.modulate,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
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
    else
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
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

  String _getBossTitle() {
    if (_showChest) return "关卡完成";
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
    double bossHpPct = widget.maxXp == 0 ? 0 : monsterCurrentHp / widget.maxXp;

    String currentImage = _isAttacking
        ? 'assets/images/boss_dragon_attack.png'
        : (_isHurt
              ? 'assets/images/boss_dragon_hurt.png'
              : 'assets/images/boss_dragon.png');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      // 🔥 瘦身：减少内边距
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.indigo.shade900, Colors.deepPurple.shade900],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.shade900.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        // 🔥 关键：使用 min 让卡片不要撑太高
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Boss 血条
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "BOSS",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "$monsterCurrentHp / ${widget.maxXp}",
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: bossHpPct,
              backgroundColor: Colors.black26,
              color: Colors.redAccent,
              minHeight: 12,
            ),
          ),

          const SizedBox(height: 12),

          // 2. Boss 形象 (缩小)
          SizedBox(
            height: 110, // 缩小尺寸
            width: 110,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _showChest
                    ? GestureDetector(
                        onTap: widget.onChestTap,
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
                          opacity: _deathOpacity,
                          child: ScaleTransition(
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

          const SizedBox(height: 8),

          // 3. 关卡名称
          Text(
            _getBossTitle(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// DamageText 组件保持不变...
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
