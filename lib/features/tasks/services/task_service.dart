import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/task.dart';

class TaskService {
  /// GET /tasks/list  -> returns "taskData" (all tasks)
  static Future<List<Task>> fetchAllTasks(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.allTasks}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['taskData'] ?? map['taskdata'] ?? []) as List<dynamic>;
      return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load all tasks: ${res.body}');
    }
  }

  /// GET /tasks/tasklist -> returns "taskdata" (user tasks)
  static Future<List<Task>> fetchMyTasks(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myTasks}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['taskdata'] ?? map['taskData'] ?? []) as List<dynamic>;
      return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load my tasks: ${res.body}');
    }
  }

  /// Create task: POST /tasks/store
  static Future<bool> createTask(String token, Map<String, dynamic> body) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.storeTask}');
    final res = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 201) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      if (map['status'] == 'true' || map['status'] == true) {
        return true;
      } else if (res.statusCode == 500) {
        throw Exception('Server error (500): Please try again later');
      } else {
        throw Exception(map['message'] ?? 'Failed to create task');
      }
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  // GET Task details
  static Future<Task> fetchTask(String token, int id) async {
    final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/tasks/show/$id'), headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      if (map['status'] == 'true') {
        return Task.fromJson(map['taskdata']);
      } else {
        throw Exception(map['message'] ?? 'Failed to fetch task');
      }
    } else if (res.statusCode == 404) {
      throw Exception('Server error (404)');
    } else if (res.statusCode == 500) {
      throw Exception('Server error (500)');
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  // DELETE Task
  static Future<bool> deleteTask(String token, int id) async {
    final res = await http.delete(Uri.parse('${ApiConstants.baseUrl}/tasks/delete/$id'), headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      return map['status'] == true || map['status'] == 'true';
    } else {
      throw Exception('Failed to delete task: HTTP ${res.statusCode}');
    }
  }

  // UPDATE Task
  static Future<bool> updateTask(String token, int id, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('${ApiConstants.baseUrl}/tasks/update/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body));

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      return map['status'] == true || map['status'] == 'true';
    } else {
      throw Exception('Failed to update task: HTTP ${res.statusCode}');
    }
  }

  // Start Task
  static Future<bool> startTask(String token, int taskId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/tasks/start_task/$taskId');
    final res = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      if (map['status'] == true || map['status'] == 'true') {
        return true;
      } else {
        throw Exception(map['message'] ?? 'Failed to start task');
      }
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  // Complete Task
  static Future<bool> completeTask(String token, int taskId, {File? taskImage}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/tasks/complete_task/$taskId');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    if (taskImage != null) {
      request.files.add(await http.MultipartFile.fromPath('task_image', taskImage.path));
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body);
      if (map['status'] == true || map['status'] == 'true') {
        return true;
      } else {
        throw Exception(map['message'] ?? 'Failed to complete task');
      }
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
