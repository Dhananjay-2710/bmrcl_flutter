class Faq {
  final int id;
  final String question;
  final String answer;
  final String description;
  final String remark;
  final String category;
  final String priority;
  final String status;
  final int addedBy;

  Faq({
    required this.id,
    required this.question,
    required this.answer,
    required this.description,
    required this.remark,
    required this.category,
    required this.priority,
    required this.status,
    required this.addedBy,
  });

  factory Faq.fromJson(Map<String, dynamic> json) {
    return Faq(
      id: json['id'] ?? 0,
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      description: json['description'] ?? '',
      remark: json['remark'] ?? '',
      category: json['category'] ?? '',
      priority: json['priority'] ?? '',
      status: json['status'] ?? '',
      addedBy: json['added_by'] ?? 0,
    );
  }
}

class FaqResponse {
  final bool status;
  final String message;
  final List<Faq> faq;

  FaqResponse({
    required this.status,
    required this.message,
    required this.faq,
  });

  factory FaqResponse.fromJson(Map<String, dynamic> json) {
    return FaqResponse(
      status: json['status'] == "true",
      message: json['message'] ?? '',
      faq: (json['faq'] as List<dynamic>?)
          ?.map((e) => Faq.fromJson(e))
          .toList() ??
          [],
    );
  }
}
