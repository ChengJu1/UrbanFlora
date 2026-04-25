import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/observation.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/widgets/observation_card.dart';
import '../../shared/widgets/streak_ring.dart';
import 'daily_digest.dart';

/// Home tab — streak ring, recent finds, daily digest popup.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _digestChecked = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final uid = user?.uid;
    final scheme = Theme.of(context).colorScheme;

    // show daily digest once per day
    if (uid != null && !_digestChecked) {
      final obsAsync = ref.watch(recentObservationsProvider(uid));
      obsAsync.whenData((list) {
        _digestChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          DailyDigest.maybeShow(context, list);
        });
      });
    }

    return Scaffold(
      body: SafeArea(
        child: uid == null
            ? const Center(child: Text('Sign in to see your codex.'))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: scheme.surface,
                    title: _Greeting(uid: uid),
                    titleSpacing: 16,
                    actions: [
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => context.push(AppRoutes.settings),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await ref.read(authServiceProvider)?.signOut();
                          if (context.mounted) context.go(AppRoutes.signIn);
                        },
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: _StreakCard(uid: uid),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                      child: Row(
                        children: [
                          Text(
                            'Recent finds',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat.yMMMd().format(DateTime.now()),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _ObservationList(uid: uid),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
                ],
              ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    final hour = DateTime.now().hour;
    final salute = hour < 5
        ? 'Late owl'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';

    final base = Theme.of(context).textTheme.titleLarge;
    return profile.when(
      loading: () => Text(
        '$salute…',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      ),
      error: (_, __) => Text(
        '$salute, botanist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      ),
      data: (p) => Text(
        '$salute, ${p.nickname}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: profile.when(
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 180,
          child: Center(child: Text('Profile error: $e')),
        ),
        data: (p) {
          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'You are a sensor node.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Every photo you take plugs another pixel into your city\'s biodiversity map.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final badge in p.badges.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.onPrimaryContainer
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              // narrow screen: stack instead of row
              final narrow = constraints.maxWidth < 360;
              final ring = StreakRing(
                streak: p.streak,
                total: p.totalObservations,
                size: narrow ? 140 : 180,
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: ring),
                    const SizedBox(height: 16),
                    body,
                  ],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 16),
                  Expanded(child: body),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ObservationList extends ConsumerWidget {
  const _ObservationList({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observations = ref.watch(recentObservationsProvider(uid));
    return observations.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load observations: $e'),
        ),
      ),
      data: (list) {
        if (list.isEmpty) return const _EmptyState();
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final Observation obs = list[i];
              return ObservationCard(
                observation: obs,
                onTap: () => context.push(AppRoutes.observation, extra: obs),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.eco_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Your codex is blank.\nTap the shutter to write its first page.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
