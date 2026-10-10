import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'auth_storage.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Bumped by the API layer when a request came back 401 and the refresh
/// token couldn't rescue it — the auth controller listens and signs out,
/// so the user sees the login screen instead of every tab erroring.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(authStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    // Extraction can take a real LLM 10–20 s; anything past this is a hang.
    receiveTimeout: const Duration(seconds: 45),
    sendTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Minutes east of UTC. The backend buckets "today" and resolves
        // "yesterday"/"for dinner" against this rather than the server's
        // clock — without it, an IST user's post-midnight logs land on the
        // previous day.
        options.headers['X-Timezone-Offset'] = DateTime.now().timeZoneOffset.inMinutes.toString();
        handler.next(options);
      },
    ),
  );

  // Queued so several 401s arriving together share one refresh instead of
  // racing each other (and each rotating the refresh token).
  dio.interceptors.add(_SessionRefreshInterceptor(dio, storage, onExpired: () {
    ref.read(sessionExpiredProvider.notifier).state++;
  }));

  return dio;
});

class _SessionRefreshInterceptor extends QueuedInterceptorsWrapper {
  _SessionRefreshInterceptor(this._dio, this._storage, {required this.onExpired});

  final Dio _dio;
  final AuthStorage _storage;
  final void Function() onExpired;

  static const _noRefreshPaths = {'/auth/login', '/auth/register', '/auth/refresh', '/auth/password/reset-request', '/auth/password/reset-confirm'};

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final alreadyRetried = err.requestOptions.extra['retried_after_refresh'] == true;
    if (err.response?.statusCode != 401 || _noRefreshPaths.contains(path) || alreadyRetried) {
      return handler.next(err);
    }

    final refresh = await _storage.readRefreshToken();
    if (refresh == null) {
      await _storage.clearToken();
      onExpired();
      return handler.next(err);
    }

    try {
      // A bare client: no interceptors, so a failing refresh can't recurse.
      final resp = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl, connectTimeout: const Duration(seconds: 15)))
          .post('/auth/refresh', options: Options(headers: {'Authorization': 'Bearer $refresh'}));
      final data = resp.data as Map<String, dynamic>;
      await _storage.saveTokens(access: data['access_token'] as String, refresh: data['refresh_token'] as String?);
    } on DioException {
      // Refresh token expired or revoked — there's nothing left to try.
      await _storage.clearToken();
      onExpired();
      return handler.next(err);
    }

    // Replay the original request once with the new token.
    final options = err.requestOptions;
    options.extra['retried_after_refresh'] = true;
    options.headers['Authorization'] = 'Bearer ${await _storage.readToken()}';
    try {
      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
