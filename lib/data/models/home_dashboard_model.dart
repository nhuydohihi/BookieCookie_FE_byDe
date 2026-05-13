class HomeDashboardModel {
  const HomeDashboardModel({
    required this.currentReading,
    required this.streakDays,
    required this.maxStreakDays,
    required this.activityCount,
    required this.finishedInYear,
    required this.year,
    this.statistics,
    this.goals,
  });

  final List<CurrentReadingBook> currentReading;
  final int streakDays;
  final int maxStreakDays;
  final int activityCount;
  final List<FinishedBook> finishedInYear;
  final int year;
  final DashboardStatistics? statistics;
  final DashboardGoals? goals;

  factory HomeDashboardModel.fromJson(Map<String, dynamic> json) {
    final currentReadingJson = (json['currentReading'] as List<dynamic>? ?? []);
    final finishedJson = (json['finishedInYear'] as List<dynamic>? ?? []);
    final streakJson = json['streak'] as Map<String, dynamic>? ?? {};

    return HomeDashboardModel(
      currentReading: currentReadingJson
          .map(
            (item) => CurrentReadingBook.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      streakDays: (streakJson['days'] as num?)?.toInt() ?? 0,
      maxStreakDays: (streakJson['max_days'] as num?)?.toInt() ?? 0,
      activityCount: (streakJson['activity_count'] as num?)?.toInt() ?? 0,
      finishedInYear: finishedJson
          .map((item) => FinishedBook.fromJson(item as Map<String, dynamic>))
          .toList(),
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      statistics: json['statistics'] is Map<String, dynamic>
          ? DashboardStatistics.fromJson(
              json['statistics'] as Map<String, dynamic>,
            )
          : null,
      goals: json['goals'] is Map<String, dynamic>
          ? DashboardGoals.fromJson(json['goals'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DashboardStatistics {
  const DashboardStatistics({
    required this.today,
    required this.week,
    required this.chart,
    required this.year,
  });

  final TodayStatistics today;
  final List<WeekdayStatistics> week;
  final ReadingChartStatistics chart;
  final YearStatistics year;

  factory DashboardStatistics.fromJson(Map<String, dynamic> json) {
    final weekJson = json['week'] as List<dynamic>? ?? [];

    return DashboardStatistics(
      today: TodayStatistics.fromJson(
        json['today'] as Map<String, dynamic>? ?? const {},
      ),
      week: weekJson
          .map(
            (item) => WeekdayStatistics.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      chart: ReadingChartStatistics.fromJson(
        json['chart'] as Map<String, dynamic>? ?? const {},
      ),
      year: YearStatistics.fromJson(
        json['year'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class TodayStatistics {
  const TodayStatistics({
    required this.minutes,
    required this.pagesRead,
    required this.goalMinutes,
    required this.progress,
  });

  final int minutes;
  final int pagesRead;
  final int goalMinutes;
  final double progress;

  factory TodayStatistics.fromJson(Map<String, dynamic> json) {
    return TodayStatistics(
      minutes: _toInt(json['minutes']),
      pagesRead: _toInt(json['pages_read']),
      goalMinutes: _toInt(json['goal_minutes']),
      progress: _toDouble(json['progress']),
    );
  }
}

class WeekdayStatistics {
  const WeekdayStatistics({
    required this.label,
    required this.shortLabel,
    required this.minutes,
    required this.pagesRead,
    this.date,
  });

  final String label;
  final String shortLabel;
  final int minutes;
  final int pagesRead;
  final DateTime? date;

  factory WeekdayStatistics.fromJson(Map<String, dynamic> json) {
    return WeekdayStatistics(
      label: json['label'] as String? ?? '',
      shortLabel: json['short_label'] as String? ?? '',
      minutes: _toInt(json['minutes']),
      pagesRead: _toInt(json['pages_read']),
      date: _toDateTime(json['date']),
    );
  }
}

class YearStatistics {
  const YearStatistics({
    required this.readingHours,
    required this.readingMinutes,
    required this.booksFinished,
    required this.quotesSaved,
    required this.currentReadingCount,
    required this.activeDays,
    required this.completionRate,
    required this.yearlyGoalBooks,
    required this.yearlyActivityLevels,
    this.highlightedBookTitle,
  });

  final int readingHours;
  final int readingMinutes;
  final int booksFinished;
  final int quotesSaved;
  final int currentReadingCount;
  final int activeDays;
  final double completionRate;
  final int yearlyGoalBooks;
  final List<int> yearlyActivityLevels;
  final String? highlightedBookTitle;

  factory YearStatistics.fromJson(Map<String, dynamic> json) {
    final activityJson = json['yearly_activity_levels'] as List<dynamic>? ?? [];

    return YearStatistics(
      readingHours: _toInt(json['reading_hours']),
      readingMinutes: _toInt(json['reading_minutes']),
      booksFinished: _toInt(json['books_finished']),
      quotesSaved: _toInt(json['quotes_saved']),
      currentReadingCount: _toInt(json['current_reading_count']),
      activeDays: _toInt(json['active_days']),
      completionRate: _toDouble(json['completion_rate']),
      yearlyGoalBooks: _toInt(json['yearly_goal_books']),
      yearlyActivityLevels: activityJson.map(_toInt).toList(),
      highlightedBookTitle: json['highlighted_book_title'] as String?,
    );
  }
}

class ReadingChartStatistics {
  const ReadingChartStatistics({required this.week, required this.month});

  final List<ReadingChartPoint> week;
  final List<ReadingChartPoint> month;

  factory ReadingChartStatistics.fromJson(Map<String, dynamic> json) {
    final weekJson = json['week'] as List<dynamic>? ?? [];
    final monthJson = json['month'] as List<dynamic>? ?? [];

    return ReadingChartStatistics(
      week: weekJson
          .map(
            (item) => ReadingChartPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      month: monthJson
          .map(
            (item) => ReadingChartPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ReadingChartPoint {
  const ReadingChartPoint({
    required this.label,
    required this.shortLabel,
    required this.minutes,
    required this.pagesRead,
    this.date,
  });

  final String label;
  final String shortLabel;
  final int minutes;
  final int pagesRead;
  final DateTime? date;

  factory ReadingChartPoint.fromJson(Map<String, dynamic> json) {
    return ReadingChartPoint(
      label: json['label'] as String? ?? '',
      shortLabel: json['short_label'] as String? ?? '',
      minutes: _toInt(json['minutes']),
      pagesRead: _toInt(json['pages_read']),
      date: _toDateTime(json['date']),
    );
  }
}

class DashboardGoals {
  const DashboardGoals({required this.yearlyBooks, required this.monthlyHours});

  final int yearlyBooks;
  final int monthlyHours;

  factory DashboardGoals.fromJson(Map<String, dynamic> json) {
    return DashboardGoals(
      yearlyBooks: _toInt(json['yearly_books']),
      monthlyHours: _toInt(json['monthly_hours']),
    );
  }
}

class CurrentReadingBook {
  const CurrentReadingBook({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    this.coverImageUrl,
  });

  final int id;
  final int bookId;
  final String title;
  final String author;
  final String? coverImageUrl;

  factory CurrentReadingBook.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawBookId = json['book_id'];

    return CurrentReadingBook(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      bookId: rawBookId is num
          ? rawBookId.toInt()
          : int.tryParse('$rawBookId') ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse('$value') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value') ?? 0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

class FinishedBook {
  const FinishedBook({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    this.coverImageUrl,
  });

  final int id;
  final int bookId;
  final String title;
  final String author;
  final String? coverImageUrl;

  factory FinishedBook.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawBookId = json['book_id'];

    return FinishedBook(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      bookId: rawBookId is num
          ? rawBookId.toInt()
          : int.tryParse('$rawBookId') ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}
