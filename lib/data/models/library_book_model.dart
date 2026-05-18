class LibraryBookModel {
  const LibraryBookModel({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    required this.status,
    this.coverImageUrl,
    this.rating,
    this.note,
  });

  final int id;
  final int bookId;
  final String title;
  final String author;
  final String status;
  final String? coverImageUrl;
  final int? rating;
  final String? note;

  factory LibraryBookModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawBookId = json['book_id'];
    final rawRating = json['rating'];

    return LibraryBookModel(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      bookId: rawBookId is num
          ? rawBookId.toInt()
          : int.tryParse('$rawBookId') ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      status: json['status'] as String? ?? 'plan_to_read',
      coverImageUrl: json['cover_image_url'] as String?,
      rating: rawRating is num ? rawRating.toInt() : int.tryParse('$rawRating'),
      note: json['note'] as String?,
    );
  }
}
