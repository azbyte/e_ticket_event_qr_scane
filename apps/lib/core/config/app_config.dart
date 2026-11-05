/// Application-wide configuration.
///
/// NOTE: Backend base URL and API endpoints are not finalized yet (PRD section 15
/// states the API contract is still a draft). Values below are placeholders and
/// must be replaced with the agreed backend host before integration.
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

  /// Whether the app is running in mock/demo mode (no real backend).
  static const bool mockMode = bool.fromEnvironment(
    'MOCK_MODE',
    defaultValue: true,
  );
}
