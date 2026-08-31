import 'dart:io' show Platform;

/// The Flask API's base URL. Android emulators route "localhost" to the
/// emulator itself, not the host machine, hence the 10.0.2.2 alias; iOS
/// simulators and desktop can reach the host directly. Override with
/// --dart-define=API_BASE_URL=... for a physical device or staging server.
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!Platform.isAndroid) return 'http://localhost:5000/api/v1';
    return 'http://10.0.2.2:5000/api/v1';
  }
}
