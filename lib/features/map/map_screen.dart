import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/observation.dart';
import '../../core/models/public_sighting.dart';
import '../../core/models/species.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../shared/widgets/observation_image.dart';
import '../../shared/widgets/rarity_badge.dart';

/// Which set of pins the map should show.
enum MapMode { mine, community }

/// Map tab. Toggles between "My finds" (the user's own pins) and a 10 km
/// "Nearby community" circle drawn around the user's current GPS fix.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _map = MapController();

  MapMode _mode = MapMode.mine;
  GeoFix? _userFix;
  bool _fetchingLocation = false;
  bool _showAllCommunity = false;

  // which rarity chips are on
  Set<Rarity> _rarityFilter = Set<Rarity>.of(Rarity.values);

  Future<void> _ensureLocation({bool force = false}) async {
    if (!force && (_userFix != null || _fetchingLocation)) return;
    setState(() => _fetchingLocation = true);
    final fix = await ref.read(locationServiceProvider).currentFix();
    if (!mounted) return;
    setState(() {
      _userFix = fix;
      _fetchingLocation = false;
    });
    if (fix != null) {
      _map.move(LatLng(fix.latitude, fix.longitude), 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get a GPS fix. Check permissions and try again.'),
        ),
      );
    }
  }

  void _switchTo(MapMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == MapMode.community) _ensureLocation();
  }

  void _toggleRarity(Rarity r) {
    setState(() {
      if (_rarityFilter.contains(r)) {
        if (_rarityFilter.length == 1) return; // keep at least one selected
        _rarityFilter = {..._rarityFilter}..remove(r);
      } else {
        _rarityFilter = {..._rarityFilter, r};
      }
    });
  }

  void _toggleScope() {
    setState(() => _showAllCommunity = !_showAllCommunity);
  }

  Future<void> _refresh() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (_mode == MapMode.mine && uid != null) {
      ref.invalidate(recentObservationsProvider(uid));
    } else {
      ref.invalidate(recentPublicSightingsProvider);
      // also re-grab GPS in case we moved
      await _ensureLocation(force: true);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing…'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _fitToPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in to see the map.')));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == MapMode.mine ? 'Your map' : 'Community map',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_mode == MapMode.mine)
            _MineLayer(
              uid: uid,
              controller: _map,
              onFit: _fitToPoints,
              onRefresh: _refresh,
            )
          else
            _CommunityLayer(
              fix: _userFix,
              fetching: _fetchingLocation,
              controller: _map,
              onFit: _fitToPoints,
              rarityFilter: _rarityFilter,
              onToggleRarity: _toggleRarity,
              showAll: _showAllCommunity,
              onToggleScope: _toggleScope,
              onRefresh: _refresh,
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _LocateMeButton(
              busy: _fetchingLocation,
              onTap: () => _ensureLocation(force: true),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SegmentedButton<MapMode>(
            segments: const [
              ButtonSegment(
                value: MapMode.mine,
                icon: Icon(Icons.person_pin_circle_outlined),
                label: Text('My finds'),
              ),
              ButtonSegment(
                value: MapMode.community,
                icon: Icon(Icons.public),
                label: Text('Community'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _switchTo(s.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: scheme.surface,
            ),
          ),
        ),
      ),
    );
  }
}

// my own pins
class _MineLayer extends ConsumerWidget {
  const _MineLayer({
    required this.uid,
    required this.controller,
    required this.onFit,
    required this.onRefresh,
  });
  final String uid;
  final MapController controller;
  final ValueChanged<List<LatLng>> onFit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obsAsync = ref.watch(recentObservationsProvider(uid));
    final scheme = Theme.of(context).colorScheme;

    return obsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (observations) {
        final located =
            observations.where((o) => o.hasLocation).toList(growable: false);
        return Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: located.isEmpty
                    ? const LatLng(51.5074, -0.1278)
                    : LatLng(located.first.latitude!, located.first.longitude!),
                initialZoom: located.isEmpty ? 11 : 14,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.urbanflora.app',
                ),
                MarkerLayer(
                  markers: [
                    for (final obs in located)
                      Marker(
                        point: LatLng(obs.latitude!, obs.longitude!),
                        width: 44,
                        height: 44,
                        child: _PlantPin(
                          rarity: obs.chosenSpecies.rarity,
                          onTap: () => _showMine(context, obs),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (located.isEmpty) _EmptyOverlay(scheme: scheme),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _LegendBar(
                count: located.length,
                label: 'located find',
                onFit: () => onFit([
                  for (final o in located) LatLng(o.latitude!, o.longitude!),
                ]),
                onRefresh: onRefresh,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMine(BuildContext context, Observation obs) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MinePreviewSheet(observation: obs),
    );
  }
}

// everyone's pins (within 10 km, or worldwide)
class _CommunityLayer extends ConsumerWidget {
  const _CommunityLayer({
    required this.fix,
    required this.fetching,
    required this.controller,
    required this.onFit,
    required this.rarityFilter,
    required this.onToggleRarity,
    required this.showAll,
    required this.onToggleScope,
    required this.onRefresh,
  });
  final GeoFix? fix;
  final bool fetching;
  final MapController controller;
  final ValueChanged<List<LatLng>> onFit;
  final Set<Rarity> rarityFilter;
  final ValueChanged<Rarity> onToggleRarity;
  final bool showAll;
  final VoidCallback onToggleScope;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sightingsAsync = ref.watch(recentPublicSightingsProvider);

    return sightingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (all) {
        final origin = fix == null
            ? null
            : LatLng(fix!.latitude, fix!.longitude);

        // when "show all" is on, skip the 10 km radius filter so any
        // sighting on Earth still shows up
        final inRange = (showAll || origin == null)
            ? all
            : all
                .where((s) =>
                    _haversineMetres(
                      origin.latitude,
                      origin.longitude,
                      s.latitude,
                      s.longitude,
                    ) <=
                    AppConstants.communityRadiusMetres)
                .toList();
        final nearby = inRange
            .where((s) => rarityFilter.contains(s.rarity))
            .toList(growable: false);

        return Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter:
                    origin ?? const LatLng(51.5074, -0.1278),
                initialZoom: origin == null ? 11 : 14,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.urbanflora.app',
                ),
                if (origin != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: origin,
                        radius: AppConstants.communityRadiusMetres,
                        useRadiusInMeter: true,
                        color: scheme.primary.withValues(alpha: 0.06),
                        borderColor: scheme.primary.withValues(alpha: 0.4),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (origin != null)
                      Marker(
                        point: origin,
                        width: 22,
                        height: 22,
                        child: _SelfDot(color: scheme.primary),
                      ),
                    for (final s in nearby)
                      Marker(
                        point: LatLng(s.latitude, s.longitude),
                        width: 44,
                        height: 44,
                        child: _PlantPin(
                          rarity: s.rarity,
                          onTap: () => _showCommunity(context, s),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (fetching && origin == null)
              const Center(child: CircularProgressIndicator()),
            if (origin == null && !fetching)
              _LocationDeniedOverlay(scheme: scheme),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LegendBar(
                    count: nearby.length,
                    total: all.length,
                    label: showAll ? 'find' : 'nearby find',
                    onFit: () => onFit([
                      if (origin != null && !showAll) origin,
                      for (final s in nearby)
                        LatLng(s.latitude, s.longitude),
                    ]),
                    trailing: showAll
                        ? 'worldwide'
                        : 'within '
                            '${(AppConstants.communityRadiusMetres / 1000).toStringAsFixed(0)} km',
                    onRefresh: onRefresh,
                  ),
                  const SizedBox(height: 8),
                  _ScopeToggle(showAll: showAll, onToggle: onToggleScope),
                  const SizedBox(height: 8),
                  _RarityFilterBar(
                    selected: rarityFilter,
                    onToggle: onToggleRarity,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCommunity(BuildContext context, PublicSighting s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CommunityPreviewSheet(sighting: s),
    );
  }
}

double _haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _deg2rad(double d) => d * math.pi / 180.0;

// shared bits below

class _PlantPin extends StatelessWidget {
  const _PlantPin({required this.rarity, required this.onTap});
  final Rarity rarity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(rarity.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.local_florist, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SelfDot extends StatelessWidget {
  const _SelfDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _MinePreviewSheet extends StatelessWidget {
  const _MinePreviewSheet({required this.observation});
  final Observation observation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ObservationImage(source: observation.thumbUrl),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        observation.chosenSpecies.commonName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        observation.chosenSpecies.scientificName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      const SizedBox(height: 6),
                      RarityBadge(
                        rarity: observation.chosenSpecies.rarity,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.observation, extra: observation);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Open observation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPreviewSheet extends StatelessWidget {
  const _CommunityPreviewSheet({required this.sighting});
  final PublicSighting sighting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = DateFormat.yMMMd().format(sighting.capturedAt);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: ObservationImage(source: sighting.thumbUrl),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              sighting.commonName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              sighting.scientificName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RarityBadge(rarity: sighting.rarity, compact: true),
                _Pill(text: 'Spotted by ${sighting.capturerNickname}'),
                _Pill(text: when),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location is approximate (~10 m).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  const _LegendBar({
    required this.count,
    required this.label,
    required this.onFit,
    this.total,
    this.trailing,
    this.onRefresh,
  });
  final int count;
  final int? total;
  final String label;
  final VoidCallback onFit;
  final String? trailing;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = total == null || total == count
        ? '$count $label${count == 1 ? '' : 's'}'
        : '$count of $total $label${total == 1 ? '' : 's'}';
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.layers, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$body${trailing == null ? '' : ' • $trailing'}',
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              tooltip: 'Fit to view',
              onPressed: onFit,
              icon: const Icon(Icons.center_focus_strong),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.showAll, required this.onToggle});
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                showAll ? Icons.public : Icons.near_me_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  showAll
                      ? 'Showing finds worldwide'
                      : 'Showing finds within '
                          '${(AppConstants.communityRadiusMetres / 1000).toStringAsFixed(0)} km',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Switch(
                value: showAll,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOverlay extends StatelessWidget {
  const _EmptyOverlay({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_outlined, size: 36, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                'No located finds yet.\nTake a photo outside to drop your first pin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationDeniedOverlay extends StatelessWidget {
  const _LocationDeniedOverlay({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 36, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                'Need your location to show nearby finds.\nEnable GPS and permissions, then reopen this tab.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocateMeButton extends StatelessWidget {
  const _LocateMeButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'map-locate-me',
      tooltip: 'Centre on my location',
      onPressed: busy ? null : onTap,
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location),
    );
  }
}

class _RarityFilterBar extends StatelessWidget {
  const _RarityFilterBar({
    required this.selected,
    required this.onToggle,
  });
  final Set<Rarity> selected;
  final ValueChanged<Rarity> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final r in Rarity.values) ...[
                _RarityChip(
                  rarity: r,
                  selected: selected.contains(r),
                  onTap: () => onToggle(r),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({
    required this.rarity,
    required this.selected,
    required this.onTap,
  });
  final Rarity rarity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(rarity.colorValue);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              rarity.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
