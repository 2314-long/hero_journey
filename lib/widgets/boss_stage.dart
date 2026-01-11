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

class BossStageState extends State<BossStage> with TickerProviderStateMixin {
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

    // 2. 🔥 [核心修改] 攻击控制器：总时长加到 2 秒
    _attackCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // 3. 🔥 [核心修改] 攻击动作改为三段式：猛扑 -> 悬停(最久) -> 缩回
    _attackScale = TweenSequence<double>([
      // 阶段1: 快速扑过来 (权重 15%)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 15),
      // 阶段2: 悬停在脸上吓唬你 (权重 70%) - 这就是让你看清的时候
      TweenSequenceItem(tween: ConstantTween(1.6), weight: 70),
      // 阶段3: 快速缩回去 (权重 15%)
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

  void hit(int damage) {
    // 霸体状态：攻击时不能被打断
    if (_isAttacking) return;

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

  // 🔥 [核心修改] Boss 攻击逻辑优化
  void attack() {
    // 1. 强制重置之前的状态
    _hurtTimer?.cancel();
    _attackCtrl.reset();

    setState(() {
      _isHurt = false;
      _isAttacking = true; // 切换凶狠图
    });

    // 2. 播放动画，并在结束后强制恢复
    _attackCtrl.forward().then((_) {
      // 当 2秒 动画播放完毕后，执行这里
      if (mounted) {
        setState(() {
          _isAttacking = false; // 变回正常图
        });
      }
    });
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
                GestureDetector(
                  onTap: () => hit(10),
                  child: ScaleTransition(
                    scale: _attackScale,
                    child: Transform.rotate(
                      angle: _shakeCtrl.value,
                      child: Image.asset(
                        currentImage,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        // 简单的切换动效
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
