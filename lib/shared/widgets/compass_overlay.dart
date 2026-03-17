import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small compass overlaid on the camera viewfinder so users can record the
/// direction they were facing when they took the photo.
class CompassOverlay extends StatelessWidget {
  const CompassOverlay({required this.heading, super.key});

  final double? heading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: CustomPaint(
            size: const Size(160, 160),
            painter: _CompassPainter(heading: heading),
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.heading});
  final double? heading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 2, ring);

    // tick every 30 degrees
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (var deg = 0; deg < 360; deg += 30) {
      final rad = deg * math.pi / 180;
      final outer = Offset(
        center.dx + math.sin(rad) * (radius - 4),
        center.dy - math.cos(rad) * (radius - 4),
      );
      final inner = Offset(
        center.dx + math.sin(rad) * (radius - (deg % 90 == 0 ? 18 : 10)),
        center.dy - math.cos(rad) * (radius - (deg % 90 == 0 ? 18 : 10)),
      );
      canvas.drawLine(inner, outer, tick);
    }

    // north pointer
    final rotation = heading == null ? 0.0 : -heading! * math.pi / 180;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final pointer = Path()
      ..moveTo(0, -radius + 18)
      ..lineTo(8, 0)
      ..lineTo(-8, 0)
      ..close();
    canvas.drawPath(
      pointer,
      Paint()..color = const Color(0xFFE2A93B),
    );
    canvas.drawCircle(Offset.zero, 3, Paint()..color = Colors.white);
    canvas.restore();

    final label = TextPainter(
      text: TextSpan(
        text: heading == null ? '—°' : '${heading!.toStringAsFixed(0)}°',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(center.dx - label.width / 2, center.dy + radius * 0.35),
    );
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) => oldDelegate.heading != heading;
}
