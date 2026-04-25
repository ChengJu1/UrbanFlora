import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/observation.dart';
import '../../core/models/species.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/plantnet_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/weather_service.dart';
import '../../shared/widgets/achievement_overlay.dart';
import '../../shared/widgets/confidence_ring.dart';
import '../../shared/widgets/observation_image.dart';
import '../../shared/widgets/rarity_badge.dart';
import 'identification_args.dart';

/// Pick one of the top-3 plant guesses, add a note, then save.
class IdentificationScreen extends ConsumerStatefulWidget {
  const IdentificationScreen({required this.args, super.key});
  final IdentificationArgs args;

  @override
  ConsumerState<IdentificationScreen> createState() =>
      _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  late final Future<List<SpeciesCandidate>> _futureCandidates;
  final _notesController = TextEditingController();
  int _selected = 0;
  bool _saving = false;
  bool _shareToCommunity = true;

  @override
  void initState() {
    super.initState();
    _futureCandidates = ref
        .read(plantNetServiceProvider)
        .identify(imagePath: widget.args.imagePath);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save(List<SpeciesCandidate> candidates) async {
    final user = ref.read(authServiceProvider)?.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to save.')),
      );
      return;
    }
    setState(() => _saving = true);

    final fs = ref.read(firestoreServiceProvider);
    final storage = ref.read(storageServiceProvider);
    final weatherSvc = ref.read(weatherServiceProvider);

    Observation? saved;

    // step 1: save to my codex (must succeed, else nothing was saved)
    try {
      final docRef = fs.newObservationRef(user.uid);
      final obsId = docRef.id;

      final uploaded = await storage.uploadObservationPhoto(
        uid: user.uid,
        observationId: obsId,
        localPath: widget.args.imagePath,
      );

      final fix = widget.args.fix;
      final weather = (fix != null)
          ? await weatherSvc.currentWeather(
              lat: fix.latitude, lon: fix.longitude)
          : null;

      saved = Observation(
        id: obsId,
        userId: user.uid,
        photoUrl: uploaded.photoUrl,
        thumbUrl: uploaded.thumbUrl,
        capturedAt: widget.args.capturedAt,
        candidates: candidates,
        chosenSpecies: candidates[_selected],
        latitude: fix?.latitude,
        longitude: fix?.longitude,
        address: fix?.address,
        heading: widget.args.heading,
        weather: weather,
        notes: _notesController.text.trim(),
      );

      await fs.saveObservation(saved);
      await fs.bumpStatsOnNewObservation(
        uid: user.uid,
        capturedAt: widget.args.capturedAt,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    // step 2: publish to community map (allowed to fail)
    String? communityWarning;
    if (_shareToCommunity && saved.hasLocation) {
      try {
        final profile = await fs.ensureProfile(user.uid);
        await fs.publishSighting(
          obs: saved,
          capturerNickname: profile.nickname,
        );
      } on Object catch (e) {
        communityWarning = e.toString();
      }
    } else if (_shareToCommunity && !saved.hasLocation) {
      communityWarning = 'no GPS fix attached';
    }

    if (!mounted) return;
    setState(() => _saving = false);

    await AchievementOverlay.show(
      context,
      commonName: saved.chosenSpecies.commonName,
      scientificName: saved.chosenSpecies.scientificName,
      rarity: saved.chosenSpecies.rarity,
    );
    if (!mounted) return;

    if (communityWarning != null) {
      // photo IS saved to the codex, just not on the community map
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to your codex, but community share failed '
            '($communityWarning). You can retry from the find detail page.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identify')),
      body: FutureBuilder<List<SpeciesCandidate>>(
        future: _futureCandidates,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _LoadingView(imagePath: widget.args.imagePath);
          }
          if (snap.hasError || (snap.data ?? const []).isEmpty) {
            final err = snap.error;
            final friendly = err is PlantNetException
                ? err.friendly
                : err == null
                    ? 'No suggestions came back. Try a clearer angle.'
                    : 'Something went wrong. Please try again.';
            return _ErrorView(
              imagePath: widget.args.imagePath,
              error: friendly,
            );
          }
          final candidates = snap.data!;
          return _ResultView(
            imagePath: widget.args.imagePath,
            candidates: candidates,
            selected: _selected,
            notesController: _notesController,
            shareToCommunity: _shareToCommunity,
            hasLocation: widget.args.fix != null,
            onShareChanged: (v) => setState(() => _shareToCommunity = v),
            onSelect: (i) => setState(() => _selected = i),
            onSave: _saving ? null : () => _save(candidates),
            saving: _saving,
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroImage(path: imagePath),
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Consulting the flora library...',
          style: Theme.of(context).textTheme.bodyMedium,
        ).animate(
          onPlay: (c) => c.repeat(reverse: true),
        ).fadeIn(duration: 800.ms).fadeOut(delay: 800.ms, duration: 800.ms),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.imagePath, required this.error});
  final String imagePath;
  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        _HeroImage(path: imagePath),
        const SizedBox(height: 32),
        Icon(Icons.error_outline, size: 56, color: scheme.error),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Could not identify this one',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try a different photo'),
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.imagePath,
    required this.candidates,
    required this.selected,
    required this.notesController,
    required this.shareToCommunity,
    required this.hasLocation,
    required this.onShareChanged,
    required this.onSelect,
    required this.onSave,
    required this.saving,
  });

  final String imagePath;
  final List<SpeciesCandidate> candidates;
  final int selected;
  final TextEditingController notesController;
  final bool shareToCommunity;
  final bool hasLocation;
  final ValueChanged<bool> onShareChanged;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroImage(path: imagePath),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              Text(
                'Which one matches?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Top-3 Pl@ntNet suggestions, highest confidence first.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < candidates.length; i++) ...[
                _CandidateCard(
                  candidate: candidates[i],
                  selected: i == selected,
                  onTap: () => onSelect(i),
                ).animate(delay: (80 * i).ms).fadeIn().slideY(begin: 0.1),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a personal note (optional)',
                ),
              ),
              const SizedBox(height: 12),
              // toggle: also share on the community map?
              _CommunityToggle(
                value: shareToCommunity,
                hasLocation: hasLocation,
                onChanged: onShareChanged,
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: FilledButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(saving ? 'Saving...' : 'Add to my codex'),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'capture-$path',
      child: Container(
        height: 220,
        width: double.infinity,
        color: Colors.black,
        child: ObservationImage(source: path),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final SpeciesCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ConfidenceRing(value: candidate.score),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.commonName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      candidate.scientificName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        RarityBadge(rarity: candidate.rarity, compact: true),
                        _pill(context, candidate.family),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: selected
                    ? Icon(Icons.check, size: 18, color: scheme.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CommunityToggle extends StatelessWidget {
  const _CommunityToggle({
    required this.value,
    required this.hasLocation,
    required this.onChanged,
  });
  final bool value;
  final bool hasLocation;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = !hasLocation;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.public, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disabled ? 'Community map unavailable' : 'Share to community map',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  disabled
                      ? 'No GPS fix attached, so this find stays private.'
                      : 'Other naturalists nearby can see this find. '
                          'Coordinates round to ~10 m for privacy.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value && !disabled,
            onChanged: disabled ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
