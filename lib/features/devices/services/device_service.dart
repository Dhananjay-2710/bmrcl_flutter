import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/device.dart';

class DeviceService {
  final ApiClient api;
  DeviceService(this.api);

  Exception _buildHttpError(int statusCode, String body) {
    debugPrint('[DeviceService] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<List<DeviceModel>> fetchDevices(String token) async {
    final res = await api.get(
      ApiConstants.deviceListEndpoint,
      token: token,
      retryOn401: true,
      retryOn5xx: true,
    );
    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['devices'] ?? map['device'] ?? []) as List<dynamic>;
      return list.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw _buildHttpError(res.statusCode, res.body);
  }
}
