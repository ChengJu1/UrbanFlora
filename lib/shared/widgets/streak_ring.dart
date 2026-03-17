import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Big circular streak counter shown on the home dashboard.
class StreakRing extends StatelessWidget {
  const StreakRing({
    required this.streak,
    required this.total,
    this.targetDays = 7,
    this.size = 180,
    super.key,
  });

  final int streak;
  final int total;
  final int targetDays;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _StreakPainter(
          streak: streak,
          targetDays: targetDays,
          trackColor: scheme.surfaceContainerHighest,
          fillColor: scheme.primary,
          tickColor: scheme.secondary,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$streak',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                streak == 1 ? 'day streak' : 'day streak',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '$total observations',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter({
    required this.streak,
    required this.targetDays,
    required this.trackColor,
    required this.fillColor,
    required this.tickColor,
  });

  final int streak;
  final int targetDays;
  final Color trackColor;
  final Color fillColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 10;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final ratio = (streak / targetDays).clamp(0, 1).toDouble();
    if (ratio > 0) {
      final fill = Paint()
        ..shader = SweepGradient(
          colors: [fillColor, tickColor, fillColor],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        fill,
      );
    }

    // a dot per day observed
    final visibleDays = streak.clamp(0, targetDays);
    final tick = Paint()
      ..color = tickColor
      ..style = PaintingStyle.fill;
    for (var i = 0; i < visibleDays; i++) {
      final rad = -math.pi / 2 + 2 * math.pi * (i / targetDays);
      final p = Offset(
        center.dx + math.cos(rad) * radius,
        center.dy + math.sin(rad) * radius,
      );
      canvas.drawCircle(p, 4, tick);
    }
  }

  @override
  bool shouldRepaint(_StreakPainter old) =>
      old.streak != streak || old.targetDays != targetDays;
}
