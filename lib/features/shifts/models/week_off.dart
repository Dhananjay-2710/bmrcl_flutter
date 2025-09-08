class WeekOff {
  final int id;
  final int userId;
  final int assignBy;
  final int organizationId;
  final DateTime? offDate;
  final String? weekday;
  final bool isRecurring;
  final String? reason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userName;

  WeekOff({
    required this.id,
    required this.userId,
    required this.assignBy,
    required this.organizationId,
    this.offDate,
    required this.weekday,
    required this.isRecurring,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
    required this.userName,
  });

  factory WeekOff.fromJson(Map<String, dynamic> json) {
    return WeekOff(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      assignBy: json['assign_by'] ?? 0,
      organizationId: json['organization_id'] ?? 0,
      offDate: json['off_date'] != null
          ? DateTime.tryParse(json['off_date'])
          : null,
      weekday: json['weekday'] ?? '',
      isRecurring: json['is_recurring'] == true || json['is_recurring'] == 1,
      reason: json['reason'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      userName: json['userName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'assign_by': assignBy,
      'organization_id': organizationId,
      'off_date': offDate?.toIso8601String(),
      'weekday': weekday,
      'is_recurring': isRecurring ? 1 : 0,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'userName': userName,
    };
  }

  /// ✅ Use this when calling `/week_off/store`
  Map<String, dynamic> toCreateJson() {
    return {
      'user_id': userId,
      'off_date': offDate != null
          ? "${offDate!.day.toString().padLeft(2, '0')}-${offDate!.month.toString().padLeft(2, '0')}-${offDate!.year}"
          : null,
      'is_recurring': isRecurring ? 1 : 0,
      'weekday': weekday,
      'reason': reason ?? "",
    };
  }

  WeekOff copyWith({
    DateTime? offDate,
    String? weekday,
    bool? isRecurring,
    String? reason,
  }) {
    return WeekOff(
      id: id,
      userId: userId,
      assignBy: assignBy,
      organizationId: organizationId,
      offDate: offDate ?? this.offDate,
      weekday: weekday ?? this.weekday,
      isRecurring: isRecurring ?? this.isRecurring,
      reason: reason ?? this.reason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      userName: userName,
    );
  }
}
