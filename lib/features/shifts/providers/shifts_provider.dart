import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/my_shifts_models.dart';
import '../services/attendance_service.dart';
import '../services/shift_service.dart';

class ShiftsProvider extends ChangeNotifier {
  // Inject services (created in main via Provider)
  final ShiftService shifts;
  final AttendanceService attendanceSvc;

  ShiftsProvider(this.shifts, this.attendanceSvc);

  bool loading = false;
  String? error;
  MyShiftsBundle? bundle;
  bool checkingIn = false;
  bool checkingOut = false;

  List<ShiftAssignment> assignments = [];
  List<AttendanceRecord> attendance = [];
  List<AssignedDevice> devices = [];

  Future<void> fetchMyShifts(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await shifts.fetchMyShifts(token);
      bundle = res; // keep the bundle too
      assignments = res.assignments;
      attendance = res.attendance;
      devices = res.devices;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---- helpers ----
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  ShiftAssignment? get todaysAssignment {
    final today = _dateOnly(DateTime.now());
    try {
      return assignments.firstWhere(
            (a) => _dateOnly(a.assignedDate) == today,
      );
    } catch (_) {
      return null;
    }
  }

  AttendanceRecord? get todaysAttendance {
    final today = _dateOnly(DateTime.now());
    try {
      return attendance.firstWhere(
            (a) => _dateOnly(a.date) == today,
      );
    } catch (_) {
      return null;
    }
  }

  bool canCheckIn(int assignmentId) {
    final att = todayAttendanceForAssignment(assignmentId);
    return att == null; // no record yet for THIS assignment
  }

  bool canCheckOut(int assignmentId) {
    final att = todayAttendanceForAssignment(assignmentId);
    if (att == null) return false;

    final co = att.checkOutTime;
    return co == null || (co is String ? co.isEmpty : false);
  }


  Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Haversine (meters)
  double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double d) => d * pi / 180.0;

  AttendanceRecord? todayAttendanceForAssignment(int assignmentId) {
    final today = _dateOnly(DateTime.now());
    for (final a in attendance) {
      if (a.userShiftAssignmentId == assignmentId && _dateOnly(a.date) == today) {
        return a;
      }
    }
    return null;
  }

  // ---- actions ----
  Future<bool> performCheckIn({
    required String token,
    required int assignmentId,
    required double stationLat,
    required double stationLon,
    required File image,
    required bool forceIfFar,
    double allowedRadiusMeters = 200,
  }) async {
    checkingIn = true;
    error = null;
    notifyListeners();
    try {
      final pos = await currentPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      final dist = distanceMeters(stationLat, stationLon, lat, lon);
      final force = dist > allowedRadiusMeters ? forceIfFar : false;

      final ok = await attendanceSvc.checkIn(
        token: token,
        assignmentId: assignmentId,
        lat: lat,
        lon: lon,
        force: force,
        imageFile: image,
      );
      if (ok) await fetchMyShifts(token);
      return ok;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      checkingIn = false;
      notifyListeners();
    }
  }

  Future<bool> performCheckOut({
    required String token,
    required int attendanceId,
    required int assignmentId,
    required double stationLat,
    required double stationLon,
    required File image,
    required bool forceIfFar,
    double allowedRadiusMeters = 200,
  }) async {
    checkingOut = true;
    error = null;
    notifyListeners();
    try {
      final pos = await currentPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      final dist = distanceMeters(stationLat, stationLon, lat, lon);
      final force = dist > allowedRadiusMeters ? forceIfFar : false;

      final ok = await attendanceSvc.checkOut(
        token: token,
        attendanceId: attendanceId,
        assignmentId: assignmentId,
        lat: lat,
        lon: lon,
        force: force,
        imageFile: image,
      );
      if (ok) await fetchMyShifts(token);
      return ok;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      checkingOut = false;
      notifyListeners();
    }
  }
}
