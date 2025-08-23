import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/lookup_models.dart';

class LookupService {
  final ApiClient api;
  LookupService(this.api);

  Never _throwForStatus(int code, String body) {
    if (code == 401) throw Exception('Unauthorized');
    if (code == 404) throw Exception('Not found (404)');
    if (code >= 500) throw Exception('Server error ($code)');
    throw Exception('HTTP $code: $body');
  }

  Future<List<ShiftLite>> fetchShifts(String token) async {
    try {
      final res = await api.get(ApiConstants.shiftsList, token: token);
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch shifts');
        final list = (map['shifts'] as List).cast<dynamic>();
        return list.map((e) => ShiftLite.fromJson(e as Map<String, dynamic>)).toList();
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<List<StationLite>> fetchStations(String token) async {
    try {
      final res = await api.get(ApiConstants.stationsList, token: token);
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch stations');
        final list = (map['stations'] as List).cast<dynamic>();
        return list.map((e) => StationLite.fromJson(e as Map<String, dynamic>)).toList();
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<List<GateLite>> fetchGates(String token, int stationId) async {
    try {
      final res = await api.get(ApiConstants.stationsGates(stationId), token: token);
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch gates');
        final list = (map['gates'] as List).cast<dynamic>();
        return list.map((e) => GateLite.fromJson(e as Map<String, dynamic>, stationId: stationId)).toList();
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }
}
