import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/book_detail_model.dart';
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
      } else {
        errorMessage = result['message'] as String? ?? 'Failed to load book detail';
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
}
