class BookNoteModel {
  const BookNoteModel({
    required this.id,
    required this.userId,
    required this.userBookId,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final int userBookId;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BookNoteModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    return BookNoteModel(
      id: parseInt(json['id']) ?? 0,
      userId: parseInt(json['user_id']) ?? 0,
      userBookId: parseInt(json['user_book_id']) ?? 0,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }
}
