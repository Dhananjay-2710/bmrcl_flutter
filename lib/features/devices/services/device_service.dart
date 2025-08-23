import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/device.dart';

class DeviceService {
  static Future<List<DeviceModel>> fetchDevices(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deviceListEndpoint}');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (map['devices'] ?? map['device'] ?? []) as List<dynamic>;
      return list.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load devices: ${res.body}');
    }
  }
}
