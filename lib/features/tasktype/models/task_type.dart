class TaskType {
  final int id;
  final String name;
  final String description;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskType({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskType.fromJson(Map<String, dynamic> json) {
    return TaskType(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      isActive: json['is_active'] == 1,
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
