import 'package:flutter/foundation.dart';
import '../models/faq.dart';
import '../services/faq_service.dart';

class FaqsProvider extends ChangeNotifier {
  List<Faq> items = [];
  bool loading = false;
  String? error;

  Future<void> load(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await FaqService.fetchFaqs(token);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String token) => load(token);
}
