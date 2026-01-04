import 'dart:math'; // 需要用到 sin 和 pi
import 'package:flutter/material.dart';

class ShakeWidget extends StatelessWidget {
  final Widget child;
  final AnimationController controller;

  const ShakeWidget({super.key, required this.child, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 使用正弦波生成左右晃动的位移 (振幅 10)
        final double offset = 10 * sin(controller.value * 3 * pi);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: child,
    );
  }
}
