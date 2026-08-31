import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/user.dart';

enum AuthStatus { checking, unauthenticated, authenticated }

class AuthState {
  const AuthState({required this.status, this.user, this.error});

  final AuthStatus status;
  final AppUser? user;
  final String? error;

  AuthState copyWith({AuthStatus? status, AppUser? user, String? error}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user, error: error);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState(status: AuthStatus.checking)) {
    _restoreSession();
  }

  final AuthRepository _repo;

  Future<void> _restoreSession() async {
    try {
      final user = await _repo.currentUser();
      state = AuthState(status: user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated, user: user);
    } catch (_) {
      // Unreachable API at launch shouldn't crash the app — fall back to the
      // login screen; the user can retry once connectivity/the API is back.
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _repo.login(email: email, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> register({required String email, required String password, String? fullName}) async {
    final user = await _repo.register(email: email, password: password, fullName: fullName);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void markOnboardingComplete() {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(user: user.copyWith(onboardingCompleted: true));
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
