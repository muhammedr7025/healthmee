import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// `offline` = there is a stored session but the API couldn't be reached at
/// launch. Distinct from `unauthenticated` so the app shows "can't reach
/// Health MEE — retry" rather than the Welcome screen to someone who is, in
/// fact, signed in.
enum AuthStatus { checking, unauthenticated, authenticated, offline }

class AuthState {
  const AuthState({required this.status, this.user, this.error});

  final AuthStatus status;
  final AppUser? user;
  final String? error;

  AuthState copyWith({AuthStatus? status, AppUser? user, String? error}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user, error: error);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, Ref ref) : super(const AuthState(status: AuthStatus.checking)) {
    // The API layer could not rescue a 401 with the refresh token: the
    // session is really over, so show the login screen instead of errors.
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      if (state.status == AuthStatus.authenticated) {
        state = const AuthState(status: AuthStatus.unauthenticated, error: 'Your session expired — please sign in again.');
      }
    });
    _restoreSession();
  }

  final AuthRepository _repo;

  Future<void> _restoreSession() async {
    try {
      final user = await _repo.currentUser();
      state = AuthState(status: user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      final hadSession = await _repo.hasStoredSession();
      final networkProblem = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          (e.response?.statusCode ?? 0) >= 500;
      // Signed in but the API is unreachable: say so and offer a retry.
      // Anything else falls back to the login screen as before.
      state = AuthState(status: hadSession && networkProblem ? AuthStatus.offline : AuthStatus.unauthenticated);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// The "Retry" on the offline screen.
  Future<void> retry() async {
    state = const AuthState(status: AuthStatus.checking);
    await _restoreSession();
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
  return AuthController(ref.watch(authRepositoryProvider), ref);
});

/// The signed-in user's id, or null. Per-user state (chat thread, onboarding
/// draft, logbook filters) watches this so a different account signing in
/// starts clean instead of inheriting the previous person's data.
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(authControllerProvider.select((s) => s.user?.id)));
