// lib/viewmodels/auth_viewmodel.dart
import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool isLoading = false;
  String? errorMessage;
  String? token;
  UserModel? currentUser;

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();

    try {
      final result = await _apiService.post('/auth/login', {
        'email': normalizedEmail,
        'password': password,
      });

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final userJson = data['user'] as Map<String, dynamic>? ?? {};

        token = data['token'] as String?;
        currentUser = UserModel.fromJson(userJson);
        return true;
      }

      errorMessage = result['message'] as String? ?? 'Login failed';
      return false;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Đăng nhập thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();

    try {
      final result = await _apiService.post('/auth/signup', {
        'name': name,
        'email': normalizedEmail,
        'password': password,
      });

      if (result['success'] == true) {
        return true;
      }

      errorMessage = result['message'] as String? ?? 'Sign up failed';
      return false;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Đăng ký thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    isLoading = false;
    errorMessage = null;
    token = null;
    currentUser = null;
    notifyListeners();
  }
}
