import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';

class AdminService {
  final ApiClient api;
  AdminService(this.api);

  Exception _buildHttpError(int statusCode, String body) {
    debugPrint('[AdminService] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<Map<String, dynamic>> fetchDashboardData(String token) async {
    final res = await api.get(
      ApiConstants.adminDashboard,
      token: token,
      retryOn401: true,
      retryOn5xx: true,
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
    }
    throw _buildHttpError(res.statusCode, res.body);
  }
}
