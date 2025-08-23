import 'package:intl/intl.dart';

class Note {
  final int id;
  final int userId;
  final String title;
  final String content;
  final String visibility;
  final String noteableType;
  final int noteableId;
  final int organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.visibility,
    required this.noteableType,
    required this.noteableId,
    required this.organizationId,
    this.createdAt,
    this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> j) {
    return Note(
      id: (j['id'] as num).toInt(),
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      title: j['title']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      visibility: j['visibility']?.toString() ?? '',
      noteableType: j['noteable_type']?.toString() ?? '',
      noteableId: (j['noteable_id'] as num?)?.toInt() ?? 0,
      organizationId: (j['organization_id'] as num?)?.toInt() ?? 0,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJsonCreate() {
    return {
      'title': title,
      'content': content,
    };
  }

  Map<String, dynamic> toJsonUpdate() {
    return {
      'title': title,
      'content': content,
    };
  }

  String get formattedCreatedAt {
    if (createdAt == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt!);
  }

  String get formattedUpdatedAt {
    if (updatedAt == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(updatedAt!);
  }
}
