import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_exceptions.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService auth;
  AuthProvider(this.auth);

  User? _user;
  String? _token;
  bool _loading = false;
  String? _error;

  // ---- Getters for UI ----
  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool v) { _loading = v; notifyListeners(); }
  void _setError(String? e) { _error = e; notifyListeners(); }

  Future<bool> login(String email, String password) async {
    _setError(null);
    _setLoading(true);
    try {
      // 1) Login
      final loginData = await auth.login(email, password);

      // token can be at root or under data.token
      final t1 = loginData['token'];
      final t2 = (loginData['data'] is Map) ? loginData['data']['token'] : null;
      _token = (t1 ?? t2) as String?;
      if (_token == null || _token!.isEmpty) {
        throw AuthException(AuthErrorCode.unknown, 'Token missing in response.');
      }

      // 2) Profile
      final profileData = await auth.getProfile(_token!);
      // Some APIs return { user: {...} }, others return the user object directly
      final dynamic candidate = profileData['user'] ?? profileData;
      if (candidate is! Map) {
        throw const FormatException('Unexpected profile JSON.');
      }
      _user = User.fromJson(Map<String, dynamic>.from(candidate));

      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setLoading(false);
      _setError(e.message);
      // Re-throw so UI can branch on error code (401/403)
      throw e;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      rethrow;
    }
  }

  // Future<void> logout() async {
  //   try {
  //     if (_token != null) {
  //       await auth.logout(_token!);
  //     }
  //   } finally {
  //     _user = null;
  //     _token = null;
  //     _setError(null);
  //     notifyListeners();
  //   }
  // }

  // Future<void> logout(BuildContext context) async {
  //   try {
  //     // Dismiss snackbars, dialogs, sheets before clearing providers
  //     ScaffoldMessenger.of(context).clearSnackBars();
  //     Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  //
  //     if (_token != null) {
  //       try {
  //         await auth.logout(_token!);
  //       } catch (e) {
  //         // You may log or ignore logout errors from server
  //         debugPrint("Server logout failed: $e");
  //       }
  //     }
  //
  //   } finally {
  //     // Clear local session
  //     _user = null;
  //     _token = null;
  //     _setError(null);
  //
  //     // Tell listeners (UI will redirect via AuthGate)
  //     notifyListeners();
  //   }
  // }

  // In AuthProvider
  // AuthProvider
  Future<void> logout() async {
    try {
      final t = _token;
      if (t != null) {
        try {
          await auth.logout(t);
        } catch (e) {
          debugPrint("Server logout failed (ignored): $e");
        }
      }
    } finally {
      _user = null;
      _token = null;
      _setError(null);
      notifyListeners(); // AuthGate reacts
    }
  }


  Future<bool> resetPassword({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final result = await auth.resetPassword(
        email: email,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return result['success'] == true;
    } on AuthException catch (e) {
      _setError(e.message);
      rethrow;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      return await auth.verifyEmailCode(email: email, code: code);
    } on AuthException catch (e) {
      _setError(e.message);
      rethrow;
    }
  }

  Future<bool> resendEmailCode({required String email}) async {
    try {
      return await auth.resendEmailCode(email: email);
    } on AuthException catch (e) {
      _setError(e.message);
      rethrow;
    }
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }
}
