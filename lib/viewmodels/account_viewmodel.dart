import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/user_model.dart';

class AccountViewModel extends ChangeNotifier {
  AccountViewModel({required this.initialUser, this.token});

  final ApiService _apiService = ApiService();
  final UserModel initialUser;
  final String? token;

  bool isLoading = false;
  String? errorMessage;
  UserModel? user;

  UserModel get displayUser => user ?? initialUser;

  Future<void> loadProfile() async {
    if (token == null || token!.trim().isEmpty) {
      user = initialUser;
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.get(
        '/auth/me',
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = result['data'] as Map<String, dynamic>? ?? {};
      user = UserModel.fromJson(data);
    } on ApiException catch (error) {
      errorMessage = error.message;
      user = initialUser;
    } catch (_) {
      errorMessage = 'Khong the tai thong tin tai khoan. Vui long thu lai.';
      user = initialUser;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
