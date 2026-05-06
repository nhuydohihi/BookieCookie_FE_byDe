class BookDetailModel {
  const BookDetailModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.title,
    required this.author,
    required this.status,
    this.coverImageUrl,
    this.rating,
    this.note,
    this.readingYear,
    this.startDate,
    this.finishDate,
    this.category,
    this.isbn,
    this.publishedYear,
    this.description,
  });

  final int id;
  final int userId;
  final int bookId;
  final String title;
  final String author;
  final String status;
  final String? coverImageUrl;
  final int? rating;
  final String? note;
  final int? readingYear;
  final String? startDate;
  final String? finishDate;
  final String? category;
  final String? isbn;
  final int? publishedYear;
  final String? description;

  factory BookDetailModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    return BookDetailModel(
      id: parseInt(json['id']) ?? 0,
      userId: parseInt(json['user_id']) ?? 0,
      bookId: parseInt(json['book_id']) ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      status: json['status'] as String? ?? 'plan_to_read',
      coverImageUrl: json['cover_image_url'] as String?,
      rating: parseInt(json['rating']),
      note: json['note'] as String?,
      readingYear: parseInt(json['reading_year']),
      startDate: json['start_date'] as String?,
      finishDate: json['finish_date'] as String?,
      category: json['category'] as String?,
      isbn: json['isbn'] as String?,
      publishedYear: parseInt(json['published_year']),
      description: json['description'] as String?,
    );
  }
}
