import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/device_service.dart';

class DevicesProvider extends ChangeNotifier {
  List<DeviceModel> items = [];
  bool loading = false;
  String? error;

  Future<void> load(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await DeviceService.fetchDevices(token);
    } catch (e) {
      error = e.toString();
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String token) => load(token);
}
