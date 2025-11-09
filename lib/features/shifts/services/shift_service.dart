import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/my_shifts_models.dart';

class ShiftService {
  final ApiClient api;
  ShiftService(this.api);

  Exception _buildHttpError(int statusCode, String body) {
    debugPrint('[ShiftService] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<MyShiftsBundle> fetchMyShifts(String token) async {
    try {
      final res = await api.get(
        ApiConstants.myShiftEndpoint,
        token: token,
        retryOn401: true,
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
          throw Exception((map['message'] ?? 'Failed to fetch shifts').toString());
        }
        return MyShiftsBundle.fromJson(map);
      }

      throw _buildHttpError(res.statusCode, res.body);
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on FormatException catch (e) {
      throw Exception('Bad JSON: $e');
    } catch (e) {
      debugPrint('[ShiftService] fetchMyShifts error: $e');
      rethrow;
    }
  }
}
