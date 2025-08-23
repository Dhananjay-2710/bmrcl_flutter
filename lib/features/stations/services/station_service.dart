import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/station.dart';

class StationService {
  static Future<List<Station>> fetchStations(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.stationListEndpoint}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['stations'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Station.fromJson)
          .toList();
      return list;
    }
    if (res.statusCode >= 500) throw Exception('Server error ${res.statusCode}');
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
