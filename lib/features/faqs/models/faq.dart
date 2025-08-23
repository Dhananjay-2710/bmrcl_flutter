class Faq {
  final int id;
  final String question;
  final String answer;
  final String? description;
  final String? remark;
  final String? category;
  final String? priority;
  final String? status;
  final int? addedBy;

  Faq({
    required this.id,
    required this.question,
    required this.answer,
    this.description,
    this.remark,
    this.category,
    this.priority,
    this.status,
    this.addedBy,
  });

  factory Faq.fromJson(Map<String, dynamic> j) {
    return Faq(
      id: j['id'] ?? 0,
      question: j['question'] ?? '',
      answer: j['answer'] ?? '',
      description: j['description'],
      remark: j['remark'],
      category: j['category'],
      priority: j['priority'],
      status: j['status'],
      addedBy: j['added_by'],
    );
  }
}
