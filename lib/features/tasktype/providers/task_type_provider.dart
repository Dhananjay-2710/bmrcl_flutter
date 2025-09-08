import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/task_type.dart';
import '../services/task_type_service.dart';

class TaskTypeProvider extends ChangeNotifier {
  List<TaskType> allTaskType = [];

  bool loadingAll = false;
  bool loadingMy = false;
  String? error;
  bool creating = false;
  TaskType? task;
  bool loading = false;
  bool loadingStart = false;

  Future<void> loadTaskType(String token) async {
    loadingAll = true;
    notifyListeners();
    try {
      allTaskType = await TaskTypeService.fetchAllTaskType(token);
      error = null;
    } catch (e) {
      error = e.toString();
      allTaskType = [];
    } finally {
      loadingAll = false;
      notifyListeners();
    }
  }
}