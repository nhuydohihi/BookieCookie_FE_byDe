class GoogleBookSearchResult {
  const GoogleBookSearchResult({
    required this.id,
    required this.title,
    required this.authors,
    this.thumbnailUrl,
    this.publishedDate,
    this.description,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String? thumbnailUrl;
  final String? publishedDate;
  final String? description;

  String get authorText => authors.isEmpty ? 'Unknown author' : authors.join(', ');

  factory GoogleBookSearchResult.fromJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? const {};
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>? ?? const {};
    final rawAuthors = volumeInfo['authors'];

    return GoogleBookSearchResult(
      id: json['id'] as String? ?? '',
      title: volumeInfo['title'] as String? ?? 'Untitled',
      authors: rawAuthors is List
          ? rawAuthors.whereType<String>().toList()
          : const <String>[],
      thumbnailUrl: (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail']) as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      description: volumeInfo['description'] as String?,
    );
  }
}
