import 'package:flutter/foundation.dart';
import '../models/faq.dart';
import '../services/faq_service.dart';

class FaqsProvider extends ChangeNotifier {
  final FaqService service;
  FaqsProvider(this.service);

  List<Faq> items = [];
  bool loading = false;
  String? error;

  bool get hasData => items.isNotEmpty;
  bool get hasError => error != null;

  Future<void> load(String token) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      items = await service.fetchFaqs(token);
    } catch (e) {
      error = e.toString();
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String token) => load(token);

  void clear() {
    items = [];
    error = null;
    loading = false;
    notifyListeners();
  }
}
