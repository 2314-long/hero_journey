import 'package:flutter/material.dart';
import 'dart:async';

class BattleHeader extends StatefulWidget {
  // 玩家数据
  final int level;
  final int currentHp;
  final int maxHp;
  final int gold;
  final bool hasResurrectionCross;
  final bool hasSword;
  final bool hasShield;

  // Boss 数据
  final int currentXp;
  final int maxXp;

  // 头像 URL
  final String avatarUrl;

  // 点击回调
  final VoidCallback? onAvatarTap;
  final VoidCallback? onChestTap;

  const BattleHeader({
    super.key,
    required this.level,
    required this.currentHp,
    required this.maxHp,
    required this.gold,
    required this.hasResurrectionCross,
    required this.hasSword,
    required this.hasShield,
    required this.currentXp,
    required this.maxXp,
    this.avatarUrl = "",
    this.onAvatarTap,
    this.onChestTap,
  });

  @override
  State<BattleHeader> createState() => BattleHeaderState();
}

class BattleHeaderState extends State<BattleHeader>
    with TickerProviderStateMixin {
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
          // 这个 setState 是震动动画必须的，但可能会导致控制台打印一些 rebuild 信息
          // 这是正常的，不必担心
          if (mounted) setState(() {});
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
      top: 10,
      right: 20,
      child: DamageText(
        value: damage,
        onDone: () {
          if (mounted) {
            setState(() => _damagePopups.removeWhere((e) => e.key == key));
          }
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

  Widget _buildDragonWithColor(String imagePath) {
    int level = widget.level;
    Widget rawImage = Image.asset(
      imagePath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );
    // 简化的 Boss 颜色逻辑
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
    else
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.purpleAccent,
          BlendMode.modulate,
        ),
        child: rawImage,
      );
  }

  String _getBossTitle() {
    if (_showChest) return "关卡完成";
    if (widget.level < 10) return "剧毒绿龙";
    if (widget.level < 20) return "冰霜蓝龙";
    if (widget.level < 30) return "虚空紫龙";
    if (widget.level < 40) return "烈焰红龙";
    if (widget.level < 50) return "深渊黑龙";
    if (widget.level < 60) return "元素彩龙";
    return "光辉白龙";
  }

  @override
  @override
  Widget build(BuildContext context) {
    int monsterCurrentHp = _showChest ? 0 : (widget.maxXp - widget.currentXp);
    if (monsterCurrentHp < 0) monsterCurrentHp = 0;
    double bossHpPct = widget.maxXp == 0 ? 0 : monsterCurrentHp / widget.maxXp;
    double playerHpPct = widget.maxHp == 0
        ? 0
        : widget.currentHp / widget.maxHp;
    String currentImage = _isAttacking
        ? 'assets/images/boss_dragon_attack.png'
        : (_isHurt
              ? 'assets/images/boss_dragon_hurt.png'
              : 'assets/images/boss_dragon.png');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. 背景层
            Row(
              children: [
                Expanded(child: Container(color: const Color(0xFF2A2D3E))),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.indigo.shade900,
                          Colors.deepPurple.shade900,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. 装饰层
            Center(
              child: Transform.rotate(
                angle: 0.2,
                child: Container(
                  width: 10,
                  height: 200,
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

            // 3. 内容层
            Row(
              children: [
                // 👈 左侧：玩家区域
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onAvatarTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 🔥 Row 1: 第一行修正 (移除 Flexible)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildBadge(
                                  Icons.shield,
                                  "Lv.${widget.level}",
                                  Colors.blue,
                                ),
                                const SizedBox(width: 4),

                                // ✅ [核心修复] 去掉了 Flexible，直接显示金币
                                // 在 SingleChildScrollView 里不能用 Flexible
                                _buildBadge(
                                  Icons.monetization_on,
                                  "${widget.gold}",
                                  Colors.amber,
                                ),

                                const SizedBox(width: 8),

                                // 装备图标
                                if (widget.hasSword)
                                  _buildSmallEquipBadge(
                                    Icons.colorize,
                                    Colors.blue,
                                  ),
                                if (widget.hasShield)
                                  _buildSmallEquipBadge(
                                    Icons.security,
                                    Colors.brown,
                                  ),
                                if (widget.hasResurrectionCross)
                                  _buildSmallEquipBadge(
                                    Icons.local_hospital,
                                    Colors.pink,
                                  ),
                              ],
                            ),
                          ),

                          // Row 2: 头像
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: widget.avatarUrl.isNotEmpty
                                    ? NetworkImage(
                                        "http://10.0.2.2:8080${widget.avatarUrl}",
                                      )
                                    : const AssetImage(
                                            'assets/images/default_avatar.png',
                                          )
                                          as ImageProvider,
                              ),
                            ),
                          ),

                          // Row 3: HP
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "HERO HP",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${widget.currentHp}/${widget.maxHp}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: playerHpPct,
                                  backgroundColor: Colors.white10,
                                  color: const Color(0xFF00FFC2),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 中间 VS
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      "VS",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

                // 👉 右侧：Boss 区域 (保持不变)
                Expanded(
                  child: GestureDetector(
                    onTap: _showChest ? widget.onChestTap : () => hit(10),
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _getBossTitle(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${monsterCurrentHp}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        "BOSS HP",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: bossHpPct,
                                      backgroundColor: Colors.white10,
                                      color: Colors.redAccent,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          top: 25,
                          child: SizedBox(
                            height: 80,
                            width: 80,
                            child: _showChest
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.5, end: 1.0),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.elasticOut,
                                    builder: (context, value, child) =>
                                        Transform.scale(
                                          scale: value,
                                          child: child,
                                        ),
                                    child: Image.asset(
                                      'assets/images/chest.png',
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : FadeTransition(
                                    opacity: _deathOpacity,
                                    child: ScaleTransition(
                                      scale: _deathScale,
                                      child: ScaleTransition(
                                        scale: _attackScale,
                                        child: Transform.rotate(
                                          angle: _shakeCtrl.value,
                                          child: _buildDragonWithColor(
                                            currentImage,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        ..._damagePopups,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 徽章组件
  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ⚡ 新的小型装备图标
  Widget _buildSmallEquipBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4), // 图标之间的间距
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4), //稍微方一点
      ),
      child: Icon(icon, color: color, size: 10), // 小尺寸图标
    );
  }
}

// 伤害飘字 (保持不变)
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
  late Animation<double> _scale;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );
    _position = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -60),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
        child: Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Text(
              "-${widget.value}",
              style: const TextStyle(
                color: Color(0xFFFF3333),
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(
                    blurRadius: 0,
                    color: Colors.black,
                    offset: Offset(-1, -1),
                  ),
                  Shadow(
                    blurRadius: 0,
                    color: Colors.black,
                    offset: Offset(1, -1),
                  ),
                  Shadow(
                    blurRadius: 0,
                    color: Colors.black,
                    offset: Offset(1, 1),
                  ),
                  Shadow(
                    blurRadius: 0,
                    color: Colors.black,
                    offset: Offset(-1, 1),
                  ),
                  Shadow(
                    blurRadius: 10,
                    color: Colors.redAccent,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
