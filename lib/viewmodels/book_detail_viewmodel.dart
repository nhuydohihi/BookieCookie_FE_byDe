import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/book_detail_model.dart';
import '../data/models/book_quote_model.dart';
import '../data/models/user_model.dart';

class BookDetailViewModel extends ChangeNotifier {
  BookDetailViewModel({
    required this.user,
    required this.userBookId,
    this.token,
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final UserModel user;
  final int userBookId;
  final String? token;

  BookDetailModel? detail;
  List<BookQuoteModel> quotes = const [];
  bool isLoading = false;
  bool isStartingReading = false;
  bool isSavingNote = false;
  String? errorMessage;

  Future<void> loadDetail() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.get(
        '/user-books/detail/$userBookId?userId=${user.id}',
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        detail = BookDetailModel.fromJson(data);

        final quoteResult = await _apiService.get(
          '/quotes/book/$userBookId?userId=${user.id}',
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        );

        if (quoteResult['success'] == true) {
          final rawQuotes = quoteResult['data'];
          quotes = rawQuotes is List
              ? rawQuotes
                    .whereType<Map>()
                    .map(
                      (item) => BookQuoteModel.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                    )
                    .toList()
              : const [];
        } else {
          quotes = const [];
        }
      } else {
        errorMessage =
            result['message'] as String? ?? 'Failed to load book detail';
      }
    } catch (_) {
      errorMessage = 'Could not load book detail';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> startReading() async {
    if (isStartingReading) return false;

    isStartingReading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.post(
        '/user-books/$userBookId/start-reading',
        {'user_id': user.id},
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        detail = BookDetailModel.fromJson(data);
        isStartingReading = false;
        notifyListeners();
        return true;
      }

      errorMessage = result['message'] as String? ?? 'Could not start reading';
    } catch (_) {
      errorMessage = 'Could not start reading';
    }

    isStartingReading = false;
    notifyListeners();
    return false;
  }

  Future<bool> saveNote(String note) async {
    if (isSavingNote) return false;

    isSavingNote = true;
    notifyListeners();

    try {
      final result = await _apiService.post(
        '/user-books/$userBookId/note',
        {'user_id': user.id, 'note': note},
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final currentDetail = detail;
        if (currentDetail != null) {
          detail = BookDetailModel.fromJson({
            'id': currentDetail.id,
            'user_id': currentDetail.userId,
            'book_id': currentDetail.bookId,
            'title': currentDetail.title,
            'author': currentDetail.author,
            'status': currentDetail.status,
            'cover_image_url': currentDetail.coverImageUrl,
            'rating': currentDetail.rating,
            'note': data['note'],
            'start_date': currentDetail.startDate,
            'finish_date': currentDetail.finishDate,
            'category': currentDetail.category,
            'isbn': currentDetail.isbn,
            'published_year': currentDetail.publishedYear,
            'description': currentDetail.description,
          });
        }
        isSavingNote = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Surface a simple failure state to the caller.
    }

    isSavingNote = false;
    notifyListeners();
    return false;
  }
}
