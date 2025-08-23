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
    required this.assignBy,
    required this.deviceId,
    required this.assignDeviceSerialNumber,
    required this.organizationId,
  });

  factory Task.fromJson(Map<String, dynamic> j) {
    DateTime? parsed;
    final d = j['due_datetime'];
    if (d != null && d is String && d.isNotEmpty) {
      try {
        parsed = DateTime.parse(d.replaceFirst(' ', 'T'));
      } catch (_) {
        parsed = null;
      }
    }

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
      dueDateTime: parsed,
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
    'assign_by': assignBy,
    'device_id': deviceId,
    'assign_device_serial_number': assignDeviceSerialNumber,
    'organization_id': organizationId,
  };
}
