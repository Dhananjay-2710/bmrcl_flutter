enum AuthErrorCode {
  invalidCredentials,  // 401
  emailNotVerified,    // 403
  network,
  server,
  unknown,
}

class AuthException implements Exception {
  final AuthErrorCode code;
  final String message;
  AuthException(this.code, this.message);

  @override
  String toString() => "AuthException($code): $message";
}
