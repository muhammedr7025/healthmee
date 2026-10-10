import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/auth_storage.dart';

/// Product analytics: every meaningful interaction becomes a named event
/// with a few counts/ids as properties — never message text or health
/// values — queued locally and sent to our own `/events` endpoint in
/// batches. Nothing here can block or break the user's real work: tracking
/// is fire-and-forget and a failed flush just keeps the batch for later.
class Analytics with WidgetsBindingObserver {
  Analytics(this._storage)
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
    PackageInfo.fromPlatform().then(
      (info) => _appVersion = '${info.version}+${info.buildNumber}',
      onError: (Object _) {}, // no version is fine; events still flow
    );
  }

  final AuthStorage _storage;
  final Dio _dio;
  final _queue = <Map<String, dynamic>>[];
  late final Timer _timer;
  bool _flushing = false;
  String? _appVersion;

  /// One per process launch; lets a session's events be grouped.
  final String sessionId = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

  static const _maxQueue = 500;
  static const _batchSize = 50;

  /// Record an event. Props must be small and PHI-free (ids, counts, enums).
  void track(String name, [Map<String, dynamic> props = const {}]) {
    if (_queue.length >= _maxQueue) _queue.removeAt(0); // drop the oldest rather than grow without bound
    _queue.add({'name': name, 'props': props, 'client_ts': DateTime.now().toUtc().toIso8601String()});
    if (_queue.length >= _batchSize) flush();
  }

  /// Crashes and caught-but-unexpected errors, with just enough to find
  /// them: the type and the first frame, never the message (it can carry
  /// user text).
  void trackError(Object error, StackTrace? stack, {String where = 'zone'}) {
    final frame = stack?.toString().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '') ?? '';
    track('app_error', {'type': error.runtimeType.toString(), 'frame': frame.trim().substring(0, min(frame.trim().length, 160)), 'where': where});
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    final token = await _storage.readToken();
    if (token == null) return; // events wait until there's a session to attribute them to
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue.take(_batchSize));
    try {
      await _dio.post(
        '/events',
        data: {
          'platform': _platform,
          'app_version': _appVersion,
          'session_id': sessionId,
          'events': batch,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _queue.removeRange(0, batch.length);
    } catch (_) {
      // Keep the batch; the next tick or the next launch retries.
    } finally {
      _flushing = false;
    }
  }

  String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'other',
      };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      flush();
      track('app_background');
    } else if (state == AppLifecycleState.resumed) {
      track('app_foreground');
    }
  }

  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final analyticsProvider = Provider<Analytics>((ref) {
  final analytics = Analytics(ref.watch(authStorageProvider));
  ref.onDispose(analytics.dispose);
  return analytics;
});

/// Tracks pushed/popped routes as screen_view events (the bottom tabs are
/// tracked separately by the shell, since they aren't routes).
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);
  final Analytics _analytics;

  void _view(Route<dynamic>? route, String how) {
    final name = route?.settings.name ?? route?.runtimeType.toString();
    if (name == null) return;
    _analytics.track('screen_view', {'screen': name, 'how': how});
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _view(route, 'push');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _view(previousRoute, 'pop');
}
