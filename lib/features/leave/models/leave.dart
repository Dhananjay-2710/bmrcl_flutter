class Leave {
  final int id;
  final String? leaveType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final String status;
  final String? remarks;
  final int userId;
  final String? userName;
  final String? userProfileImageUrl;
  final int? organizationId;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewerRemarks;
  final int? approvedBy;
  final DateTime? approvedAt;
  final String? approvedRemarks;
  final int? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectedRemarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Leave({
    required this.id,
    this.leaveType,
    this.startDate,
    this.endDate,
    this.reason,
    required this.status,
    this.remarks,
    required this.userId,
    this.userName,
    this.userProfileImageUrl,
    this.organizationId,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewerRemarks,
    this.approvedBy,
    this.approvedAt,
    this.approvedRemarks,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectedRemarks,
    this.createdAt,
    this.updatedAt,
  });

  factory Leave.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic d) {
      if (d == null || (d is String && d.isEmpty)) return null;
      try {
        if (d is String) {
          // Extract date part from ISO string (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
          String dateStr = d.trim();
          
          // Try to extract just the date part (YYYY-MM-DD)
          if (dateStr.contains('T') || dateStr.contains(' ')) {
            // Extract date part before T or space
            final datePart = dateStr.split(RegExp(r'[T\s]'))[0];
            if (datePart.length >= 10) {
              // Parse as YYYY-MM-DD format
              final parts = datePart.split('-');
              if (parts.length == 3) {
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final day = int.parse(parts[2]);
                // Create local DateTime (no timezone conversion)
                return DateTime(year, month, day);
              }
            }
          }
          
          // Fallback: parse normally and convert to local date
          final parsed = DateTime.parse(dateStr);
          final local = parsed.toLocal();
          return DateTime(local.year, local.month, local.day);
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    // Determine remarks based on status
    String? remarks;
    if (j['reviewer_remarks'] != null) {
      remarks = j['reviewer_remarks'];
    } else if (j['approved_remarks'] != null) {
      remarks = j['approved_remarks'];
    } else if (j['rejected_remarks'] != null) {
      remarks = j['rejected_remarks'];
    } else {
      remarks = j['remarks'];
    }

    return Leave(
      id: j['id'] ?? 0,
      leaveType: j['leave_type'],
      startDate: parseDate(j['start_date']),
      endDate: parseDate(j['end_date']),
      reason: j['reason'],
      status: j['status'] ?? 'Pending',
      remarks: remarks,
      userId: j['user_id'] ?? 0,
      userName: j['user_name'],
      userProfileImageUrl: j['user_profile_image_url'],
      organizationId: j['organization_id'],
      reviewedBy: j['reviewed_by'],
      reviewedAt: parseDate(j['reviewed_at']),
      reviewerRemarks: j['reviewer_remarks'],
      approvedBy: j['approved_by'],
      approvedAt: parseDate(j['approved_at']),
      approvedRemarks: j['approved_remarks'],
      rejectedBy: j['rejected_by'],
      rejectedAt: parseDate(j['rejected_at']),
      rejectedRemarks: j['rejected_remarks'],
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'leave_type': leaveType,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'reason': reason,
        'status': status,
        'remarks': remarks,
        'user_id': userId,
        'user_name': userName,
        'user_profile_image_url': userProfileImageUrl,
        'organization_id': organizationId,
        'reviewed_by': reviewedBy,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewer_remarks': reviewerRemarks,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'approved_remarks': approvedRemarks,
        'rejected_by': rejectedBy,
        'rejected_at': rejectedAt?.toIso8601String(),
        'rejected_remarks': rejectedRemarks,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  String get formattedStartDate {
    if (startDate == null) return '—';
    // Use local date components (already normalized in parseDate)
    return '${startDate!.day}/${startDate!.month}/${startDate!.year}';
  }

  String get formattedEndDate {
    if (endDate == null) return '—';
    // Use local date components (already normalized in parseDate)
    return '${endDate!.day}/${endDate!.month}/${endDate!.year}';
  }

  String get formattedCreatedAt {
    if (createdAt == null) return '—';
    // Use local date components
    final local = createdAt!.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

