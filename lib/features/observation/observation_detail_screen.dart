import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/observation.dart';
import '../../core/services/share_service.dart';
import '../../shared/widgets/observation_image.dart';
import '../../shared/widgets/rarity_badge.dart';

/// Full detail page for one saved observation. Big hero photo, species info,
/// time / place / weather metadata, notes, and a share button.
class ObservationDetailScreen extends ConsumerStatefulWidget {
  const ObservationDetailScreen({required this.observation, super.key});
  final Observation observation;

  @override
  ConsumerState<ObservationDetailScreen> createState() =>
      _ObservationDetailScreenState();
}

class _ObservationDetailScreenState
    extends ConsumerState<ObservationDetailScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final outcome = await ref
          .read(shareServiceProvider)
          .shareObservation(widget.observation);
      if (!mounted) return;
      _showShareFeedback(outcome);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showShareFeedback(ShareOutcome outcome) {
    final messenger = ScaffoldMessenger.of(context);
    final url = widget.observation.photoUrl;
    final canCopyLink = url.startsWith('http');
    switch (outcome) {
      case ShareOutcome.success:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Shared!'),
            behavior: SnackBarBehavior.floating,
            action: canCopyLink
                ? SnackBarAction(
                    label: 'Copy link',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Photo link copied to clipboard.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      case ShareOutcome.dismissed:
        // user cancelled, no message
        break;
      case ShareOutcome.unavailable:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No share targets available on this device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final obs = widget.observation;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: scheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'obs-${obs.id}',
                child: ObservationImage(source: obs.photoUrl),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Share this find',
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obs.chosenSpecies.commonName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    obs.chosenSpecies.scientificName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RarityBadge(rarity: obs.chosenSpecies.rarity),
                      _chip(context, Icons.account_tree_outlined,
                          obs.chosenSpecies.family),
                      _chip(
                        context,
                        Icons.percent,
                        'Confidence ${(obs.chosenSpecies.score * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Captured'),
                  _MetaRow(
                    icon: Icons.schedule,
                    label: DateFormat.yMMMMEEEEd().add_Hm().format(obs.capturedAt),
                  ),
                  if (obs.address != null && obs.address!.isNotEmpty)
                    _MetaRow(
                      icon: Icons.place_outlined,
                      label: obs.address!,
                    )
                  else if (obs.hasLocation)
                    _MetaRow(
                      icon: Icons.place_outlined,
                      label:
                          '${obs.latitude!.toStringAsFixed(4)}, ${obs.longitude!.toStringAsFixed(4)}',
                    )
                  else
                    const _MetaRow(
                      icon: Icons.place_outlined,
                      label: 'Location unavailable',
                    ),
                  if (obs.heading != null)
                    _MetaRow(
                      icon: Icons.explore_outlined,
                      label: 'Facing ${obs.heading!.toStringAsFixed(0)}° ${_compass(obs.heading!)}',
                    ),
                  if (obs.weather != null)
                    _MetaRow(
                      icon: Icons.wb_sunny_outlined,
                      label:
                          '${obs.weather!.tempC.toStringAsFixed(1)}°C • ${obs.weather!.description} • humidity ${obs.weather!.humidity}%',
                    ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: 'Other candidates'),
                  const SizedBox(height: 6),
                  for (final c in obs.candidates.where(
                      (c) => c.scientificName != obs.chosenSpecies.scientificName))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${c.commonName} · ${c.scientificName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${(c.score * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  if (obs.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Your note'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(obs.notes),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _compass(double deg) {
    const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = (((deg % 360) + 22.5) / 45).floor() % 8;
    return points[idx];
  }

  Widget _chip(BuildContext context, IconData icon, String text) {
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
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
