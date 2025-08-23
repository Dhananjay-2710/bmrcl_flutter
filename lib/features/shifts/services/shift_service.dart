import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/my_shifts_models.dart';

class ShiftService {
  final ApiClient api;
  ShiftService(this.api);

  Never _throwForStatus(int code, String body) {
    if (code == 401) throw Exception('Unauthorized. Please login again.');
    if (code == 404) throw Exception('Endpoint not found (404).');
    if (code >= 500) throw Exception('Server error ($code).');
    throw Exception('HTTP $code: $body');
  }

  Future<MyShiftsBundle> fetchMyShifts(String token) async {
    try {
      final res = await api.get(
        ApiConstants.myShiftEndpoint,
        token: token,
      );

      // debug:
      // print('My Shifts -> ${res.statusCode}\n${res.body}');

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        if (map is! Map<String, dynamic>) {
          throw const FormatException('Unexpected JSON format.');
        }
        final ok = map['status'] == true ||
            map['status'] == 'true' ||
            map['status'] == 'success';
        if (!ok) {
          throw Exception((map['message'] ?? 'Failed to fetch shifts').toString());
        }
        return MyShiftsBundle.fromJson(map);
      }

      _throwForStatus(res.statusCode, res.body);
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on FormatException catch (e) {
      throw Exception('Bad JSON: $e');
    }
  }
}
