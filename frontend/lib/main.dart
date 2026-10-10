import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/analytics/analytics.dart';

void main() {
  final container = ProviderContainer();
  final analytics = container.read(analyticsProvider);

  // Crashes become events we can count, with the error type and first frame
  // only — never the message, which can carry what the user typed.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    analytics.trackError(details.exception, details.stack, where: 'flutter');
  };

  runZonedGuarded(
    () {
      analytics.track('app_open');
      runApp(UncontrolledProviderScope(container: container, child: const HealthApp()));
    },
    (error, stack) => analytics.trackError(error, stack, where: 'zone'),
  );
}
