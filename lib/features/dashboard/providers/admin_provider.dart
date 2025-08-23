import 'package:flutter/foundation.dart';
import '../services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  bool loading = false;
  String? error;

  // Parsed fields
  Map<String, dynamic>? summary; // counts
  List<String> codes = [];
  Map<String, dynamic>? stationTransactions; // date -> stationCode -> metrics
  Map<String, dynamic>? stationTotals;       // stationCode -> totals
  Map<String, dynamic>? dailyTransactions;   // date -> {passengers, tickets, amount}
  List<dynamic> deviceTransactions = [];
  List<dynamic> users = [];

  Future<void> loadDashboard(String token) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await AdminService.fetchDashboardData(token);

      summary = (data['summary'] as Map?)?.cast<String, dynamic>();
      codes = (data['codes'] as List?)?.map((e) => e.toString()).toList() ?? [];

      stationTransactions = (data['station_transactions'] as Map?)?.cast<String, dynamic>();
      stationTotals       = (data['station_totals'] as Map?)?.cast<String, dynamic>();
      dailyTransactions   = (data['daily_transactions'] as Map?)?.cast<String, dynamic>();

      deviceTransactions  = (data['device_transactions'] as List?) ?? [];
      users               = (data['users'] as List?) ?? [];

      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = e.toString();
      notifyListeners();
    }
  }
}
