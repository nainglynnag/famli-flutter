import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/secure_storage.dart';
import '../models/user.dart';
import 'api_provider.dart';

/// Mirrors mobile/src/context/AuthContext.tsx.
///
/// Sessions work differently per backend, which is why this class still knows
/// which one is active even though [apiClientProvider] hides the rest of the
/// difference. Firebase Auth persists its own session, so there is no token to
/// store; the Express API issues a JWT that has to be kept in secure storage.
class AuthState {
  const AuthState({this.token, this.profile});

  final String? token;
  final UserSummary? profile;

  bool get isAuthenticated => token != null;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final SecureStorage _storage = SecureStorage();

  @override
  Future<AuthState> build() async {
    final token = Env.useFirebaseBackend
        ? await _firebaseToken()
        : await _storage.read(Env.authStorageKey);
    if (token == null) return const AuthState();

    try {
      final profile = await ref.read(apiClientProvider).fetchProfile(token);
      return AuthState(token: token, profile: profile);
    } catch (_) {
      // Signed in but the profile is unreadable — e.g. the user document was
      // deleted when they were removed from a family, or the JWT expired.
      await _clearSession();
      return const AuthState();
    }
  }

  /// `FirebaseAuth.currentUser` can read null immediately after
  /// `Firebase.initializeApp()` even with a persisted session — on web,
  /// restoring that session from IndexedDB is asynchronous. Reading it
  /// synchronously here raced a real Firestore read against that restore and
  /// lost, sending an unauthenticated request straight into the rules'
  /// deny-by-default. Waiting for the first authStateChanges() emission
  /// blocks until restoration (or its absence) is actually known.
  Future<String?> _firebaseToken() async {
    final user = await _auth.authStateChanges().first;
    return user?.getIdToken();
  }

  Future<void> _persist(String token) async {
    if (Env.useFirebaseBackend) return;
    await _storage.write(Env.authStorageKey, token);
  }

  Future<void> _clearSession() async {
    if (Env.useFirebaseBackend) {
      await _auth.signOut();
      return;
    }
    await _storage.delete(Env.authStorageKey);
  }

  Future<void> login(String identifier, String password) async {
    final response = await ref
        .read(apiClientProvider)
        .login(identifier, password);
    await _persist(response.token);
    state = AsyncData(AuthState(token: response.token, profile: response.user));
  }

  Future<void> registerParent(RegisterParentPayload payload) async {
    final response = await ref.read(apiClientProvider).registerParent(payload);
    await _persist(response.token);
    state = AsyncData(
      AuthState(token: response.token, profile: response.parent),
    );
  }

  Future<void> logout() async {
    await _clearSession();
    state = const AsyncData(AuthState());
  }

  Future<void> refreshProfile() async {
    final current = state.value;
    final token = current?.token;
    if (token == null) return;
    try {
      final profile = await ref.read(apiClientProvider).fetchProfile(token);
      state = AsyncData(AuthState(token: token, profile: profile));
    } catch (_) {
      // Best-effort refresh, same as AuthContext's invalidateQueries.
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
