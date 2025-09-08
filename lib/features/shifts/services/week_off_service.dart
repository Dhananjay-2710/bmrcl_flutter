import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/week_off.dart';

class WeekOffService {
  final ApiClient api;
  WeekOffService(this.api);

  Never _throwForStatus(int code, String body) {
    if (code == 401) throw Exception('Unauthorized. Please login again.');
    if (code == 404) throw Exception('Endpoint not found (404).');
    if (code >= 500) throw Exception('Server error ($code).');
    throw Exception('HTTP $code: $body');
  }

  /// Fetch list of week offs
  Future<List<WeekOff>> fetchWeekOffs(String token) async {

    try {
      final res = await api.get(
        ApiConstants.weekOffListEndpoint,
        token: token,
      );
      print('Week Off -> ${res.statusCode}\n${res.body}');

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);

        if (map is! Map<String, dynamic>) {
          throw const FormatException('Unexpected JSON format.');
        }

        final ok = map['status'] == true ||
            map['status'] == 'true' ||
            map['status'] == 'success';
        if (!ok) {
          throw Exception((map['message'] ?? 'Failed to fetch week offs').toString());
        }

        final dataList = (map['data']?['data'] ?? []) as List;
        return dataList.map((e) => WeekOff.fromJson(e)).toList();
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

  Future<WeekOff> createWeekOff(String token, WeekOff input) async {
    try {
      final res = await api.post(
        ApiConstants.weekOffCreateEndpoint,
        body: jsonEncode(input.toJson()),
        token: token,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final map = jsonDecode(res.body);
        if (map['status'] != 'success') {
          throw Exception(map['message'] ?? 'Failed to create week off');
        }
        return WeekOff.fromJson(map['data']);
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

  /// Update a week off
  Future<WeekOff> updateWeekOff(String token, WeekOff weekOff) async {
    try {
      final res = await api.post(
        '${ApiConstants.weekOffEndpoint}/update/${weekOff.id}',
        token: token,
        body: jsonEncode(weekOff.toJson()),
        // body: weekOff.toJson(),
      );

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true ||
            map['status'] == 'true' ||
            map['status'] == 'success';
        if (!ok) {
          throw Exception((map['message'] ?? 'Failed to update week off').toString());
        }
        return WeekOff.fromJson(map['data']);
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

  /// Delete a week off
  Future<void> deleteWeekOff(String token, int id) async {
    try {
      final res = await api.delete(
        '${ApiConstants.weekOffEndpoint}/delete/$id',
        token: token,
      );

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true ||
            map['status'] == 'true' ||
            map['status'] == 'success';
        if (!ok) {
          throw Exception((map['message'] ?? 'Failed to delete week off').toString());
        }
        return;
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
