import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/task_type.dart';

class TaskTypeService {

  static Future<List<TaskType>> fetchAllTaskType(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.allTaskType}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    print("Task Type Response :  ${res.statusCode}");
    print("Task Type Data : ${res.body}");
    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['data'] ?? map['data'] ?? []) as List<dynamic>;
      return list.map((e) => TaskType.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load all tasks: ${res.body}');
    }
  }
}
