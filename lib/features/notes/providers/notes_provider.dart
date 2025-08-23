import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/notes_service.dart';

class NotesProvider extends ChangeNotifier {
  List<Note> items = [];
  bool loading = false;
  bool creating = false;
  String? error;

  Future<void> fetchNotes(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await NotesService.listNotes(token);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create(String token, String title, String content) async {
    creating = true;
    notifyListeners();
    try {
      final ok = await NotesService.createNote(token, title, content);
      creating = false;

      if (ok) {
        await fetchNotes(token); // refresh notes list
      }

      notifyListeners();
      return ok;
    } catch (e) {
      creating = false;
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(String token, int id, String title, String content) async {
    try {
      final ok = await NotesService.updateNote(token, id, title, content);
      creating = false;

      if (ok) {
        await fetchNotes(token); // refresh list after update
      }

      notifyListeners();
      return ok;
    } catch (e) {
      creating = false;
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String token, int id) async {
    try {
      final ok = await NotesService.deleteNote(token, id);
      if (ok) {
        items.removeWhere((n) => n.id == id);
        await fetchNotes(token);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
