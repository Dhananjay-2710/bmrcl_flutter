import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/note.dart';

class NotesService {
  final ApiClient api;
  NotesService(this.api);

  Exception _buildHttpError(int statusCode, String body) {
    debugPrint('[NotesService] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  // LIST
  Future<List<Note>> listNotes(String token) async {
    final res = await api.get(
      ApiConstants.noteListEndpoint,
      token: token,
      retryOn401: true,
      retryOn5xx: true,
    );

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
    }
    throw _buildHttpError(res.statusCode, res.body);
  }

  // CREATE
  Future<bool> createNote(String token, String title, String content) async {
    final res = await api.post(
      ApiConstants.noteStoreEndpoint,
      token: token,
      retryOn401: true,
      body: jsonEncode({'title': title, 'content': content}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
      return ok;
    }
    if (res.statusCode == 404) {
      throw Exception('Resource not found (404)');
    }
    throw _buildHttpError(res.statusCode, res.body);
  }

  // UPDATE
  Future<bool> updateNote(String token, int id, String title, String content) async {
    final res = await api.put(
      '${ApiConstants.noteUpdateEndpoint}/$id',
      token: token,
      retryOn401: true,
      body: jsonEncode({'title': title, 'content': content}),
    );

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
      return ok;
    }
    if (res.statusCode == 404) {
      throw Exception('Note not found (404)');
    }
    throw _buildHttpError(res.statusCode, res.body);
  }

  // DELETE
  Future<bool> deleteNote(String token, int id) async {
    final res = await api.delete(
      '${ApiConstants.noteDeleteEndpoint}/$id',
      token: token,
      retryOn401: true,
    );

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = map['status'] == true || map['status'] == 'true';
      if (ok) return true;
      throw Exception(map['message'] ?? 'Failed to delete note');
    }
    throw _buildHttpError(res.statusCode, res.body);
  }
}
