import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/device_service.dart';

class DevicesProvider extends ChangeNotifier {
  final DeviceService service;
  DevicesProvider(this.service);

  List<DeviceModel> devices = [];
  bool loading = false;
  String? error;

  Future<void> load(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      devices = await service.fetchDevices(token);
    } catch (e) {
      error = e.toString();
      devices = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String token) => load(token);
}
