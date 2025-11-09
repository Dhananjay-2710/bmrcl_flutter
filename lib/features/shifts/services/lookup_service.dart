import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/lookup_models.dart';

class LookupService {
  final ApiClient api;
  LookupService(this.api);

  Exception _buildHttpError(int code, String body, String context) {
    debugPrint('[$context] HTTP $code: $body');
    if (code == 401) return Exception('Your session expired. Please login again.');
    if (code == 404) return Exception('We couldn\'t find that resource (404).');
    if (code >= 500) return Exception('We\'re having trouble reaching the server. Please try again later.');
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<List<ShiftLite>> fetchShifts(String token) async {
    try {
      final res = await api.get(
        ApiConstants.shiftsList,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch shifts');
        final list = (map['shifts'] as List).cast<dynamic>();
        return list.map((e) => ShiftLite.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw _buildHttpError(res.statusCode, res.body, 'LookupService.fetchShifts');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<List<StationLite>> fetchStations(String token) async {
    try {
      final res = await api.get(
        ApiConstants.stationsList,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch stations');
        final list = (map['stations'] as List).cast<dynamic>();
        return list.map((e) => StationLite.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw _buildHttpError(res.statusCode, res.body, 'LookupService.fetchStations');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<List<GateLite>> fetchGates(String token, int stationId) async {
    try {
      final res = await api.get(
        ApiConstants.stationsGates(stationId),
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch gates');
        final list = (map['gates'] as List).cast<dynamic>();
        return list.map((e) => GateLite.fromJson(e as Map<String, dynamic>, stationId: stationId)).toList();
      }
      throw _buildHttpError(res.statusCode, res.body, 'LookupService.fetchGates');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }
}
