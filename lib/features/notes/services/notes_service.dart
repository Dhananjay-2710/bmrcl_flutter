import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/note.dart';

class NotesService {
  // LIST
  static Future<List<Note>> listNotes(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.noteListEndpoint}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('application/json')) {
        throw Exception('Expected JSON but got: ${res.body}');
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true';
      if (ok) {
        final notes = (map['notes'] as List<dynamic>? ?? []).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
        return notes;
      } else {
        throw Exception(map['message'] ?? 'Failed to load notes');
      }
    } else if (res.statusCode >= 500) {
      throw Exception('Server error (${res.statusCode})');
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  // CREATE
  static Future<bool> createNote(String token, String title, String content) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.noteStoreEndpoint}');
    final res = await http.post(url, headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }, body: jsonEncode({'title': title, 'content': content}));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
      return ok;
    } else if (res.statusCode == 404) {
      throw Exception('Resource not found (404)');
    } else if (res.statusCode >= 500) {
      throw Exception('Server error (${res.statusCode})');
    } else {
      return false;
    }
  }

  // UPDATE
  static Future<bool> updateNote(String token, int id, String title, String content) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.noteUpdateEndpoint}/$id');
    final res = await http.put(url, headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }, body: jsonEncode({'title': title, 'content': content}));

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
      return ok;
    } else if (res.statusCode == 404) {
      throw Exception('Note not found (404)');
    } else if (res.statusCode >= 500) {
      throw Exception('Server error (${res.statusCode})');
    } else {
      return false;
    }
  }

  // DELETE
  static Future<bool> deleteNote(String token, int id) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.noteDeleteEndpoint}/$id');
    final res = await http.delete(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true';
      if (ok) return true;
      throw Exception(map['message'] ?? 'Failed to delete note');
    } else if (res.statusCode >= 500) {
      throw Exception('Server error (${res.statusCode})');
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
