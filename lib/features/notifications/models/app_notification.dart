class NotificationData {
  final String title;
  final String message; // may contain HTML
  final String url;
  final String event;
  final int? fromUserId;
  final String? fromUserName;
  final String? fromUserImage;

  NotificationData({
    required this.title,
    required this.message,
    required this.url,
    required this.event,
    this.fromUserId,
    this.fromUserName,
    this.fromUserImage,
  });

  factory NotificationData.fromMap(Map<String, dynamic> m) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return NotificationData(
      title: (m['title'] ?? '').toString(),
      message: (m['message'] ?? '').toString(),
      url: (m['url'] ?? '').toString(),
      event: (m['event'] ?? '').toString(),
      fromUserId: asInt(m['from_user_id']),
      fromUserName: m['from_user_name']?.toString(),
      fromUserImage: m['from_user_image']?.toString(),
    );
  }
}

class AppNotification {
  final String id;
  final NotificationData data;
  DateTime? readAt;

  AppNotification({
    required this.id,
    required this.data,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    DateTime? asDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    return AppNotification(
      id: (m['id'] ?? '').toString(),
      data: NotificationData.fromMap(Map<String, dynamic>.from(m['data'] ?? {})),
      readAt: asDate(m['read_at']),
    );
  }
}

class PaginatedNotifications {
  final int currentPage;
  final int lastPage;
  final int total;
  final List<AppNotification> data;
  final String? nextPageUrl;

  PaginatedNotifications({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.data,
    required this.nextPageUrl,
  });

  factory PaginatedNotifications.fromMap(Map<String, dynamic> body) {
    final wrap = Map<String, dynamic>.from(body['notifications'] ?? {});
    final list = (wrap['data'] ?? []) as List;

    int _asInt(dynamic v, [int def = 0]) =>
        int.tryParse((v ?? def).toString()) ?? def;

    return PaginatedNotifications(
      currentPage: _asInt(wrap['current_page'], 1),
      lastPage: _asInt(wrap['last_page'], 1),
      total: _asInt(wrap['total'], 0),
      nextPageUrl: wrap['next_page_url']?.toString(),
      data: list.map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e))).toList(),
    );
  }
}