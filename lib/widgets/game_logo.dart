import 'package:flutter/material.dart';
import 'dart:math' as math;

class GameLogo extends StatelessWidget {
  final double size;
  const GameLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. 底部的盾牌
        Icon(
          Icons.security_rounded, // 这是一个实心的盾牌
          size: size,
          color: Colors.deepPurple,
        ),
        // 2. 中间的剑 (用一个看起来像剑的图标旋转一下)
        // Material 图标库里没有剑，我们用 "colorize" (滴管) 旋转一下勉强模拟，或者用 "flash_on" (闪电)
        // 这里我用 Stack 组合一个类似剑的形状
        Transform.rotate(
          angle: -math.pi / 4, // 旋转 45 度
          child: Icon(
            Icons.colorize_rounded, // 这个图标看起来像一把短剑/匕首
            size: size * 0.6,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
