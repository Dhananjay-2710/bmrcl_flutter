import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import 'auth_exceptions.dart';

class AuthService {
  final ApiClient api;
  AuthService(this.api);

  Never _throwForStatus(int code, String body) {
    if (code == 401) {
      throw AuthException(AuthErrorCode.invalidCredentials, 'Unauthorized.');
    }
    if (code == 403) {
      throw AuthException(AuthErrorCode.emailNotVerified, 'Email not verified.');
    }
    if (code >= 500) {
      throw AuthException(AuthErrorCode.server, 'Server error ($code).');
    }
    throw Exception('Request failed ($code): $body');
  }

  /// Returns parsed JSON map on success.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await api.post(
        ApiConstants.loginEndpoint,
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
        throw const FormatException('Unexpected JSON format.');
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final res = await api.get(
        ApiConstants.profileEndpoint,
        token: token,
      );

      if (res.statusCode == 200) {
        final body = res.body.isEmpty ? '{}' : res.body;
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) return data;
        throw const FormatException('Unexpected JSON format.');
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }

  // Future<void> logout(String token) async {
  //   try {
  //     final res = await api.post(
  //       ApiConstants.logoutEndpoint,
  //       token: token,
  //     );
  //     if (res.statusCode == 200 || res.statusCode == 204) return;
  //     _throwForStatus(res.statusCode, res.body);
  //   } on SocketException catch (e) {
  //     throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
  //   } on TimeoutException {
  //     throw AuthException(AuthErrorCode.network, 'Request timed out.');
  //   }
  // }

  Future<void> logout(String token) async {
    try {
      final res = await api.post(ApiConstants.logoutEndpoint, token: token);
      // Treat any response as success; the local state is the source of truth.
      if (res.statusCode >= 200 && res.statusCode < 500) return;
    } on SocketException catch (e) {
      // Consider swallowing to avoid blocking local logout
      debugPrint('Network/DNS error during logout: ${e.message}');
    } on TimeoutException {
      debugPrint('Logout timed out.');
    }
  }


  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final res = await api.post(
        ApiConstants.resetPasswordEndpoint,
        body: jsonEncode({
          'email': email.trim(),
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'message': (data is Map && data['message'] is String)
              ? data['message']
              : 'Password reset successfully',
        };
      }
      // Friendly message for non-200
      return {'success': false, 'message': 'Failed to reset password'};
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, 'Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw AuthException(AuthErrorCode.network, 'Request timed out.');
    }
  }

  Future<bool> verifyEmailCode({
    required String email,
    required String code, // 6-digit
  }) async {
    try {
      final res = await api.post(
        ApiConstants.verifyEmailCodeEndpoint,
        body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
      );

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        if (map is Map<String, dynamic>) {
          return map['status'] == true || map['status'] == 'true';
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

  Future<bool> resendEmailCode({required String email}) async {
    try {
      final res = await api.post(
        ApiConstants.resendEmailCodeEndpoint,
        body: jsonEncode({'email': email.trim()}),
      );

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        if (map is Map<String, dynamic>) {
          return map['status'] == true || map['status'] == 'true';
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
}
