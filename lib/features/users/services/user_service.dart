import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/user.dart';

class UserService {
  final ApiClient api;
  UserService(this.api);

  Exception _buildHttpError(int statusCode, String body, String context) {
    debugPrint('[$context] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<List<UserModel>> fetchUsers(String token) async {
    final res = await api.get(
      ApiConstants.userListEndpoint,
      token: token,
      retryOn401: true,
      retryOn5xx: true,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['user'] ?? map['users'] ?? []) as List<dynamic>;
      return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _buildHttpError(res.statusCode, res.body, 'UserService.fetchUsers');
  }

  Future<bool> resetPassword(
    String email,
    String newPassword,
    String confirmPassword,
  ) async {
    final res = await api.post(
      ApiConstants.resetPasswordEndpoint,
      body: jsonEncode({
        "email": email,
        "new_password": newPassword,
        "new_password_confirmation": confirmPassword,
      }),
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      return map['status'] == true || map['status'] == 'true';
    }
    throw _buildHttpError(res.statusCode, res.body, 'UserService.resetPassword');
  }
}
