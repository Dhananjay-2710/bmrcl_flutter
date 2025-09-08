import 'package:flutter/foundation.dart';
import '../models/assign_shift_models.dart';
import '../services/shift_assign_service.dart';

class ShiftAssignProvider extends ChangeNotifier {
  final ShiftAssignService svc;
  ShiftAssignProvider(this.svc);

  bool loading = false;
  String? error;
  List<AssignShift> items = [];

  Future<void> fetchAll(String token) async {
    loading = true; error = null; notifyListeners();
    try {
      items = await svc.listAll(token);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<bool> create(String token, AssignShiftInput input) async {
    try {
      final ok = await svc.create(token, input);
      if (ok) await fetchAll(token);
      return ok;
    } catch (e) {
      error = e.toString(); notifyListeners(); return false;
    }
  }

  Future<bool> bulkCreate(String token, AssignBulkShiftInput input) async {
    try {
      final ok = await svc.bulkCreate(token, input);
      if (ok) await fetchAll(token);
      return ok;
    } catch (e) {
      error = e.toString(); notifyListeners(); return false;
    }
  }

  Future<bool> update(String token, int id, AssignShiftInput input) async {
    try {
      final ok = await svc.update(token, id, input);
      if (ok) await fetchAll(token);
      return ok;
    } catch (e) {
      error = e.toString(); notifyListeners(); return false;
    }
  }

  Future<bool> remove(String token, int id) async {
    try {
      final ok = await svc.delete(token, id);
      if (ok) items.removeWhere((x) => x.id == id);
      notifyListeners();
      return ok;
    } catch (e) {
      error = e.toString(); notifyListeners(); return false;
    }
  }
}
