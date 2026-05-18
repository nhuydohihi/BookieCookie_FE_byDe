import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/book_detail_model.dart';
import '../data/models/book_note_model.dart';
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
  List<BookNoteModel> notes = const [];
  List<BookQuoteModel> quotes = const [];
  bool isLoading = false;
  bool isStartingReading = false;
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

        final noteResult = await _apiService.get(
          '/notes/book/$userBookId?userId=${user.id}',
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        );

        if (noteResult['success'] == true) {
          final rawNotes = noteResult['data'];
          notes = rawNotes is List
              ? rawNotes
                    .whereType<Map>()
                    .map(
                      (item) => BookNoteModel.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                    )
                    .toList()
              : const [];
        } else {
          notes = const [];
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
    try {
      final result = await _apiService.post('/notes', {
        'user_id': user.id,
        'user_book_id': userBookId,
        'content': note,
      }, headers: token == null ? null : {'Authorization': 'Bearer $token'});

      if (result['success'] == true) {
        return true;
      }
    } catch (_) {
      // Surface a simple failure state to the caller.
    }

    return false;
  }

  Future<bool> saveQuote(String quote) async {
    try {
      final result = await _apiService.post('/quotes', {
        'user_id': user.id,
        'user_book_id': userBookId,
        'content': quote,
        'ocr_text': quote,
        'ocr_status': 'manual',
      }, headers: token == null ? null : {'Authorization': 'Bearer $token'});

      if (result['success'] == true) {
        return true;
      }
    } catch (_) {
      // Surface a simple failure state to the caller.
    }

    return false;
  }
}
