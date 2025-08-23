import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../constants/api_constants.dart';

class AdminService {
  static Future<Map<String, dynamic>> fetchDashboardData(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/admin_dashboard');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('application/json')) {
        // Safety: backend sometimes returns HTML; catch early
        throw Exception('Expected JSON but got: ${res.body.substring(0, 120)}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) return data;
      throw Exception('API returned success=false');
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
