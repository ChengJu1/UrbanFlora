import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/observation.dart';
import 'observation_image.dart';
import 'rarity_badge.dart';

/// Tappable list-row card showing one observation: thumbnail, species, time
/// and rarity badge. Used on the home feed.
class ObservationCard extends StatelessWidget {
  const ObservationCard({
    required this.observation,
    required this.onTap,
    super.key,
  });

  final Observation observation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'obs-${observation.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 72,
                    width: 72,
                    child: ObservationImage(source: observation.thumbUrl),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      observation.chosenSpecies.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      observation.chosenSpecies.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RarityBadge(
                          rarity: observation.chosenSpecies.rarity,
                          compact: true,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DateFormat.MMMd().add_Hm().format(observation.capturedAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
