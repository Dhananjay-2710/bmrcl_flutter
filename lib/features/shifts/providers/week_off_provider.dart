import 'package:flutter/foundation.dart';
import '../models/week_off.dart';
import '../services/week_off_service.dart';

class WeekOffProvider extends ChangeNotifier {
  final WeekOffService service;

  WeekOffProvider(this.service);

  bool loading = false;
  String? error;
  List<WeekOff> weekOffs = [];

  // To prevent multiple initial fetches
  bool initialized = false;

  /// Fetch week offs
  Future<void> fetchWeekOffs(String token, {bool forceRefresh = false}) async {
    if (initialized && !forceRefresh) return; // Skip if already loaded
    loading = true;
    error = null;
    notifyListeners();
    try {
      print("Inside fetchWeekOffs of Provider");
      final res = await service.fetchWeekOffs(token);
      weekOffs = res;
      initialized = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Create a new week off
  // Future<bool> createWeekOff(String token, WeekOff newWeekOff) async {
  //   loading = true;
  //   notifyListeners();
  //   try {
  //     final created = await service.createWeekOff(token, newWeekOff);
  //     if (created) await fetchWeekOffs(token);
  //     // if (created) fetchWeekOffs;
  //     // weekOffs.add(created);
  //     return true;
  //   } catch (e) {
  //     error = e.toString();
  //     return false;
  //   } finally {
  //     loading = false;
  //     notifyListeners();
  //   }
  // }
  //
  // /// Update an existing week off
  // Future<bool> updateWeekOff(String token, WeekOff updated) async {
  //   loading = true;
  //   error = null;
  //   notifyListeners();
  //   try {
  //     final res = await service.updateWeekOff(token, updated);
  //     final index = weekOffs.indexWhere((w) => w.id == res.id);
  //     if (index != -1) {
  //       weekOffs[index] = res;
  //     }
  //     return true;
  //   } catch (e) {
  //     error = e.toString();
  //     return false;
  //   } finally {
  //     loading = false;
  //     notifyListeners();
  //   }
  // }
  //
  // /// Delete a week off
  // Future<bool> deleteWeekOff(String token, int id) async {
  //   loading = true;
  //   error = null;
  //   notifyListeners();
  //   try {
  //     await service.deleteWeekOff(token, id);
  //     weekOffs.removeWhere((w) => w.id == id);
  //     return true;
  //   } catch (e) {
  //     error = e.toString();
  //     return false;
  //   } finally {
  //     loading = false;
  //     notifyListeners();
  //   }
  // }
  //
  // /// Force reload data (ignores _initialized)
  // Future<void> refresh(String token) async {
  //   await fetchWeekOffs(token, forceRefresh: true);
  // }
  /// Create a new week off
  Future<bool> createWeekOff(String token, WeekOff newWeekOff) async {
    loading = true;
    notifyListeners();
    try {
      final created = await service.createWeekOff(token, newWeekOff);
      // if (created) {
      await fetchWeekOffs(token, forceRefresh: true); // fetch fresh data from DB
      // }
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Update an existing week off
  Future<bool> updateWeekOff(String token, WeekOff updated) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await service.updateWeekOff(token, updated);
      // Always fetch fresh data instead of updating locally
      await fetchWeekOffs(token, forceRefresh: true);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Delete a week off
  Future<bool> deleteWeekOff(String token, int id) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await service.deleteWeekOff(token, id);
      await fetchWeekOffs(token, forceRefresh: true); // fetch fresh data
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Force reload data from the server
  Future<void> refresh(String token) async {
    await fetchWeekOffs(token, forceRefresh: true);
  }
}
