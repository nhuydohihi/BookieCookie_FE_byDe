import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import '../data/models/achievement_model.dart';
import '../data/models/home_dashboard_model.dart';
import '../data/models/user_model.dart';

class ChallengeViewModel extends ChangeNotifier {
  ChallengeViewModel({required this.user, this.token, ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  final UserModel user;
  final String? token;

  List<AchievementModel> achievements = const [];
  ChallengeOverview overview = ChallengeOverview.empty();
  bool isLoading = false;
  String? errorMessage;

  int get unlockedCount => achievements.where((item) => item.isUnlocked).length;

  AchievementModel? get nextAchievement {
    final locked = achievements.where((item) => !item.isUnlocked).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    if (locked.isEmpty) {
      return null;
    }

    return locked.first;
  }

  Future<void> loadChallenges() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final stats = await _loadStats();
      overview = stats.overview;
      achievements = await _loadAchievements(stats);
    } catch (_) {
      overview = ChallengeOverview.empty();
      achievements = _buildFallbackAchievements(
        AchievementStats(
          readingHours: 0,
          booksFinished: 0,
          streakDays: 0,
          quotesSaved: 0,
          overview: ChallengeOverview.empty(),
        ),
      );
      errorMessage =
          'Could not load challenge data from server. Showing starter achievements.';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<AchievementStats> _loadStats() async {
    final result = await _apiService.get(
      '/home/${user.id}/dashboard',
      headers: _authHeaders,
    );

    if (result['success'] != true) {
      throw const ApiException('Failed to load dashboard stats');
    }

    final data = result['data'] as Map<String, dynamic>? ?? {};
    final dashboard = HomeDashboardModel.fromJson(data);
    final estimatedMinutes =
        dashboard.currentReading.length * 120 + dashboard.activityCount * 18;

    final overview = _buildOverview(dashboard, estimatedMinutes);

    return AchievementStats(
      readingHours: (estimatedMinutes / 60).floor(),
      booksFinished: dashboard.finishedInYear.length,
      streakDays: dashboard.streakDays,
      quotesSaved: dashboard.activityCount * 2,
      overview: overview,
    );
  }

  Future<List<AchievementModel>> _loadAchievements(
    AchievementStats stats,
  ) async {
    try {
      final result = await _apiService.get(
        '/achievements/user/${user.id}',
        headers: _authHeaders,
      );

      if (result['success'] != true) {
        throw const ApiException('Failed to load achievements');
      }

      final data = result['data'];
      final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final achievementItems =
          payload['achievements'] as List<dynamic>? ??
          payload['items'] as List<dynamic>? ??
          [];
      final unlockedItems =
          payload['userAchievements'] as List<dynamic>? ??
          payload['user_achievements'] as List<dynamic>? ??
          [];

      final achievements = achievementItems
          .whereType<Map>()
          .map(
            (item) =>
                AchievementModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      final unlocked = unlockedItems
          .whereType<Map>()
          .map(
            (item) =>
                UserAchievementModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      if (achievements.isEmpty) {
        return _buildFallbackAchievements(stats);
      }

      return _mergeAchievementProgress(
        achievements: achievements,
        unlocked: unlocked,
        stats: stats,
      );
    } catch (_) {
      return _buildFallbackAchievements(stats);
    }
  }

  List<AchievementModel> _mergeAchievementProgress({
    required List<AchievementModel> achievements,
    required List<UserAchievementModel> unlocked,
    required AchievementStats stats,
  }) {
    return achievements.map((achievement) {
      final unlockedEntry = unlocked.cast<UserAchievementModel?>().firstWhere(
        (item) => item?.achievementId == achievement.id,
        orElse: () => null,
      );

      return achievement.copyWith(
        progressValue: stats.valueFor(achievement.targetType),
        isUnlocked: unlockedEntry != null,
        achievedAt: unlockedEntry?.achievedAt,
      );
    }).toList()..sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }

      return a.targetValue.compareTo(b.targetValue);
    });
  }

  List<AchievementModel> _buildFallbackAchievements(AchievementStats stats) {
    final seeded = <AchievementModel>[
      AchievementModel(
        id: 1,
        name: '100 Reading Hours',
        description: 'Spend 100 focused hours reading across your library.',
        iconUrl: 'schedule',
        targetType: 'reading_hours',
        targetValue: 100,
        createdAt: DateTime.now(),
      ),
      AchievementModel(
        id: 2,
        name: '10 Books Finished',
        description:
            'Finish 10 books and build a full year of completed reads.',
        iconUrl: 'book',
        targetType: 'books_finished',
        targetValue: 10,
        createdAt: DateTime.now(),
      ),
      AchievementModel(
        id: 3,
        name: '7-Day Streak',
        description:
            'Read every day for a full week without breaking the chain.',
        iconUrl: 'fire',
        targetType: 'streak_days',
        targetValue: 7,
        createdAt: DateTime.now(),
      ),
      AchievementModel(
        id: 4,
        name: '50 Quotes Saved',
        description: 'Save 50 favorite quotes or highlights from your books.',
        iconUrl: 'quote',
        targetType: 'quotes_saved',
        targetValue: 50,
        createdAt: DateTime.now(),
      ),
    ];

    return seeded
        .map(
          (item) => item.copyWith(
            progressValue: stats.valueFor(item.targetType),
            isUnlocked: stats.valueFor(item.targetType) >= item.targetValue,
            achievedAt: stats.valueFor(item.targetType) >= item.targetValue
                ? DateTime.now()
                : null,
          ),
        )
        .toList();
  }

  Map<String, String>? get _authHeaders =>
      token == null ? null : {'Authorization': 'Bearer $token'};

  ChallengeOverview _buildOverview(
    HomeDashboardModel dashboard,
    int estimatedMinutes,
  ) {
    final now = DateTime.now();
    final yearStart = DateTime(dashboard.year, 1, 1);
    final yearEnd = DateTime(dashboard.year, 12, 31);
    final elapsedDays = now.difference(yearStart).inDays + 1;
    final safeElapsedDays = math.max(1, elapsedDays);
    final today = DateTime(now.year, now.month, now.day);
    final activityLevels = <int>[];
    var activeDays = 0;

    for (
      var date = yearStart;
      !date.isAfter(yearEnd);
      date = date.add(const Duration(days: 1))
    ) {
      if (date.isAfter(today)) {
        activityLevels.add(0);
        continue;
      }

      final dayOfYear = date.difference(yearStart).inDays + 1;
      final weekdayWeight = switch (date.weekday) {
        DateTime.saturday || DateTime.sunday => 1,
        DateTime.friday => 2,
        _ => 3,
      };
      final rhythmSeed =
          dayOfYear +
          dashboard.activityCount * 3 +
          dashboard.currentReading.length * 5 +
          dashboard.finishedInYear.length * 7;
      final rhythmValue = rhythmSeed % 10;
      var level = 0;

      if (rhythmValue < weekdayWeight + 2) {
        level = 1;
      }
      if (rhythmValue < weekdayWeight) {
        level = 2;
      }
      if (rhythmValue == 0 || rhythmValue == 1) {
        level = 3;
      }
      if (dashboard.streakDays > 0 &&
          dayOfYear >= elapsedDays - dashboard.streakDays + 1) {
        level = 4;
      }

      if (dashboard.currentReading.isNotEmpty &&
          date.weekday <= DateTime.friday &&
          level == 0 &&
          rhythmValue.isEven) {
        level = 1;
      }

      activityLevels.add(level);
      if (level > 0) {
        activeDays++;
      }
    }

    final readingHours = (estimatedMinutes / 60).floor();
    final completionRate = (activeDays / safeElapsedDays).clamp(0.0, 1.0);

    return ChallengeOverview(
      year: dashboard.year,
      readingHours: readingHours,
      booksFinished: dashboard.finishedInYear.length,
      streakDays: dashboard.streakDays,
      quotesSaved: dashboard.activityCount * 2,
      currentReadingCount: dashboard.currentReading.length,
      activeDays: activeDays,
      completionRate: completionRate,
      highlightedBookTitle: dashboard.finishedInYear.isNotEmpty
          ? dashboard.finishedInYear.first.title
          : null,
      yearlyActivityLevels: activityLevels,
    );
  }
}
