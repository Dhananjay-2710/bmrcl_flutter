import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../models/faq.dart';

class FaqService {
  static Future<List<Faq>> fetchFaqs(String token) async {
    // If your endpoint is /faq (based on your sample), set it in ApiConstants.faqEndpoint
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.faqEndpoint}');

    final res = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      // Your JSON has the list under "faq"
      final list = (map['faq'] as List?) ?? [];
      return list.map((e) => Faq.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load FAQs: ${res.body}');
    }
  }
}
