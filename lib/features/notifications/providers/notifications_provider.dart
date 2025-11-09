import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/notifications_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationsService service;
  String? _token;

  NotificationsProvider({required this.service});

  bool get isAuthenticated => (_token != null && _token!.isNotEmpty);

  // state
  final List<AppNotification> _items = [];
  int _currentPage = 0;
  int _lastPage = 0;             // <-- was 1; start at 0 so hasMore is false initially
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  int _unreadCount = 0;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _lastPage > 0 && _currentPage < _lastPage;  // <-- guard
  int get total => _total;

  void updateToken(String? token) {
    _token = token;
    notifyListeners();
  }

  void reset() {
    _token = null;
    _items.clear();
    _currentPage = 0;
    _lastPage = 0;
    _total = 0;
    _unreadCount = 0;
    _loading = false;
    _loadingMore = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    // if not logged in, clear and bail
    if (!isAuthenticated) {
      _items.clear();
      _currentPage = 0;
      _lastPage = 0;
      _total = 0;
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    
    try {
      final page = await service.list(token: _token!, page: 1);
      _items
        ..clear()
        ..addAll(page.data);
      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      _total = page.total;

      final unread = await service.unread(token: _token!);
      _unreadCount = unread.length;
    } catch (e) {
      // Stop the infinite loader if an error occurs
      _lastPage = _currentPage;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!isAuthenticated || !hasMore || _loadingMore) return;

    _loadingMore = true;
    notifyListeners();
    try {
      final next = _currentPage + 1;
      final page = await service.list(token: _token!, page: next);
      _items.addAll(page.data);
      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      _total = page.total;
    } catch (e) {
      // Stop the infinite loader on failure
      _lastPage = _currentPage;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    if (!isAuthenticated) return;
    await service.markRead(token: _token!, id: id);
    final i = _items.indexWhere((n) => n.id == id);
    if (i != -1) _items[i].readAt = DateTime.now();
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    if (!isAuthenticated) return;
    await service.markAllRead(token: _token!);
    for (final n in _items) {
      n.readAt ??= DateTime.now();
    }
    _unreadCount = 0;
    notifyListeners();
  }
}
