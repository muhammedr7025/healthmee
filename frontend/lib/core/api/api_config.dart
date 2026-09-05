/// The Flask API's base URL. Defaults to the deployed production API — the
/// backend a real device (or a plain `flutter run` with no flags) actually
/// needs to reach; "localhost" from a physical phone means the phone
/// itself, not this machine, which silently breaks every request (register,
/// login, everything) with no visible error beyond "something went wrong".
///
/// For local development against a Flask dev server running on this same
/// machine, override explicitly:
///   flutter run --dart-define=API_BASE_URL=http://localhost:5001/api/v1
/// (or http://10.0.2.2:5001/api/v1 for the Android emulator, which routes
/// "localhost" to the emulator itself rather than the host).
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl => _override.isNotEmpty ? _override : 'https://healthmeeapi.muhammedr.me/api/v1';
}
