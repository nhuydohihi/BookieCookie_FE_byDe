class GoogleBookSearchResult {
  const GoogleBookSearchResult({
    required this.id,
    required this.title,
    required this.authors,
    this.isbn,
    this.thumbnailUrl,
    this.publishedDate,
    this.description,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String? isbn;
  final String? thumbnailUrl;
  final String? publishedDate;
  final String? description;

  String get authorText => authors.isEmpty ? 'Unknown author' : authors.join(', ');

  static String? _normalizeUrl(dynamic value) {
    final raw = value as String?;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    return raw.replaceFirst('http://', 'https://');
  }

  factory GoogleBookSearchResult.fromJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? const {};
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>? ?? const {};
    final rawAuthors = volumeInfo['authors'];
    final thumbnailUrl =
        _normalizeUrl(imageLinks['thumbnail']) ??
        _normalizeUrl(imageLinks['smallThumbnail']) ??
        _normalizeUrl(imageLinks['small']) ??
        _normalizeUrl(imageLinks['medium']) ??
        _normalizeUrl(imageLinks['large']) ??
        _normalizeUrl(imageLinks['extraLarge']);

    return GoogleBookSearchResult(
      id: json['id'] as String? ?? '',
      title: volumeInfo['title'] as String? ?? 'Untitled',
      authors: rawAuthors is List
          ? rawAuthors.whereType<String>().toList()
          : const <String>[],
      isbn: volumeInfo['isbn'] as String?,
      thumbnailUrl: thumbnailUrl,
      publishedDate: volumeInfo['publishedDate'] as String?,
      description: volumeInfo['description'] as String?,
    );
  }
}
