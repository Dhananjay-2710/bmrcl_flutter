import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class UsersProvider extends ChangeNotifier {
  List<UserModel> items = [];
  bool loading = false;
  String? error;

  Future<void> load(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await UserService.fetchUsers(token);
    } catch (e) {
      error = e.toString();
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String token) => load(token);
}
