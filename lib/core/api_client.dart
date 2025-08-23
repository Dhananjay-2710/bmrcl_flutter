import 'dart:async';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _http;
  static const Duration _timeout = Duration(seconds: 20);

  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

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

  Future<http.Response> get(String endpoint, {String? token, Map<String, String>? query}) {
    return _http.get(uri(endpoint, query), headers: _headers(token: token)).timeout(_timeout);
  }

  Future<http.Response> post(String endpoint, {String? token, Map<String, String>? query, Object? body}) =>
      _http.post(uri(endpoint, query), headers: _headers(token: token), body: body).timeout(_timeout);

  Future<http.Response> put(String endpoint, {String? token, Map<String, String>? query, Object? body}) =>
      _http.put(uri(endpoint, query), headers: _headers(token: token), body: body).timeout(_timeout);

  Future<http.Response> delete(String endpoint, {String? token, Map<String, String>? query}) =>
      _http.delete(uri(endpoint, query), headers: _headers(token: token)).timeout(_timeout);
}