import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/week_off.dart';

class WeekOffService {
  final ApiClient api;
  WeekOffService(this.api);

  Exception _buildHttpError(int code, String body, String context) {
    debugPrint('[$context] HTTP $code: $body');
    if (code == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (code == 404) {
      return Exception('We couldn\'t find that resource (404).');
    }
    if (code >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  /// Fetch list of week offs
  Future<List<WeekOff>> fetchWeekOffs(String token) async {

    try {
      final res = await api.get(
        ApiConstants.weekOffListEndpoint,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );

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

      throw _buildHttpError(res.statusCode, res.body, 'WeekOffService.fetchWeekOffs');
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
        retryOn401: true,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final map = jsonDecode(res.body);
        if (map['status'] != 'success') {
          throw Exception(map['message'] ?? 'Failed to create week off');
        }
        return WeekOff.fromJson(map['data']);
      }

      throw _buildHttpError(res.statusCode, res.body, 'WeekOffService.createWeekOff');
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
        retryOn401: true,
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

      throw _buildHttpError(res.statusCode, res.body, 'WeekOffService.updateWeekOff');
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
        retryOn401: true,
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

      throw _buildHttpError(res.statusCode, res.body, 'WeekOffService.deleteWeekOff');
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on FormatException catch (e) {
      throw Exception('Bad JSON: $e');
    }
  }
}
