import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nicknameController = TextEditingController();
  bool _saving = false;
  bool _seeded = false;
  bool _resyncing = false;
  String? _message;
  String? _resyncMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save(String uid) async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _message = 'Name cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(firestoreServiceProvider).updateNickname(
            uid: uid,
            nickname: nickname,
          );
      if (!mounted) return;
      setState(() => _message = 'Saved.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider)?.signOut();
    if (mounted) context.go(AppRoutes.signIn);
  }

  Future<void> _resyncCommunity(String uid) async {
    setState(() {
      _resyncing = true;
      _resyncMessage = null;
    });
    final fs = ref.read(firestoreServiceProvider);
    try {
      final profile = await fs.ensureProfile(uid);
      final observations = await fs.allObservations(uid);
      var pushed = 0;
      var skipped = 0;
      for (final obs in observations) {
        if (!obs.hasLocation) {
          skipped += 1;
          continue;
        }
        try {
          await fs.publishSighting(obs: obs, capturerNickname: profile.nickname);
          pushed += 1;
        } on Object catch (e) {
          debugPrint('[Settings] republish failed for ${obs.id}: $e');
        }
      }
      if (!mounted) return;
      setState(() => _resyncMessage =
          'Re-shared $pushed find${pushed == 1 ? '' : 's'}'
          '${skipped == 0 ? '' : ', skipped $skipped without GPS'}.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _resyncMessage = 'Could not re-sync: $e');
    } finally {
      if (mounted) setState(() => _resyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final uid = user?.uid;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to edit your profile.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.isAnonymous == true
                              ? 'Anonymous explorer'
                              : user?.email ?? 'Signed in',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileForm(
                  uid: uid,
                  controller: _nicknameController,
                  saving: _saving,
                  seeded: _seeded,
                  message: _message,
                  onSeeded: () => _seeded = true,
                  onSave: () => _save(uid),
                ),
                const SizedBox(height: 16),
                _CommunitySyncCard(
                  busy: _resyncing,
                  message: _resyncMessage,
                  onTap: () => _resyncCommunity(uid),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
    );
  }
}

class _ProfileForm extends ConsumerWidget {
  const _ProfileForm({
    required this.uid,
    required this.controller,
    required this.saving,
    required this.seeded,
    required this.message,
    required this.onSeeded,
    required this.onSave,
  });

  final String uid;
  final TextEditingController controller;
  final bool saving;
  final bool seeded;
  final String? message;
  final VoidCallback onSeeded;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    final scheme = Theme.of(context).colorScheme;

    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Could not load profile: $e'),
      data: (p) {
        if (!seeded) {
          controller.text = p.nickname;
          onSeeded();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!saving) onSave();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(label: 'Finds', value: '${p.totalObservations}'),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Streak', value: '${p.streak}'),
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    style: TextStyle(
                      color: message == 'Saved.' ? scheme.primary : scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save name'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommunitySyncCard extends StatelessWidget {
  const _CommunitySyncCard({
    required this.busy,
    required this.message,
    required this.onTap,
  });

  final bool busy;
  final String? message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community map',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Re-publish all your saved finds. Useful if a photo failed to '
              'reach the community map (network glitch, etc).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: TextStyle(color: scheme.primary),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onTap,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
              label: Text(busy ? 'Re-syncing...' : 'Re-share my finds'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
