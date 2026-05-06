import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/library_book_model.dart';
import '../data/models/user_model.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required this.user,
    this.token,
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final UserModel user;
  final String? token;

  List<LibraryBookModel> books = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadLibrary() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.get(
        '/user-books/${user.id}',
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        final data = result['data'] as List<dynamic>? ?? [];
        books = data
            .whereType<Map>()
            .map((item) => LibraryBookModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else {
        errorMessage = result['message'] as String? ?? 'Failed to load library';
      }
    } catch (_) {
      errorMessage = 'Could not load library data';
    }

    isLoading = false;
    notifyListeners();
  }
}
