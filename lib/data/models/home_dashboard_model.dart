class HomeDashboardModel {
  const HomeDashboardModel({
    required this.currentReading,
    required this.streakDays,
    required this.activityCount,
    required this.finishedInYear,
    required this.year,
  });

  final List<CurrentReadingBook> currentReading;
  final int streakDays;
  final int activityCount;
  final List<FinishedBook> finishedInYear;
  final int year;

  factory HomeDashboardModel.fromJson(Map<String, dynamic> json) {
    final currentReadingJson = (json['currentReading'] as List<dynamic>? ?? []);
    final finishedJson = (json['finishedInYear'] as List<dynamic>? ?? []);
    final streakJson = json['streak'] as Map<String, dynamic>? ?? {};

    return HomeDashboardModel(
      currentReading: currentReadingJson
          .map((item) => CurrentReadingBook.fromJson(item as Map<String, dynamic>))
          .toList(),
      streakDays: (streakJson['days'] as num?)?.toInt() ?? 0,
      activityCount: (streakJson['activity_count'] as num?)?.toInt() ?? 0,
      finishedInYear: finishedJson
          .map((item) => FinishedBook.fromJson(item as Map<String, dynamic>))
          .toList(),
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
    );
  }
}

class CurrentReadingBook {
  const CurrentReadingBook({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    this.coverImageUrl,
  });

  final int id;
  final int bookId;
  final String title;
  final String author;
  final String? coverImageUrl;

  factory CurrentReadingBook.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawBookId = json['book_id'];

    return CurrentReadingBook(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      bookId: rawBookId is num ? rawBookId.toInt() : int.tryParse('$rawBookId') ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

class FinishedBook {
  const FinishedBook({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    this.coverImageUrl,
  });

  final int id;
  final int bookId;
  final String title;
  final String author;
  final String? coverImageUrl;

  factory FinishedBook.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawBookId = json['book_id'];

    return FinishedBook(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      bookId: rawBookId is num ? rawBookId.toInt() : int.tryParse('$rawBookId') ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}
