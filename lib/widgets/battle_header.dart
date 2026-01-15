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

  // 🔥 [新增] 视觉上的 Boss 血量，实现“即时扣血”
  late double _visualBossHp;

  @override
  void initState() {
    super.initState();
    // 初始化视觉血量
    _updateVisualHpFromProps();

    _shakeCtrl =
        AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
          lowerBound: 0.0,
          upperBound: 0.1,
        )..addListener(() {
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

  // 计算真实血量
  void _updateVisualHpFromProps() {
    double realHp = (widget.maxXp - widget.currentXp).toDouble();
    if (realHp < 0) realHp = 0;
    _visualBossHp = realHp;
  }

  @override
  void didUpdateWidget(BattleHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当网络数据真正变化时，才同步视觉血量
    if (widget.currentXp != oldWidget.currentXp ||
        widget.maxXp != oldWidget.maxXp) {
      _updateVisualHpFromProps();
    }
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
    setState(() {
      _visualBossHp = 0; // 死亡瞬间血条清空
    });
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
      _updateVisualHpFromProps(); // 复活满血
    });
    _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());
  }

  void hit(int damage) {
    if (_isAttacking || _showChest) return;
    _hurtTimer?.cancel();

    setState(() {
      _isHurt = true;
      // 🔥 [核心修改] 立即扣除视觉血量，无需等待
      _visualBossHp -= damage;
      if (_visualBossHp < 0) _visualBossHp = 0;
    });

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

    // 🔥 [修改] 延长受击变红时间到 1.2秒
    _hurtTimer = Timer(const Duration(milliseconds: 2000), () {
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

  // 保持你的颜色逻辑不变
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
  Widget build(BuildContext context) {
    int monsterCurrentHp = _showChest ? 0 : (widget.maxXp - widget.currentXp);
    if (monsterCurrentHp < 0) monsterCurrentHp = 0;

    // 🔥 [修改] 使用 _visualBossHp 来计算血条
    double bossHpPct = widget.maxXp == 0 ? 0 : _visualBossHp / widget.maxXp;

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
                          // Row 1: 徽章
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
                                _buildBadge(
                                  Icons.monetization_on,
                                  "${widget.gold}",
                                  Colors.amber,
                                ),
                                const SizedBox(width: 8),
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

                // 👉 右侧：Boss 区域
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
                                      // 🔥 [修改] 显示 _visualBossHp
                                      Text(
                                        "${_visualBossHp.toInt()}",
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
                                      value: bossHpPct, // 🔥 [修改] 使用视觉百分比
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
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            child: _buildDragonWithColor(
                                              currentImage,
                                              // ⚠️ 注意：AnimatedSwitcher 需要 key 才能识别图片变化
                                              // 给 _buildDragonWithColor 里的 Image 加 key，或者在这里加 key
                                              // 最简单的方法是不用 AnimatedSwitcher，只改上面的时间其实就够了
                                            ),
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

  Widget _buildSmallEquipBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 10),
    );
  }
}

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
    // 🔥 [核心修改] 动画时间延长到 3秒 (3000ms)，保证你能看清！
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    // 🔥 0%~80% 都是完全不透明，只有最后 20% 才淡出
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );
    // 🔥 飘动得慢一点
    _position = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -50),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // 弹性弹出效果
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 90),
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
