import 'package:intl/intl.dart';

class Task {
  final int id;
  final String title;
  final String description;
  final int assignUserId;
  final String assignUserName;
  final String? taskImage;
  final String? taskImageURL;
  final String priority;
  final String status;
  final DateTime? dueDateTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int assignBy;
  final int deviceId;
  final String assignDeviceSerialNumber;
  final int organizationId;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assignUserId,
    required this.assignUserName,
    this.taskImage,
    this.taskImageURL,
    required this.priority,
    required this.status,
    this.dueDateTime,
    this.createdAt,
    this.updatedAt,
    required this.assignBy,
    required this.deviceId,
    required this.assignDeviceSerialNumber,
    required this.organizationId,
  });

  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is String && raw.isNotEmpty) {
      final sanitized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
      try {
        return DateTime.parse(sanitized).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _formatDate(DateTime? dateTime) {
    if (dateTime == null) return null;
    return _displayFormat.format(dateTime.toLocal());
  }

  factory Task.fromJson(Map<String, dynamic> j) {
    return Task(
      id: j['id'] ?? 0,
      title: j['title'] ?? '',
      description: j['description'] ?? '',
      assignUserId: j['assign_user_id'] ?? 0,
      assignUserName: j['assign_user_name']?? '',
      taskImage: j['task_image'],
      taskImageURL: j['task_image_url'],
      priority: j['priority'] ?? '',
      status: j['status'] ?? '',
      dueDateTime: _parseDate(j['due_datetime']),
      createdAt: _parseDate(j['created_at']),
      updatedAt: _parseDate(j['updated_at']),
      assignBy: j['assign_by'] ?? 0,
      deviceId: j['device_id'] ?? 0,
      assignDeviceSerialNumber: j['assign_device_serial_number'] ?? '',
      organizationId: j['organization_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'assign_user_id': assignUserId,
    'assign_user_name': assignUserName,
    'task_image': taskImage,
    'task_image_url': taskImageURL,
    'priority': priority,
    'status': status,
    'due_datetime': dueDateTime?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'assign_by': assignBy,
    'device_id': deviceId,
    'assign_device_serial_number': assignDeviceSerialNumber,
    'organization_id': organizationId,
  };

  String? get formattedDueDate => _formatDate(dueDateTime);
  String? get formattedAssignedTime => _formatDate(createdAt);
  String? get formattedCompletionTime => _formatDate(updatedAt);
}
