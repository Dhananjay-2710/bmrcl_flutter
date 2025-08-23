import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/assign_shift_models.dart';

class ShiftAssignService {
  final ApiClient api;
  ShiftAssignService(this.api);

  Never _throwForStatus(int code, String body) {
    if (code == 401) throw Exception('Unauthorized. Please login again.');
    if (code == 404) throw Exception('Endpoint not found (404).');
    if (code >= 500) throw Exception('Server error ($code).');
    throw Exception('HTTP $code: $body');
  }

  Future<List<AssignShift>> listAll(String token) async {
    try {
      final res = await api.get(ApiConstants.shiftAssignList, token: token);
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch assigned shifts');
        final list = (map['all_assign_shifts'] as List).cast<dynamic>();
        return list.map((e) => AssignShift.fromJson(e as Map<String, dynamic>)).toList();
      }
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }

  Future<bool> create(String token, AssignShiftInput input) async {
    try {
      final res = await api.post(
        ApiConstants.shiftAssignStore,
        token: token,
        body: jsonEncode(input.toJson()),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }

  Future<bool> update(String token, int id, AssignShiftInput input) async {
    try {
      final res = await api.put(
        ApiConstants.shiftAssignUpdate(id),
        token: token,
        body: jsonEncode(input.toJson()),
      );
      if (res.statusCode == 200) return true;
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }

  Future<bool> delete(String token, int id) async {
    try {
      final res = await api.delete(
        ApiConstants.shiftAssignDelete(id),
        token: token,
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;
      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }
}
