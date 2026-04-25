import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

/// Sign-in / sign-up screen.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _registerMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

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
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // turn ugly firebase errors into something a user can understand
  String _friendlyAuthError(Object e) {
    final s = e.toString();
    if (s.contains('sign_in_failed') && s.contains('12500')) {
      return 'Google Sign-In needs Google Play services, which are not '
          'available on this device. Use email or explore anonymously instead.';
    }
    if (s.contains('sign_in_canceled') || s.contains('canceled')) {
      return 'Sign-in was cancelled.';
    }
    if (s.contains('network_error') || s.contains('network-request-failed')) {
      return 'Network error. Check your connection and try again.';
    }
    if (s.contains('email-already-in-use')) {
      return 'That email is already registered. Try signing in instead.';
    }
    if (s.contains('invalid-email')) {
      return 'That email address does not look right.';
    }
    if (s.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (s.contains('user-not-found')) {
      return 'No account found with this email. Tap "Create an account" '
          'below to sign up.';
    }
    if (s.contains('wrong-password')) {
      return 'Password does not match this account.';
    }
    // when email enumeration protection is on, firebase folds the two
    // cases above into this one, so we just say something general
    if (s.contains('invalid-credential') ||
        s.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Email or password is incorrect. Check both and try again.';
    }
    if (s.contains('too-many-requests')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    return 'Sign-in failed. Please try again.';
  }

  Future<void> _submitEmail() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final nickname = _nicknameController.text.trim();

    if (email.isEmpty || password.length < 6) {
      setState(() => _error = 'Use an email and a password with 6+ characters.');
      return;
    }
    if (_registerMode && nickname.isEmpty) {
      setState(() => _error = 'Pick a display name for your profile.');
      return;
    }

    await _go(() async {
      final user = _registerMode
          ? await auth.registerWithEmail(
              email: email,
              password: password,
              nickname: nickname,
            )
          : await auth.signInWithEmail(email: email, password: password);
      if (user != null && _registerMode) {
        await ref.read(firestoreServiceProvider).updateNickname(
              uid: user.uid,
              nickname: nickname,
            );
      }
      return user;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    // already signed in -> jump straight to home
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
          child: ListView(
            children: [
              const SizedBox(height: 24),
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
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction:
                    _registerMode ? TextInputAction.next : TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) {
                  if (!_registerMode && !_busy) _submitEmail();
                },
              ),
              if (_registerMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nicknameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  onSubmitted: (_) {
                    if (!_busy) _submitEmail();
                  },
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _submitEmail,
                icon: Icon(
                  _registerMode
                      ? Icons.person_add_alt_1
                      : Icons.login_rounded,
                ),
                label: Text(_registerMode ? 'Create account' : 'Sign in'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _registerMode = !_registerMode;
                          _error = null;
                        });
                      },
                child: Text(
                  _registerMode
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
              const SizedBox(height: 8),
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
