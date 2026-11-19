/// Application-wide configuration.
///
/// The application uses the backend unless demo mode is explicitly enabled.
class AppConfig {
  AppConfig._();

  /// Human-readable application name.
  static const String appName = 'E-Ticket Event QR Scanner';

  /// Override at build time, e.g. --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  /// Connection timeout in seconds.
  static const int connectTimeoutSeconds = 30;

  /// Receive timeout in seconds.
  static const int receiveTimeoutSeconds = 30;

  /// Enable mock/demo data explicitly with `--dart-define=MOCK_MODE=true`.
  static const bool mockMode = bool.fromEnvironment(
    'MOCK_MODE',
    defaultValue: false,
  );
}
