import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/task_type.dart';

class TaskTypeService {
  static Exception _buildHttpError(http.Response res) {
    debugPrint('[TaskTypeService] HTTP ${res.statusCode}: ${res.body}');
    if (res.statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (res.statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  static Future<List<TaskType>> fetchAllTaskType(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.allTaskType}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['data'] ?? map['data'] ?? []) as List<dynamic>;
      return list.map((e) => TaskType.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _buildHttpError(res);
  }
}
