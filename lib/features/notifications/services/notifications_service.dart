import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../../auth/services/auth_exceptions.dart';

import '../models/app_notification.dart';

class NotificationsService {
  final ApiClient api;
  NotificationsService(this.api);

  Never _throwForStatus(int code, String body) {
    if (code == 401) {
      throw AuthException(AuthErrorCode.invalidCredentials, 'Unauthorized.');
    }
    if (code == 403) {
      throw AuthException(AuthErrorCode.emailNotVerified, 'Forbidden.');
    }
    if (code >= 500) {
      throw AuthException(AuthErrorCode.server, 'Server error ($code).');
    }
    throw Exception('Request failed ($code): $body');
  }

  /// GET /notifications/list?page=X
  Future<PaginatedNotifications> list({
    required String token,
    int page = 1,
  }) async {
    try {
      final endpoint = ApiConstants.notificationsList;
      final query = {'page': page.toString()};
      final res = await api.get(
        endpoint,
        token: token,
        query: query,
        retryOn401: true,
        retryOn5xx: true,
      );
      
      if (res.statusCode == 200) {
        final body = res.body.isEmpty ? '{}' : res.body;
        final map = jsonDecode(body);
        
        if (map is Map<String, dynamic>) {
          return PaginatedNotifications.fromMap(map);
        }
        throw const FormatException('Unexpected JSON format - expected Map.');
      }
      _throwForStatus(res.statusCode, res.body);
    } on FormatException catch (e) {
      throw Exception('Failed to parse response: $e');
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }

  /// GET /notifications/unread
  Future<List<AppNotification>> unread({required String token}) async {
    try {
      final res = await api.get(
        ApiConstants.notificationsUnread,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      if (res.statusCode == 200) {
        final body = res.body.isEmpty ? '{}' : res.body;
        final map = jsonDecode(body);
        if (map is Map<String, dynamic>) {
          final List list = (map['notifications'] ?? []) as List;
          return list
              .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
        throw const FormatException('Unexpected JSON format.');
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }

  /// POST /notifications/read/{id}
  Future<void> markRead({required String token, required String id}) async {
    try {
      final res = await api.post(
        '${ApiConstants.notificationsRead}/$id',
        token: token,
        retryOn401: true,
      );

      if (res.statusCode == 200) return;
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }

  /// POST /notifications/read-all
  Future<void> markAllRead({required String token}) async {
    try {
      final res = await api.post(
        ApiConstants.notificationsReadAll,
        token: token,
        retryOn401: true,
      );

      if (res.statusCode == 200) return;
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }
}
