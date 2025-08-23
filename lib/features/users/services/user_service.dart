import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/user.dart';

class UserService {
  static Future<List<UserModel>> fetchUsers(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.userListEndpoint}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['user'] ?? map['users'] ?? []) as List<dynamic>;
      return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load users: ${res.body}');
    }
  }

  static Future<bool> resetPassword(
      String email, String newPassword, String confirmPassword) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.resetPasswordEndpoint}');

    final res = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email,
          "new_password": newPassword,
          "new_password_confirmation": confirmPassword
        }));

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      return map['status'] == true || map['status'] == 'true';
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
