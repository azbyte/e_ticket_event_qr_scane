/// ApiClient for the E-Ticket Event QR Scanner application.
/// Handles communication with the backend API using the http package.
/// Currently uses https://api.example.com as placeholder base URL.
class ApiClient {
  final http.Client _client;
  final String _baseUrl;

  ApiClient({http.Client? client})
      : _client = client ?? http.Client(),
        _baseUrl = 'https://api.example.com';

  Future<http.Response> get(Uri uri) async {
    final fullUri = Uri.parse(_baseUrl).replace(path: _baseUrl.endsWith('/') ? '' : '/') + uri;
    return _client.get(fullUri);
  }

  Future<http.Response> post(Uri uri, {Map<String, dynamic>? body}) async {
    final fullUri = Uri.parse(_baseUrl).replace(path: _baseUrl.endsWith('/') ? '' : '/') + uri;
    return _client.post(fullUri, body: body);
  }

  Future<http.Response> put(Uri uri, {Map<String, dynamic>? body}) async {
    final fullUri = Uri.parse(_baseUrl).replace(path: _baseUrl.endsWith('/') ? '' : '/') + uri;
    return _client.put(fullUri, body: body);
  }

  Future<http.Response> delete(Uri uri) async {
    final fullUri = Uri.parse(_baseUrl).replace(path: _baseUrl.endsWith('/') ? '' : '/') + uri;
    return _client.delete(fullUri);
  }
}