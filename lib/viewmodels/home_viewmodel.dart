import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/home_dashboard_model.dart';
import '../data/models/user_model.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.user,
    this.token,
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final UserModel user;
  final String? token;

  HomeDashboardModel? dashboard;
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadDashboard() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.get(
        '/home/${user.id}/dashboard',
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        dashboard = HomeDashboardModel.fromJson(data);
      } else {
        errorMessage = result['message'] as String? ?? 'Failed to load homepage';
      }
    } catch (_) {
      errorMessage = 'Could not load homepage data';
    }

    isLoading = false;
    notifyListeners();
  }
}
