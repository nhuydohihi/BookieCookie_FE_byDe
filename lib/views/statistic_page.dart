import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/home_dashboard_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/home_viewmodel.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'widgets/app_bottom_bar.dart';

class StatisticPage extends StatelessWidget {
  const StatisticPage({super.key, required this.user, this.token});

  final UserModel user;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(user: user, token: token)..loadDashboard(),
      child: _StatisticPageView(user: user, token: token),
    );
  }
}

class _StatisticPageView extends StatefulWidget {
  const _StatisticPageView({required this.user, required this.token});

  final UserModel user;
  final String? token;

  @override
  State<_StatisticPageView> createState() => _StatisticPageViewState();
}

class _StatisticPageViewState extends State<_StatisticPageView> {
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = DateTime.now().weekday - 1;
  }

  void _handleTabSelection(BuildContext context, AppTab tab) {
    switch (tab) {
      case AppTab.home:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(user: widget.user, token: widget.token),
          ),
        );
        break;
      case AppTab.library:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LibraryPage(user: widget.user, token: widget.token),
          ),
        );
        break;
      case AppTab.statistic:
        break;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tab.label} is coming soon.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Consumer<HomeViewModel>(
          builder: (context, homeVM, _) {
            final dashboard = homeVM.dashboard;
            final weekStats = _buildWeekStats(dashboard);
            final selectedStat = weekStats[_selectedDayIndex];
            final minuteGoal = _buildTodayGoal(dashboard);
            final yearlyGoal = _buildYearlyGoal(dashboard);
            final achievements = _buildAchievements(dashboard);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: homeVM.loadDashboard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const _StatisticHeader(),
                        const SizedBox(height: 20),
                        _TodayGoalCard(
                          minutes: minuteGoal.minutes,
                          progress: minuteGoal.progress,
                          streakDays: dashboard?.streakDays ?? 0,
                          isLoading: homeVM.isLoading,
                        ),
                        const SizedBox(height: 20),
                        _WeekStrip(
                          stats: weekStats,
                          selectedIndex: _selectedDayIndex,
                          onSelected: (index) {
                            setState(() {
                              _selectedDayIndex = index;
                            });
                          },
                        ),
                        const SizedBox(height: 28),
                        _YearlyOverviewCard(
                          year: dashboard?.year ?? DateTime.now().year,
                          finishedCount: dashboard?.finishedInYear.length ?? 0,
                          yearlyGoal: yearlyGoal,
                          currentReadingCount:
                              dashboard?.currentReading.length ?? 0,
                          highlightedBook:
                              dashboard?.finishedInYear.isNotEmpty == true
                              ? dashboard!.finishedInYear.first
                              : null,
                        ),
                        const SizedBox(height: 28),
                        _AchievementSection(achievements: achievements),
                        if (homeVM.errorMessage != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            homeVM.errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (!homeVM.isLoading) ...[
                          const SizedBox(height: 18),
                          Text(
                            'Selected day: ${selectedStat.label} • ${selectedStat.minutes} min',
                            style: TextStyle(
                              color: AppColors.darkBrown.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        currentTab: AppTab.statistic,
        onTabSelected: (tab) => _handleTabSelection(context, tab),
      ),
    );
  }
}

class _StatisticHeader extends StatelessWidget {
  const _StatisticHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Track your daily reading rhythm and yearly wins.',
          style: TextStyle(
            color: AppColors.darkBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TodayGoalCard extends StatelessWidget {
  const _TodayGoalCard({
    required this.minutes,
    required this.progress,
    required this.streakDays,
    required this.isLoading,
  });

  final int minutes;
  final double progress;
  final int streakDays;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 208,
            height: 208,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(208),
                  painter: _ArcProgressPainter(progress: progress),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      )
                    else ...[
                      Text(
                        '$minutes',
                        style: const TextStyle(
                          color: AppColors.darkBlue,
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'minutes',
                        style: TextStyle(
                          color: AppColors.darkBrown.withValues(alpha: 0.78),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Today',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    streakDays == 0
                        ? 'Read a little today to start your streak.'
                        : 'You are on a $streakDays-day reading streak.',
                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.stats,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_DayStat> stats;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This week',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: List.generate(stats.length, (index) {
              final item = stats[index];
              final isSelected = index == selectedIndex;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => onSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 1.2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              item.shortLabel,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.darkBrown.withValues(
                                        alpha: 0.72,
                                      ),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.cream,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${item.minutes}',
                                style: const TextStyle(
                                  color: AppColors.darkBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _YearlyOverviewCard extends StatelessWidget {
  const _YearlyOverviewCard({
    required this.year,
    required this.finishedCount,
    required this.yearlyGoal,
    required this.currentReadingCount,
    required this.highlightedBook,
  });

  final int year;
  final int finishedCount;
  final int yearlyGoal;
  final int currentReadingCount;
  final FinishedBook? highlightedBook;

  @override
  Widget build(BuildContext context) {
    final progress = yearlyGoal == 0 ? 0.0 : finishedCount / yearlyGoal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My yearly goal',
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(128),
                      painter: _ArcProgressPainter(
                        progress: progress.clamp(0, 1),
                        strokeWidth: 12,
                        baseColor: AppColors.secondary.withValues(alpha: 0.12),
                        progressColor: AppColors.secondary,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$finishedCount',
                          style: const TextStyle(
                            color: AppColors.darkBlue,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'books',
                          style: TextStyle(
                            color: AppColors.darkBrown.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$year',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniStatLine(
                      icon: Icons.flag_rounded,
                      label: 'Goal',
                      value: '$yearlyGoal books',
                    ),
                    const SizedBox(height: 10),
                    _MiniStatLine(
                      icon: Icons.check_circle_rounded,
                      label: 'Done',
                      value: '$finishedCount finished',
                    ),
                    const SizedBox(height: 10),
                    _MiniStatLine(
                      icon: Icons.menu_book_rounded,
                      label: 'Reading now',
                      value: '$currentReadingCount books',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (highlightedBook != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest finished',
                          style: TextStyle(
                            color: AppColors.darkBrown,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          highlightedBook!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.darkBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStatLine extends StatelessWidget {
  const _MiniStatLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: AppColors.darkBrown.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementSection extends StatelessWidget {
  const _AchievementSection({required this.achievements});

  final List<_AchievementItem> achievements;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achieve',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ...achievements.map(
          (achievement) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: achievement.tint.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: achievement.tint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(achievement.icon, color: achievement.tint),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title,
                          style: const TextStyle(
                            color: AppColors.darkBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          achievement.description,
                          style: TextStyle(
                            color: AppColors.darkBrown.withValues(alpha: 0.76),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcProgressPainter extends CustomPainter {
  _ArcProgressPainter({
    required this.progress,
    this.strokeWidth = 14,
    this.baseColor,
    this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color? baseColor;
  final Color? progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final startAngle = math.pi * 0.80;
    final sweepAngle = math.pi * 1.6;

    final basePaint = Paint()
      ..color = baseColor ?? AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor ?? AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      rect.deflate(strokeWidth),
      startAngle,
      sweepAngle,
      false,
      basePaint,
    );
    canvas.drawArc(
      rect.deflate(strokeWidth),
      startAngle,
      sweepAngle * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _TodayGoalData {
  const _TodayGoalData({required this.minutes, required this.progress});

  final int minutes;
  final double progress;
}

class _DayStat {
  const _DayStat({
    required this.label,
    required this.shortLabel,
    required this.minutes,
  });

  final String label;
  final String shortLabel;
  final int minutes;
}

class _AchievementItem {
  const _AchievementItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color tint;
}

_TodayGoalData _buildTodayGoal(HomeDashboardModel? dashboard) {
  final currentReadingCount = dashboard?.currentReading.length ?? 0;
  final activityCount = dashboard?.activityCount ?? 0;
  final minutes = math.min(120, currentReadingCount * 8 + activityCount * 2);
  final normalizedMinutes = minutes == 0 && currentReadingCount > 0
      ? 10
      : minutes;

  return _TodayGoalData(
    minutes: normalizedMinutes,
    progress: (normalizedMinutes / 30).clamp(0, 1),
  );
}

List<_DayStat> _buildWeekStats(HomeDashboardModel? dashboard) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final streakDays = dashboard?.streakDays ?? 0;
  final activityCount = dashboard?.activityCount ?? 0;
  final currentReadingCount = dashboard?.currentReading.length ?? 0;
  final base = currentReadingCount * 4 + activityCount;
  final todayIndex = DateTime.now().weekday - 1;

  return List.generate(labels.length, (index) {
    final distance = (todayIndex - index).abs();
    final minutes = math.max(
      0,
      base + (streakDays > 0 ? 6 - distance * 2 : 0) + (index.isEven ? 2 : -1),
    );

    return _DayStat(
      label: labels[index],
      shortLabel: labels[index].substring(0, 2),
      minutes: minutes,
    );
  });
}

int _buildYearlyGoal(HomeDashboardModel? dashboard) {
  final finishedCount = dashboard?.finishedInYear.length ?? 0;
  return math.max(6, math.max(finishedCount + 3, 12));
}

List<_AchievementItem> _buildAchievements(HomeDashboardModel? dashboard) {
  final streakDays = dashboard?.streakDays ?? 0;
  final finishedCount = dashboard?.finishedInYear.length ?? 0;
  final currentReadingCount = dashboard?.currentReading.length ?? 0;

  return [
    _AchievementItem(
      title: streakDays > 0
          ? '$streakDays days in a row'
          : 'First streak starts now',
      description: streakDays > 0
          ? 'You kept your reading habit alive for $streakDays consecutive day(s).'
          : 'Open a book today and turn your first session into a streak.',
      icon: Icons.local_fire_department_rounded,
      tint: AppColors.secondary,
    ),
    _AchievementItem(
      title: '$finishedCount books completed',
      description: finishedCount > 0
          ? 'Nice work finishing $finishedCount book(s) this year.'
          : 'Your first finished book of the year is waiting for you.',
      icon: Icons.emoji_events_rounded,
      tint: AppColors.primary,
    ),
    _AchievementItem(
      title: currentReadingCount > 0
          ? '$currentReadingCount active reading slot(s)'
          : 'Build your reading shelf',
      description: currentReadingCount > 0
          ? 'You currently have $currentReadingCount book(s) in progress.'
          : 'Add books to your library to unlock richer reading statistics.',
      icon: Icons.auto_stories_rounded,
      tint: AppColors.darkBlue,
    ),
  ];
}
