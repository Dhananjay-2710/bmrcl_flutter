import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/faq.dart';

class FaqService {
  static Future<List<Faq>> fetchFaqs(String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.faqEndpoint}');

    final res = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> map = jsonDecode(res.body);

      if (map['status'] == "true" && map['faq'] != null) {
        final list = map['faq'] as List<dynamic>;
        return list.map((e) => Faq.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        throw Exception(map['message'] ?? "Invalid response");
      }
    } else {
      throw Exception('Failed to load FAQs: ${res.statusCode} → ${res.body}');
    }
  }
}
