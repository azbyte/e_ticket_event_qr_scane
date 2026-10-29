/// Application-wide configuration.
///
/// NOTE: Backend base URL and API endpoints are not finalized yet (PRD section 15
/// states the API contract is still a draft). Values below are placeholders and
/// must be replaced with the agreed backend host before integration.
class AppConfig {
  AppConfig._();

  /// Human-readable application name.
  static const String appName = 'E-Ticket Event QR Scanner';

  /// Base URL of the backend API. TODO: replace with actual backend host.
  static const String apiBaseUrl = 'https://api.example.com';

  /// Connection timeout in seconds.
  static const int connectTimeoutSeconds = 30;

  /// Receive timeout in seconds.
  static const int receiveTimeoutSeconds = 30;

  /// Whether the app is running in mock/demo mode (no real backend).
  static const bool mockMode = true;
}
