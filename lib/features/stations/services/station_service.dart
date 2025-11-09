import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/station.dart';

class StationService {
  final ApiClient api;
  StationService(this.api);

  Exception _buildHttpError(int statusCode, String body) {
    debugPrint('[StationService] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<List<Station>> fetchStations(String token) async {
    final res = await api.get(
      ApiConstants.stationListEndpoint,
      token: token,
      retryOn401: true,
      retryOn5xx: true,
    );

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['stations'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Station.fromJson)
          .toList();
      return list;
    }
    throw _buildHttpError(res.statusCode, res.body);
  }
}
