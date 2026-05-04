import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/google_book_search_result.dart';
import '../data/models/user_model.dart';

class ManualAddBookViewModel extends ChangeNotifier {
  ManualAddBookViewModel({
    required this.user,
    this.token,
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final UserModel user;
  final String? token;

  bool isSubmitting = false;
  bool isSearchingOnline = false;
  String? errorMessage;
  String? searchErrorMessage;
  List<GoogleBookSearchResult> searchResults = const [];

  Future<bool> createBook({
    required String title,
    String? author,
    String status = 'plan_to_read',
    int? rating,
    String? note,
    int? readingYear,
    String? startDate,
    String? finishDate,
    String? coverImagePath,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.postMultipart(
        '/user-books/manual',
        fields: {
          'user_id': user.id.toString(),
          'title': title,
          'author': author ?? '',
          'status': status,
          'rating': rating?.toString() ?? '',
          'reading_year': readingYear?.toString() ?? '',
          'start_date': startDate ?? '',
          'finish_date': finishDate ?? '',
          'note': note ?? '',
        },
        fileField: 'cover',
        filePath: coverImagePath,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        isSubmitting = false;
        notifyListeners();
        return true;
      }

      errorMessage = result['message'] as String? ?? 'Could not create book';
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isSubmitting = false;
    notifyListeners();
    return false;
  }

  Future<void> searchBooksOnline(String keyword) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      searchResults = const [];
      searchErrorMessage = null;
      notifyListeners();
      return;
    }

    isSearchingOnline = true;
    searchErrorMessage = null;
    notifyListeners();

    try {
      final query = Uri.encodeQueryComponent(trimmedKeyword);
      final result = await _apiService.getByUrl(
        'https://www.googleapis.com/books/v1/volumes?q=$query&maxResults=10&printType=books',
      );

      final items = result['items'];
      if (items is List) {
        searchResults = items
            .whereType<Map>()
            .map((item) => GoogleBookSearchResult.fromJson(Map<String, dynamic>.from(item)))
            .where((book) => book.title.trim().isNotEmpty)
            .toList();
      } else {
        searchResults = const [];
      }

      if (searchResults.isEmpty) {
        searchErrorMessage = 'Khong tim thay sach phu hop voi tu khoa nay.';
      }
    } catch (error) {
      searchResults = const [];
      searchErrorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isSearchingOnline = false;
    notifyListeners();
  }
}
