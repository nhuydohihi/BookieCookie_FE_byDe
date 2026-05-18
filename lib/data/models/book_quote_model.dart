class BookQuoteModel {
  const BookQuoteModel({
    required this.id,
    required this.userId,
    required this.userBookId,
    required this.content,
    this.note,
    this.pageNumber,
    this.imageUrl,
    this.ocrText,
    this.ocrStatus,
    this.ocrConfidence,
    this.createdAt,
  });

  final int id;
  final int userId;
  final int userBookId;
  final String content;
  final String? note;
  final int? pageNumber;
  final String? imageUrl;
  final String? ocrText;
  final String? ocrStatus;
  final double? ocrConfidence;
  final DateTime? createdAt;

  factory BookQuoteModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value');
    }

    return BookQuoteModel(
      id: parseInt(json['id']) ?? 0,
      userId: parseInt(json['user_id']) ?? 0,
      userBookId: parseInt(json['user_book_id']) ?? 0,
      content: json['content'] as String? ?? '',
      note: json['note'] as String?,
      pageNumber: parseInt(json['page_number']),
      imageUrl: json['image_url'] as String?,
      ocrText: json['ocr_text'] as String?,
      ocrStatus: json['ocr_status'] as String?,
      ocrConfidence: parseDouble(json['ocr_confidence']),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
