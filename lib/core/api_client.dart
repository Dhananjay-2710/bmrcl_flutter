import 'dart:async';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _http;
  static const Duration _timeout = Duration(seconds: 20);

  Future<String?> Function()? _refreshCallback;

  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  void configureAuth({Future<String?> Function()? refreshCallback}) {
    _refreshCallback = refreshCallback;
  }

  Future<String?> refreshAccessToken() async {
    if (_refreshCallback == null) return null;
    return _refreshCallback!();
  }

  Uri uri(String endpoint, [Map<String, String>? query]) {
    final baseUri = Uri.parse(baseUrl.trim());
    final cleanBasePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
    final cleanEndpoint = endpoint.trim().replaceFirst(RegExp(r'^/+'), '');
    return baseUri.replace(path: '$cleanBasePath/$cleanEndpoint', queryParameters: query);
  }

  Map<String, String> _headers({String? token}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static const int _max5xxRetries = 1;
  static const Duration _retryBaseDelay = Duration(milliseconds: 600);

  Future<http.Response> _performRequest({
    required Future<http.Response> Function(String? token) send,
    String? token,
    bool retryOn401 = false,
    bool retryOn5xx = false,
  }) async {
    String? currentToken = token;
    bool hasRefreshed = false;
    int attemptFor5xx = 0;

    http.Response response = await send(currentToken);

    while (true) {
      // Handle 401 with optional refresh
      if (response.statusCode == 401 &&
          retryOn401 &&
          currentToken != null &&
          !hasRefreshed &&
          _refreshCallback != null) {
        final newToken = await _refreshCallback!.call();
        if (newToken != null && newToken.isNotEmpty && newToken != currentToken) {
          currentToken = newToken;
          hasRefreshed = true;
          response = await send(currentToken);
          continue;
        }
      }

      // Handle 5xx retries
      if (retryOn5xx &&
          response.statusCode >= 500 &&
          response.statusCode < 600 &&
          attemptFor5xx < _max5xxRetries) {
        attemptFor5xx += 1;
        final delay = _retryBaseDelay * attemptFor5xx;
        await Future.delayed(delay);
        response = await send(currentToken);
        continue;
      }

      break;
    }

    return response;
  }

  Future<http.Response> get(
    String endpoint, {
    String? token,
    Map<String, String>? query,
    bool retryOn401 = false,
    bool retryOn5xx = false,
  }) {
    Future<http.Response> send(String? tk) => _http
        .get(uri(endpoint, query), headers: _headers(token: tk))
        .timeout(_timeout);

    return _performRequest(
      send: send,
      token: token,
      retryOn401: retryOn401,
      retryOn5xx: retryOn5xx,
    );
  }

  Future<http.Response> post(
    String endpoint, {
    String? token,
    Map<String, String>? query,
    Object? body,
    bool retryOn401 = false,
    bool retryOn5xx = false,
  }) {
    Future<http.Response> send(String? tk) => _http
        .post(uri(endpoint, query), headers: _headers(token: tk), body: body)
        .timeout(_timeout);

    return _performRequest(
      send: send,
      token: token,
      retryOn401: retryOn401,
      retryOn5xx: retryOn5xx,
    );
  }

  Future<http.Response> put(
    String endpoint, {
    String? token,
    Map<String, String>? query,
    Object? body,
    bool retryOn401 = false,
    bool retryOn5xx = false,
  }) {
    Future<http.Response> send(String? tk) => _http
        .put(uri(endpoint, query), headers: _headers(token: tk), body: body)
        .timeout(_timeout);

    return _performRequest(
      send: send,
      token: token,
      retryOn401: retryOn401,
      retryOn5xx: retryOn5xx,
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    String? token,
    Map<String, String>? query,
    bool retryOn401 = false,
    bool retryOn5xx = false,
  }) {
    Future<http.Response> send(String? tk) => _http
        .delete(uri(endpoint, query), headers: _headers(token: tk))
        .timeout(_timeout);

    return _performRequest(
      send: send,
      token: token,
      retryOn401: retryOn401,
      retryOn5xx: retryOn5xx,
    );
  }
}
