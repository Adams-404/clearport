import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Three softly pulsing dots shown while the first token is in flight.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.size = 6});

  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.palette.muted;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final wave =
                (math.sin((_controller.value * 2 * math.pi) - index * 0.9) +
                    1) /
                2;
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : widget.size),
              child: Opacity(
                opacity: 0.28 + 0.72 * wave,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
