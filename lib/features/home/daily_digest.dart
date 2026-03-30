import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/observation.dart';
import '../../core/models/species.dart';

/// Once-a-day "yesterday's finds" recap sheet.
class DailyDigest {
  const DailyDigest._();

  static const _lastShownKey = 'daily_digest_last_shown';

  /// Show the digest at most once per day. No-op if there's nothing to show.
  static Future<void> maybeShow(
    BuildContext context,
    List<Observation> observations,
  ) async {
    if (observations.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString(_lastShownKey) == todayKey) return;
    await prefs.setString(_lastShownKey, todayKey);

    if (!context.mounted) return;

    final stats = _DigestStats.compute(observations);
    await showDialog<void>(
      context: context,
      builder: (_) => _DigestDialog(stats: stats),
    );
  }
}

class _DigestStats {
  _DigestStats({
    required this.todayCount,
    required this.yesterdayCount,
    required this.uniqueFamilies,
    required this.topRarity,
    required this.totalSpecies,
  });

  final int todayCount;
  final int yesterdayCount;
  final int uniqueFamilies;
  final Rarity topRarity;
  final int totalSpecies;

  factory _DigestStats.compute(List<Observation> obs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int todayCount = 0;
    int yesterdayCount = 0;
    final families = <String>{};
    final species = <String>{};
    Rarity topRarity = Rarity.common;

    for (final o in obs) {
      final d = DateTime(o.capturedAt.year, o.capturedAt.month, o.capturedAt.day);
      if (d == today) todayCount++;
      if (d == yesterday) yesterdayCount++;
      families.add(o.chosenSpecies.family);
      species.add(o.chosenSpecies.scientificName);
      if (o.chosenSpecies.rarity.index > topRarity.index) {
        topRarity = o.chosenSpecies.rarity;
      }
    }

    return _DigestStats(
      todayCount: todayCount,
      yesterdayCount: yesterdayCount,
      uniqueFamilies: families.length,
      topRarity: topRarity,
      totalSpecies: species.length,
    );
  }
}

class _DigestDialog extends StatelessWidget {
  const _DigestDialog({required this.stats});
  final _DigestStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final prefix = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_twilight, color: scheme.secondary)
                    .animate()
                    .rotate(
                      begin: -0.1,
                      end: 0.05,
                      duration: 1200.ms,
                    ),
                const SizedBox(width: 8),
                Text(
                  '$prefix, botanist',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _headline(stats),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _digestChip(context, Icons.local_florist,
                    '${stats.todayCount} today'),
                _digestChip(context, Icons.history,
                    '${stats.yesterdayCount} yesterday'),
                _digestChip(context, Icons.account_tree,
                    '${stats.uniqueFamilies} families'),
                _digestChip(context, Icons.auto_awesome,
                    'Rarest: ${stats.topRarity.label}'),
                _digestChip(context, Icons.library_books,
                    '${stats.totalSpecies} species'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _reflection(stats),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep noticing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headline(_DigestStats s) {
    if (s.todayCount == 0 && s.yesterdayCount == 0) {
      return 'Your codex waits for you.';
    }
    if (s.todayCount > 0) {
      return 'You have already written ${s.todayCount} page${s.todayCount == 1 ? '' : 's'} today.';
    }
    return 'Yesterday gave you ${s.yesterdayCount} new chapter${s.yesterdayCount == 1 ? '' : 's'}.';
  }

  String _reflection(_DigestStats s) {
    if (s.uniqueFamilies >= 3) {
      return 'Your finds span ${s.uniqueFamilies} botanical families — your neighbourhood is more diverse than it looks.';
    }
    if (s.topRarity == Rarity.legendary) {
      return 'One legendary sighting. That is rare even for career botanists.';
    }
    return 'Keep the streak alive; every photo makes the city\'s biodiversity map a little sharper.';
  }

  Widget _digestChip(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}
