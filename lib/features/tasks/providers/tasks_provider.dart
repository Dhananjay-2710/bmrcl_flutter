import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TasksProvider extends ChangeNotifier {
  List<Task> allTasks = [];
  List<Task> myTasks = [];

  bool loadingAll = false;
  bool loadingMy = false;
  String? error;
  bool creating = false;
  Task? task;
  bool loading = false;
  bool loadingStart = false;

  Future<void> loadAll(String token) async {
    loadingAll = true;
    notifyListeners();
    try {
      allTasks = await TaskService.fetchAllTasks(token);
      error = null;
    } catch (e) {
      error = e.toString();
      allTasks = [];
    } finally {
      loadingAll = false;
      notifyListeners();
    }
  }

  Future<void> loadMy(String token) async {
    loadingMy = true;
    notifyListeners();
    try {
      myTasks = await TaskService.fetchMyTasks(token);
      error = null;
    } catch (e) {
      error = e.toString();
      myTasks = [];
    } finally {
      loadingMy = false;
      notifyListeners();
    }
  }

  // convenience refresh both
  Future<void> refreshBoth(String token) async {
    await Future.wait([loadAll(token), loadMy(token)]);
  }

  Future<bool> createTask(String token, Map<String, dynamic> body) async {
    creating = true;
    notifyListeners();
    try {
      final ok = await TaskService.createTask(token, body);
      if (ok) {
        await Future.wait([
          loadAll(token),
          loadMy(token),
        ]);
        creating = false;
        notifyListeners();
        return true;
      } else {
        creating = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      creating = false;
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  Future<void> loadTask(String token, int id) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      task = await TaskService.fetchTask(token, id);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTask(String token, int id) async {
    try {
      final success = await TaskService.deleteTask(token, id);
      if (success) {
        await Future.wait([
          loadAll(token),
          loadMy(token),
        ]);
      }
      notifyListeners();
      return success;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }


  Future<bool> updateTask(String token, int id, Map<String, dynamic> body) async {
    try {
      final success = await TaskService.updateTask(token, id, body);
      if (success) {
        await loadTask(token, id); // reload updated task
      }
      return success;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> startTask(String token, int taskId) async {
    try {
      final success = await TaskService.startTask(token, taskId);
      if (success) {
        notifyListeners();
        return success;
      }
      return false;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTask(String token, int taskId, {File? taskImage}) async {
    try {
      final success = await TaskService.completeTask(token, taskId, taskImage: taskImage);
      notifyListeners();
      return success;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}