import 'package:flutter/material.dart';

class AchievementModel {
  const AchievementModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.targetType,
    required this.targetValue,
    required this.createdAt,
    this.progressValue = 0,
    this.isUnlocked = false,
    this.achievedAt,
  });

  final int id;
  final String name;
  final String description;
  final String iconUrl;
  final String targetType;
  final int targetValue;
  final DateTime? createdAt;
  final int progressValue;
  final bool isUnlocked;
  final DateTime? achievedAt;

  double get progress {
    if (targetValue <= 0) {
      return isUnlocked ? 1 : 0;
    }

    return (progressValue / targetValue).clamp(0, 1).toDouble();
  }

  AchievementModel copyWith({
    int? progressValue,
    bool? isUnlocked,
    DateTime? achievedAt,
  }) {
    return AchievementModel(
      id: id,
      name: name,
      description: description,
      iconUrl: iconUrl,
      targetType: targetType,
      targetValue: targetValue,
      createdAt: createdAt,
      progressValue: progressValue ?? this.progressValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      achievedAt: achievedAt ?? this.achievedAt,
    );
  }

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: _toInt(json['id']),
      name: json['name'] as String? ?? 'Achievement',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String? ?? '',
      targetType: json['target_type'] as String? ?? 'books_finished',
      targetValue: _toInt(json['target_value']),
      createdAt: _toDateTime(json['created_at']),
    );
  }
}

class UserAchievementModel {
  const UserAchievementModel({
    required this.id,
    required this.userId,
    required this.achievementId,
    this.achievedAt,
  });

  final int id;
  final int userId;
  final int achievementId;
  final DateTime? achievedAt;

  factory UserAchievementModel.fromJson(Map<String, dynamic> json) {
    return UserAchievementModel(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id']),
      achievementId: _toInt(json['achievement_id']),
      achievedAt: _toDateTime(json['achieved_at']),
    );
  }
}

class AchievementStats {
  const AchievementStats({
    required this.readingHours,
    required this.booksFinished,
    required this.streakDays,
    required this.quotesSaved,
    required this.overview,
  });

  final int readingHours;
  final int booksFinished;
  final int streakDays;
  final int quotesSaved;
  final ChallengeOverview overview;

  int valueFor(String targetType) {
    switch (targetType) {
      case 'reading_hours':
        return readingHours;
      case 'books_finished':
        return booksFinished;
      case 'streak_days':
        return streakDays;
      case 'quotes_saved':
        return quotesSaved;
      default:
        return 0;
    }
  }
}

class ChallengeOverview {
  const ChallengeOverview({
    required this.year,
    required this.readingHours,
    required this.booksFinished,
    required this.streakDays,
    required this.quotesSaved,
    required this.currentReadingCount,
    required this.activeDays,
    required this.completionRate,
    required this.yearlyActivityLevels,
    this.highlightedBookTitle,
  });

  final int year;
  final int readingHours;
  final int booksFinished;
  final int streakDays;
  final int quotesSaved;
  final int currentReadingCount;
  final int activeDays;
  final double completionRate;
  final List<int> yearlyActivityLevels;
  final String? highlightedBookTitle;

  factory ChallengeOverview.empty() {
    final now = DateTime.now();
    final daysInYear = DateTime(
      now.year + 1,
      1,
      1,
    ).difference(DateTime(now.year, 1, 1)).inDays;

    return ChallengeOverview(
      year: now.year,
      readingHours: 0,
      booksFinished: 0,
      streakDays: 0,
      quotesSaved: 0,
      currentReadingCount: 0,
      activeDays: 0,
      completionRate: 0,
      yearlyActivityLevels: List<int>.filled(daysInYear, 0),
    );
  }
}

IconData iconForAchievement(String iconUrl, String targetType) {
  final iconKey = iconUrl.trim().toLowerCase();

  switch (iconKey) {
    case 'schedule':
    case 'timer':
    case 'hourglass':
      return Icons.schedule_rounded;
    case 'book':
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'streak':
    case 'fire':
      return Icons.local_fire_department_rounded;
    case 'quote':
    case 'format_quote':
      return Icons.format_quote_rounded;
    case 'award':
    case 'medal':
    case 'trophy':
      return Icons.workspace_premium_rounded;
  }

  switch (targetType) {
    case 'reading_hours':
      return Icons.schedule_rounded;
    case 'books_finished':
      return Icons.menu_book_rounded;
    case 'streak_days':
      return Icons.local_fire_department_rounded;
    case 'quotes_saved':
      return Icons.format_quote_rounded;
    default:
      return Icons.workspace_premium_rounded;
  }
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse('$value') ?? 0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}
