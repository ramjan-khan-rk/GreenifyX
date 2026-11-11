/// API location. Override at build time:
///   flutter run -d chrome --dart-define=API_BASE=http://localhost:5000/api
class AdminConfig {
  AdminConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://greenifyx.onrender.com/api',
  );
}
