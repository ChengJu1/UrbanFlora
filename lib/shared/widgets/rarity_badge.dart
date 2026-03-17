import 'package:flutter/material.dart';

import '../../core/models/species.dart';

/// Coloured pill that shows a species' rarity tier.
class RarityBadge extends StatelessWidget {
  const RarityBadge({required this.rarity, this.compact = false, super.key});

  final Rarity rarity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(rarity.colorValue);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            rarity.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
