import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../models/user.dart';
import '../services/auth_exceptions.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService auth;
  AuthProvider(this.auth) {
    auth.api.configureAuth(refreshCallback: _handleTokenRefresh);
  }

  User? _user;
  String? _token;
  bool _loading = false;
  bool _initializing = false;
  String? _error;

  // ---- Getters for UI ----
  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  bool get initializing => _initializing;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setInitializing(bool v) {
    _initializing = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  Future<void> _applyRefreshedTokens(String newToken, {String? refreshToken}) async {
    _token = newToken;
    await StorageService.saveToken(newToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      auth.updateRefreshToken(refreshToken);
      await StorageService.saveRefreshToken(refreshToken);
    }
    notifyListeners();
  }

  Future<String?> _handleTokenRefresh() async {
    try {
      final data = await auth.performRefresh();
      final newToken =
          (data['token'] ?? data['access_token'])?.toString();
      final newRefresh = data['refresh_token']?.toString();

      if (newToken == null || newToken.isEmpty) {
        await StorageService.clearAuthData();
        auth.updateRefreshToken(null);
        _token = null;
        notifyListeners();
        return null;
      }

      await _applyRefreshedTokens(newToken, refreshToken: newRefresh);
      return newToken;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await StorageService.clearAuthData();
      auth.updateRefreshToken(null);
      _token = null;
      _user = null;
      notifyListeners();
      return null;
    }
  }

  /// Initialize auth state from storage on app startup
  Future<void> initializeAuth() async {
    if (_initializing) return; // Prevent multiple simultaneous initializations
    _setInitializing(true);
    _setError(null);

    try {
      // Load token and user data from storage
      final storedToken = await StorageService.getToken();
      final storedUser = await StorageService.getUserData();
      final storedRefresh = await StorageService.getRefreshToken();
      auth.updateRefreshToken(storedRefresh);

      if (storedToken == null || storedToken.isEmpty) {
        // No stored token, user needs to login
        _setInitializing(false);
        return;
      }

      // We have a stored token, validate it by fetching fresh profile
      try {
        final profileData = await auth.getProfile(storedToken);
        final dynamic candidate = profileData['user'] ?? profileData;
        if (candidate is! Map) {
          throw const FormatException('Unexpected profile JSON.');
        }

        // Token is valid, restore session
        _token = storedToken;
        _user = User.fromJson(Map<String, dynamic>.from(candidate));

        // Update stored user data with fresh data
        await StorageService.saveUserData(_user!);
      } on AuthException catch (e) {
        // Token is invalid (401/403) or expired
        if (e.code == AuthErrorCode.invalidCredentials ||
            e.code == AuthErrorCode.emailNotVerified) {
          // Clear invalid session data
          await StorageService.clearAuthData();
          _token = null;
          _user = null;
          auth.updateRefreshToken(null);
        } else {
          // For other errors (network, etc.), use cached data if available
          if (storedUser != null) {
            _token = storedToken;
            _user = storedUser;
            debugPrint('Using cached user data due to network error');
            if (storedRefresh != null) {
              auth.updateRefreshToken(storedRefresh);
            }
          } else {
            await StorageService.clearAuthData();
            _token = null;
            _user = null;
            auth.updateRefreshToken(null);
          }
        }
      } catch (e) {
        // Network error or other exception - use cached data if available
        if (storedUser != null) {
          _token = storedToken;
          _user = storedUser;
          debugPrint('Using cached user data due to error: $e');
          if (storedRefresh != null) {
            auth.updateRefreshToken(storedRefresh);
          }
        } else {
          await StorageService.clearAuthData();
          _token = null;
          _user = null;
          auth.updateRefreshToken(null);
        }
      }
    } catch (e) {
      debugPrint('Error during auth initialization: $e');
      // Clear potentially corrupted data
      await StorageService.clearAuthData();
      _token = null;
      _user = null;
      auth.updateRefreshToken(null);
    } finally {
      _setInitializing(false);
    }
  }

  /// Save session data to storage
  Future<void> _saveSession(String token, User user, bool rememberMe, {String? refreshToken}) async {
    if (rememberMe) {
      await StorageService.saveToken(token);
      await StorageService.saveUserData(user);
      await StorageService.saveRememberMe(true);
    } else {
      // If not remember me, still save token temporarily (session-based)
      // But clear it on logout
      await StorageService.saveToken(token);
      await StorageService.saveUserData(user);
      await StorageService.saveRememberMe(false);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await StorageService.saveRefreshToken(refreshToken);
    }
  }

  Future<bool> login(String email, String password,
      {bool rememberMe = true}) async {
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
        throw AuthException(
            AuthErrorCode.unknown, 'Token missing in response.');
      }

      final refreshToken = loginData['refresh_token']?.toString() ??
          (loginData['data'] is Map ? loginData['data']['refresh_token']?.toString() : null);
      auth.updateRefreshToken(refreshToken);

      // 2) Profile
      final profileData = await auth.getProfile(_token!);
      // Some APIs return { user: {...} }, others return the user object directly
      final dynamic candidate = profileData['user'] ?? profileData;
      if (candidate is! Map) {
        throw const FormatException('Unexpected profile JSON.');
      }
      _user = User.fromJson(Map<String, dynamic>.from(candidate));

      // Save session data to storage
      await _saveSession(_token!, _user!, rememberMe, refreshToken: refreshToken);
      // Save email for convenience
      if (rememberMe) {
        await StorageService.saveEmail(email);
      }

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
      // Clear local state
      _user = null;
      _token = null;
      _setError(null);

      // Clear stored auth data
      await StorageService.clearAuthData();
      auth.updateRefreshToken(null);

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

  Future<void> updateLocalUser(User updated) async {
    _user = updated;
    await StorageService.saveUserData(updated);
    notifyListeners();
  }
}
