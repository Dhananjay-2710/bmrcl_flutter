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
      final res = await api.get(endpoint, token: token);
      print("Print ${res.body} ${res.statusCode}");
      if (res.statusCode == 200) {
        final body = res.body.isEmpty ? '{}' : res.body;
        final map = jsonDecode(body);
        if (map is Map<String, dynamic>) {
          return PaginatedNotifications.fromMap(map);
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

  /// GET /notifications/unread
  Future<List<AppNotification>> unread({required String token}) async {
    try {
      final res = await api.get(ApiConstants.notificationsUnread, token: token);
      print("Notification Status : ${res.body}");
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
      final res = await api.post('${ApiConstants.notificationsRead}/$id', token: token);

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
      final res = await api.post(ApiConstants.notificationsReadAll, token: token);

      if (res.statusCode == 200) return;
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }
}
