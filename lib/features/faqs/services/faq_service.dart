import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/faq.dart';

class FaqService {
  final ApiClient api;
  FaqService(this.api);

  Exception _buildHttpError(int statusCode, String body) {
    debugPrint('[FaqService] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<List<Faq>> fetchFaqs(String token) async {
    final res = await api.get(
      ApiConstants.faqEndpoint,
      token: token,
      retryOn401: true,
      retryOn5xx: true,
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> map = jsonDecode(res.body);

      if (map['status'] == "true" && map['faq'] != null) {
        final list = map['faq'] as List<dynamic>;
        return list.map((e) => Faq.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        throw Exception(map['message'] ?? "Invalid response");
      }
    }
    throw _buildHttpError(res.statusCode, res.body);
  }
}
