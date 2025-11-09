import 'package:flutter/foundation.dart';
import '../models/leave.dart';
import '../services/leave_service.dart';

class LeaveProvider extends ChangeNotifier {
  final LeaveService service;

  LeaveProvider(this.service);

  List<Leave> allLeaves = [];
  List<Leave> myLeaves = [];

  bool loadingAll = false;
  bool loadingMy = false;
  String? error;
  bool creating = false;

  Future<void> loadAll(String token) async {
    loadingAll = true;
    notifyListeners();
    try {
      allLeaves = await service.fetchAllLeaves(token);
      error = null;
    } catch (e) {
      error = e.toString();
      allLeaves = [];
    } finally {
      loadingAll = false;
      notifyListeners();
    }
  }

  Future<void> loadMy(String token) async {
    loadingMy = true;
    notifyListeners();
    try {
      myLeaves = await service.fetchMyLeaves(token);
      error = null;
    } catch (e) {
      error = e.toString();
      myLeaves = [];
    } finally {
      loadingMy = false;
      notifyListeners();
    }
  }

  // Convenience method to refresh both
  Future<void> refreshBoth(String token) async {
    await Future.wait([loadAll(token), loadMy(token)]);
  }

  Future<bool> createLeave(
    String token, {
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    creating = true;
    notifyListeners();
    try {
      final success = await service.createLeave(
        token,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );

      print("Create leave success: " + success.toString());
      
      if (success) {
        // Refresh both lists after creation
        await Future.wait([
          loadAll(token),
          loadMy(token),
        ]);
      }
      creating = false;
      notifyListeners();
      return success;
    } catch (e) {
      creating = false;
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reviewLeave(String token, int leaveId, String reviewRemarks) async {
    try {
      final success = await service.reviewLeave(token, leaveId, reviewRemarks);
      if (success) {
        // Refresh both lists after review
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

  Future<bool> approveLeave(String token, int leaveId, String approvedRemarks) async {
    try {
      final success = await service.approveLeave(token, leaveId, approvedRemarks);
      if (success) {
        // Refresh both lists after approval
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

  Future<bool> updateLeave(
    String token,
    int leaveId, {
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      final success = await service.updateLeave(
        token,
        leaveId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      if (success) {
        // Refresh both lists after update
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

  Future<bool> deleteLeave(String token, int leaveId) async {
    try {
      final success = await service.deleteLeave(token, leaveId);
      if (success) {
        // Refresh both lists after deletion
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
}

