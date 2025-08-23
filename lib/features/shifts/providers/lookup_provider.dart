import 'package:flutter/foundation.dart';
import '../models/lookup_models.dart';
import '../services/lookup_service.dart';

class LookupProvider extends ChangeNotifier {
  final LookupService svc;
  LookupProvider(this.svc);

  bool loadingShifts = false;
  bool loadingStations = false;
  final Map<int, bool> _loadingGates = {}; // per-station loading

  String? error;

  List<ShiftLite> shifts = [];
  List<StationLite> stations = [];
  final Map<int, List<GateLite>> gatesByStation = {}; // stationId -> gates

  Future<void> ensureBasics(String token) async {
    error = null;
    if (shifts.isEmpty) await fetchShifts(token);
    if (stations.isEmpty) await fetchStations(token);
  }

  Future<void> fetchShifts(String token) async {
    loadingShifts = true; error = null; notifyListeners();
    try {
      shifts = await svc.fetchShifts(token);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingShifts = false; notifyListeners();
    }
  }

  Future<void> fetchStations(String token) async {
    loadingStations = true; error = null; notifyListeners();
    try {
      stations = await svc.fetchStations(token);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingStations = false; notifyListeners();
    }
  }

  Future<void> fetchGatesForStation(String token, int stationId) async {
    if (_loadingGates[stationId] == true) return;
    _loadingGates[stationId] = true; error = null; notifyListeners();
    try {
      gatesByStation[stationId] = await svc.fetchGates(token, stationId);
    } catch (e) {
      error = e.toString();
    } finally {
      _loadingGates[stationId] = false; notifyListeners();
    }
  }

  bool isLoadingGates(int stationId) => _loadingGates[stationId] == true;
}
