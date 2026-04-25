import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps FirebaseAuth + Google sign-in.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Fires every time the user signs in / out.
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Sign in as a guest (no account needed).
  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// Make a new email/password account.
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user != null && nickname.trim().isNotEmpty) {
      await user.updateDisplayName(nickname.trim());
    }
    return user;
  }

  /// Email + password sign in.
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user;
  }

  /// Sign in with the Google account picker.
  Future<User?> signInWithGoogle() async {
    final gUser = await _googleSignIn.signIn();
    if (gUser == null) return null;
    final gAuth = await gUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final result = await _auth.signInWithCredential(cred);
    return result.user;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}

final authServiceProvider = Provider<AuthService?>((_) {
  try {
    return AuthService();
  } on Object {
    return null;
  }
});

final authStateProvider = StreamProvider<User?>((ref) {
  final svc = ref.watch(authServiceProvider);
  if (svc == null) return Stream<User?>.value(null);
  try {
    return svc.authStateChanges();
  } on Object {
    return Stream<User?>.value(null);
  }
});
