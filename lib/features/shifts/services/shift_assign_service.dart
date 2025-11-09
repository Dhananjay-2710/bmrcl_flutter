import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../../../constants/api_constants.dart';
import '../models/assign_shift_models.dart';

class ShiftAssignService {
  final ApiClient api;
  ShiftAssignService(this.api);

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

  Future<List<AssignShift>> listAll(String token) async {
    try {
      final res = await api.get(
        ApiConstants.shiftAssignList,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
        if (!ok) throw Exception(map['message'] ?? 'Failed to fetch assigned shifts');
        final list = (map['all_assign_shifts'] as List).cast<dynamic>();
        return list.map((e) => AssignShift.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw _buildHttpError(res.statusCode, res.body, 'ShiftAssignService.listAll');
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }

  Future<AssignShiftDetail> detail(String token, int id) async {
    try {
      final res = await api.get(
        ApiConstants.shiftAssignShow(id),
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final ok = map['status'] == true || map['status'] == 'true' || map['status'] == 'success';
        if (!ok) {
          throw Exception(map['message'] ?? 'Failed to fetch shift assignment detail');
        }
        final data = map['shift_assignment'];
        if (data is Map<String, dynamic>) {
          return AssignShiftDetail.fromJson(data);
        }
        if (data is Map) {
          return AssignShiftDetail.fromJson(Map<String, dynamic>.from(data as Map<dynamic, dynamic>));
        }
        throw const FormatException('Unexpected response shape for shift assignment detail');
      }
      throw _buildHttpError(res.statusCode, res.body, 'ShiftAssignService.detail');
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
        retryOn401: true,
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      throw _buildHttpError(res.statusCode, res.body, 'ShiftAssignService.create');
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }

  Future<bool> bulkCreate(String token, AssignBulkShiftInput input) async {
    try {
      final res = await api.post(
        ApiConstants.shiftAssignBulkStore,
        token: token,
        body: jsonEncode(input.toJson()),
        retryOn401: true,
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      throw _buildHttpError(res.statusCode, res.body, 'ShiftAssignService.bulkCreate');
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
        retryOn401: true,
      );
      if (res.statusCode == 200) return true;
      throw _buildHttpError(res.statusCode, res.body, 'ShiftAssignService.update');
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
        retryOn401: true,
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;
      throw _buildHttpError(res.statusCode, res.body, 'ShiftAssignService.delete');
    } on SocketException catch (e) {
      throw Exception('Network/DNS error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out.');
    }
  }
}
