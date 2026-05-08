import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/user_model.dart';

class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel({required this.user, this.token, ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final UserModel user;
  final String? token;

  bool isSubmitting = false;
  String? errorMessage;

  Future<UserModel?> updateProfile({
    required String name,
    required String bio,
    String? avatarPath,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.postMultipart(
        '/auth/me/update',
        fields: {'name': name, 'bio': bio},
        fileField: 'avatar',
        filePath: avatarPath,
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final updatedUser = UserModel.fromJson(data);
        isSubmitting = false;
        notifyListeners();
        return updatedUser;
      }

      errorMessage = result['message'] as String? ?? 'Could not update profile';
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isSubmitting = false;
    notifyListeners();
    return null;
  }
}
