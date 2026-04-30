import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/models/species.dart';

class AchievementOverlay {
  const AchievementOverlay._();

  static Future<void> show(
    BuildContext context, {
    required String commonName,
    required String scientificName,
    required Rarity rarity,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => _AchievementView(
          commonName: commonName,
          scientificName: scientificName,
          rarity: rarity,
        ),
      ),
    );
  }
}

class _AchievementView extends StatefulWidget {
  const _AchievementView({
    required this.commonName,
    required this.scientificName,
    required this.rarity,
  });

  final String commonName;
  final String scientificName;
  final Rarity rarity;

  @override
  State<_AchievementView> createState() => _AchievementViewState();
}

class _AchievementViewState extends State<_AchievementView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.rarity.colorValue);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: AnimatedBuilder(
                    animation: _ring,
                    builder: (_, __) => CustomPaint(
                      painter: _BurstPainter(
                        progress: _ring.value,
                        color: color,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: color,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(),
                const SizedBox(height: 16),
                Text(
                  'New species!',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 2,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 4),
                Text(
                  widget.commonName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                Text(
                  widget.scientificName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    widget.rarity.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    // outer ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, maxR - 4, ringPaint);

    // rays
    final rayPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final rad = 2 * math.pi * (i / rays) + progress * 2 * math.pi;
      final innerR = maxR * 0.6;
      final outerR = maxR * (0.85 + 0.1 * math.sin(progress * 4 * math.pi + i));
      canvas.drawLine(
        Offset(
          center.dx + math.cos(rad) * innerR,
          center.dy + math.sin(rad) * innerR,
        ),
        Offset(
          center.dx + math.cos(rad) * outerR,
          center.dy + math.sin(rad) * outerR,
        ),
        rayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
