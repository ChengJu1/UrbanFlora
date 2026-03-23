import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';

/// Welcome / sign-in screen. Offers Google sign-in and anonymous explore.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _go(Future<dynamic> Function() op) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await op();
      if (!mounted) return;
      if (result != null) context.go(AppRoutes.home);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    // auto-jump to home if session restores
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null && mounted) context.go(AppRoutes.home);
      });
    });
    if (auth == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Firebase is not configured yet.\nRun `flutterfire configure` to enable sign-in.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.local_florist, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Welcome, botanist.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to sync your finds across devices,\nor explore anonymously.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              if (!kIsWeb) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _go(auth.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _busy ? null : () => _go(auth.signInAnonymously),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore anonymously'),
              ),
              const SizedBox(height: 32),
              Text(
                'By continuing you agree to photograph responsibly\nand avoid trespassing private gardens.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
