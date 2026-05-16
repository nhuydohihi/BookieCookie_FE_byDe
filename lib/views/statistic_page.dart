import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../data/models/achievement_model.dart';
import '../data/models/home_dashboard_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/home_viewmodel.dart';
import 'account_page.dart';
import 'challenge_page.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'widgets/app_bottom_bar.dart';

class StatisticPage extends StatelessWidget {
  const StatisticPage({super.key, required this.user, this.token});

  final UserModel user;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return ChangeNotifierProvider(
      create: (_) =>
          HomeViewModel(user: user, token: token)
            ..loadDashboard(year: currentYear),
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
  late int _selectedYear;
  _ChartRange _selectedChartRange = _ChartRange.week;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = DateTime.now().weekday - 1;
    _selectedYear = DateTime.now().year;
  }

  Future<void> _changeYear(int year) async {
    if (_selectedYear == year) {
      return;
    }

    setState(() {
      _selectedYear = year;
    });

    await context.read<HomeViewModel>().loadDashboard(year: year);
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
      case AppTab.challenge:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChallengePage(user: widget.user, token: widget.token),
          ),
        );
        break;
      case AppTab.statistic:
        break;
      case AppTab.account:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AccountPage(user: widget.user, token: widget.token),
          ),
        );
        break;
    }
  }

  Future<void> _editYearlyGoal({
    required int initialGoal,
    required int year,
  }) async {
    final homeViewModel = context.read<HomeViewModel>();
    final controller = TextEditingController(
      text: initialGoal > 0 ? '$initialGoal' : '',
    );
    String? errorText;

    final updatedGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit yearly goal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set how many books you want to finish in $year.',
                    style: TextStyle(
                      color: AppColors.darkBrown.withValues(alpha: 0.74),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Books target',
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed == null || parsed <= 0) {
                      setDialogState(() {
                        errorText =
                            'Please enter a valid number greater than 0.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      if (updatedGoal == null || !mounted) {
        return;
      }

      await homeViewModel.updateYearlyGoal(updatedGoal, year: year);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Yearly goal updated.')),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not update yearly goal: $error')),
      );
    } finally {
      controller.dispose();
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
            final dashboardYear = dashboard?.year ?? _selectedYear;
            if (dashboardYear != _selectedYear) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _selectedYear = dashboardYear;
                });
              });
            }
            final weekStats = _buildWeekStats(dashboard);
            final selectedStat = weekStats[_selectedDayIndex];
            final minuteGoal = _buildTodayGoal(dashboard);
            final yearlyGoal = _buildYearlyGoal(dashboard);
            final overview = _buildChallengeOverview(dashboard);
            final chartData = _buildChartData(dashboard, _selectedChartRange);
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => homeVM.loadDashboard(year: _selectedYear),
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
                        _StreakSummaryRow(
                          currentStreak: dashboard?.streakDays ?? 0,
                          maxStreak: dashboard?.maxStreakDays ?? 0,
                        ),
                        const SizedBox(height: 20),
                        _WeekStrip(
                          stats: weekStats,
                          selectedIndex: _selectedDayIndex,
                        ),
                        const SizedBox(height: 28),
                        _ReadingTimeChartCard(
                          year: dashboardYear,
                          chartData: chartData,
                          selectedRange: _selectedChartRange,
                          onRangeChanged: (range) {
                            setState(() {
                              _selectedChartRange = range;
                            });
                          },
                          onPreviousYear: () => _changeYear(dashboardYear - 1),
                          onNextYear: dashboardYear < DateTime.now().year
                              ? () => _changeYear(dashboardYear + 1)
                              : null,
                        ),
                        const SizedBox(height: 28),
                        _YearReadingCard(overview: overview),
                        const SizedBox(height: 28),
                        _YearlyOverviewCard(
                          year: dashboardYear,
                          finishedCount:
                              dashboard?.statistics?.year.booksFinished ?? 0,
                          yearlyGoal: yearlyGoal,
                          currentReadingCount:
                              dashboard?.currentReading.length ?? 0,
                          onEditGoal: () => _editYearlyGoal(
                            initialGoal: yearlyGoal,
                            year: dashboardYear,
                          ),
                          highlightedBook:
                              dashboard?.finishedInYear.isNotEmpty == true
                              ? dashboard!.finishedInYear.first
                              : null,
                        ),
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

class _YearReadingCard extends StatelessWidget {
  const _YearReadingCard({required this.overview});

  final ChallengeOverview overview;

  static const double _cellSize = 14;
  static const double _cellGap = 5;
  static const double _columnWidth = _cellSize + _cellGap;

  @override
  Widget build(BuildContext context) {
    final monthOffsets = _buildMonthOffsets(overview.year);
    final activityColumns = _buildActivityColumns(overview);
    final gridWidth = activityColumns.length * _columnWidth;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('📖', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reading',
                  style: TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MetricPill(
                icon: Icons.av_timer_rounded,
                label: '${(overview.completionRate * 100).round()}%',
              ),
              const SizedBox(width: 10),
              _MetricPill(
                icon: Icons.verified_rounded,
                label: '${overview.activeDays}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: gridWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          child: Stack(
                            children: monthOffsets.entries.map((entry) {
                              return Positioned(
                                left: entry.value * _columnWidth,
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: AppColors.darkBrown.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: activityColumns.map((column) {
                            return Padding(
                              padding: const EdgeInsets.only(right: _cellGap),
                              child: Column(
                                children: List.generate(column.length, (index) {
                                  final level = column[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: _cellGap,
                                    ),
                                    child: Container(
                                      width: _cellSize,
                                      height: _cellSize,
                                      decoration: BoxDecoration(
                                        color: _heatmapColor(level),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.darkBrown),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.darkBrown,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    final hasReadToday = minutes > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
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
                  painter: _ArcProgressPainter(
                    progress: progress,
                    progressColor: hasReadToday
                        ? AppColors.secondary
                        : AppColors.primary,
                  ),
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
                      const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

class _StreakSummaryRow extends StatelessWidget {
  const _StreakSummaryRow({
    required this.currentStreak,
    required this.maxStreak,
  });

  final int currentStreak;
  final int maxStreak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StreakStatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF5A5F),
            iconBackground: const Color(0xFFFFECEC),
            value: currentStreak,
            label: 'Current streak',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StreakStatCard(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFA000),
            iconBackground: const Color(0xFFFFF4DD),
            value: maxStreak,
            label: 'Max streak',
          ),
        ),
      ],
    );
  }
}

class _StreakStatCard extends StatelessWidget {
  const _StreakStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 40,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.56),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingTimeChartCard extends StatelessWidget {
  const _ReadingTimeChartCard({
    required this.year,
    required this.chartData,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onPreviousYear,
    required this.onNextYear,
  });

  final int year;
  final _ChartData chartData;
  final _ChartRange selectedRange;
  final ValueChanged<_ChartRange> onRangeChanged;
  final VoidCallback onPreviousYear;
  final VoidCallback? onNextYear;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = chartData.points.fold<int>(
      0,
      (sum, point) => sum + point.minutes,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 320;
              final title = const Text(
                'Reading time',
                style: TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              );
              final yearStepper = _YearStepper(
                year: year,
                onPrevious: onPreviousYear,
                onNext: onNextYear,
                compact: isCompact,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), yearStepper],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  yearStepper,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 320;
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalMinutes',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    selectedRange == _ChartRange.week
                        ? 'mins this week'
                        : 'mins this month',
                    style: TextStyle(
                      color: AppColors.darkBrown.withValues(alpha: 0.68),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final rangeSwitch = _ChartRangeSwitch(
                selectedRange: selectedRange,
                onChanged: onRangeChanged,
                compact: isCompact,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [summary, const SizedBox(height: 14), rangeSwitch],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [summary, const Spacer(), rangeSwitch],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(height: 220, child: _LineChart(points: chartData.points)),
        ],
      ),
    );
  }
}

class _YearStepper extends StatelessWidget {
  const _YearStepper({
    required this.year,
    required this.onPrevious,
    required this.onNext,
    this.compact = false,
  });

  final int year;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _YearArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
            compact: compact,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
            child: Text(
              '$year',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 15 : null,
              ),
            ),
          ),
          _YearArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _YearArrowButton extends StatelessWidget {
  const _YearArrowButton({
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 2 : 4),
          child: Icon(
            icon,
            size: compact ? 16 : 18,
            color: isEnabled
                ? AppColors.darkBrown
                : AppColors.darkBrown.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}

class _ChartRangeSwitch extends StatelessWidget {
  const _ChartRangeSwitch({
    required this.selectedRange,
    required this.onChanged,
    this.compact = false,
  });

  final _ChartRange selectedRange;
  final ValueChanged<_ChartRange> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chipWidth = compact ? 50.0 : 58.0;

    return Container(
      padding: EdgeInsets.all(compact ? 2 : 3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChartRangeChip(
            label: 'Week',
            isSelected: selectedRange == _ChartRange.week,
            onTap: () => onChanged(_ChartRange.week),
            compact: compact,
            width: chipWidth,
          ),
          _ChartRangeChip(
            label: 'Month',
            isSelected: selectedRange == _ChartRange.month,
            onTap: () => onChanged(_ChartRange.month),
            compact: compact,
            width: chipWidth,
          ),
        ],
      ),
    );
  }
}

class _ChartRangeChip extends StatelessWidget {
  const _ChartRangeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.width,
    this.compact = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 13 : 14,
          ),
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});

  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No reading data yet.',
          style: TextStyle(
            color: AppColors.darkBrown.withValues(alpha: 0.68),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final contentWidth = math.max(320.0, points.length * 28.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: contentWidth,
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                size: Size(contentWidth, 180),
                painter: _LineChartPainter(points: points),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: points
                  .map(
                    (point) => Expanded(
                      child: Text(
                        point.shortLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.darkBrown.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.stats, required this.selectedIndex});

  final List<_DayStat> stats;
  final int selectedIndex;

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
              final hasRead = item.minutes > 0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
                                : AppColors.darkBrown.withValues(alpha: 0.72),
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
                                : hasRead
                                ? AppColors.secondary.withValues(alpha: 0.18)
                                : AppColors.cream,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${item.dayOfMonth}',
                            style: TextStyle(
                              color: hasRead && !isSelected
                                  ? AppColors.secondary
                                  : AppColors.darkBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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
    required this.onEditGoal,
    required this.highlightedBook,
  });

  final int year;
  final int finishedCount;
  final int yearlyGoal;
  final int currentReadingCount;
  final VoidCallback onEditGoal;
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My yearly goal',
                  style: TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                height: 34,
                child: Material(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onEditGoal,
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: AppColors.darkBrown,
                    ),
                  ),
                ),
              ),
            ],
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

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points});

  final List<_ChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(14, 10, 14, 18);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;
    final maxMinutes = math.max(
      20,
      points.fold<int>(
        0,
        (maxValue, point) => math.max(maxValue, point.minutes),
      ),
    );

    final guidePaint = Paint()
      ..color = AppColors.darkBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    for (var step = 0; step < 4; step++) {
      final y = padding.top + (chartHeight * step / 3);
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        guidePaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    final spots = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      final dx = points.length == 1
          ? padding.left + (chartWidth / 2)
          : padding.left + (chartWidth * index / (points.length - 1));
      final dy =
          padding.top +
          chartHeight -
          (points[index].minutes / maxMinutes) * chartHeight;
      final spot = Offset(dx, dy);
      spots.add(spot);

      if (index == 0) {
        path.moveTo(dx, dy);
        fillPath
          ..moveTo(dx, padding.top + chartHeight)
          ..lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }

    if (spots.isNotEmpty) {
      fillPath
        ..lineTo(spots.last.dx, padding.top + chartHeight)
        ..close();
    }

    final fillPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.20),
              AppColors.primary.withValues(alpha: 0.02),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(padding.left, padding.top, chartWidth, chartHeight),
          );

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final pointFillPaint = Paint()..color = Colors.white;
    final pointStrokePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final spot in spots) {
      canvas.drawCircle(spot, 4, pointFillPaint);
      canvas.drawCircle(spot, 4, pointStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
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
    required this.dayOfMonth,
    required this.minutes,
  });

  final String label;
  final String shortLabel;
  final int dayOfMonth;
  final int minutes;
}

enum _ChartRange { week, month }

class _ChartPoint {
  const _ChartPoint({
    required this.label,
    required this.shortLabel,
    required this.minutes,
  });

  final String label;
  final String shortLabel;
  final int minutes;
}

class _ChartData {
  const _ChartData({required this.points});

  final List<_ChartPoint> points;
}

_TodayGoalData _buildTodayGoal(HomeDashboardModel? dashboard) {
  final todayStats = dashboard?.statistics?.today;
  final minutes = todayStats?.minutes ?? 0;
  final progress =
      todayStats?.goalMinutes == null || todayStats!.goalMinutes <= 0
      ? 0.0
      : todayStats.progress.clamp(0, 1).toDouble();

  return _TodayGoalData(minutes: minutes, progress: progress);
}

List<_DayStat> _buildWeekStats(HomeDashboardModel? dashboard) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekStats = dashboard?.statistics?.week ?? const <WeekdayStatistics>[];

  if (weekStats.isNotEmpty) {
    return weekStats
        .map(
          (item) => _DayStat(
            label: item.label,
            shortLabel: item.shortLabel,
            dayOfMonth: item.date?.day ?? 0,
            minutes: item.minutes,
          ),
        )
        .toList();
  }

  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

  return labels
      .asMap()
      .entries
      .map(
        (entry) => _DayStat(
          label: entry.value,
          shortLabel: entry.value.substring(0, 2),
          dayOfMonth: startOfWeek.add(Duration(days: entry.key)).day,
          minutes: 0,
        ),
      )
      .toList();
}

_ChartData _buildChartData(HomeDashboardModel? dashboard, _ChartRange range) {
  final chart = dashboard?.statistics?.chart;
  final source = switch (range) {
    _ChartRange.week => chart?.week ?? const <ReadingChartPoint>[],
    _ChartRange.month => chart?.month ?? const <ReadingChartPoint>[],
  };

  return _ChartData(
    points: source
        .map(
          (item) => _ChartPoint(
            label: item.label,
            shortLabel: item.shortLabel,
            minutes: item.minutes,
          ),
        )
        .toList(),
  );
}

int _buildYearlyGoal(HomeDashboardModel? dashboard) {
  final goal =
      dashboard?.statistics?.year.yearlyGoalBooks ??
      dashboard?.goals?.yearlyBooks ??
      0;
  return goal;
}

ChallengeOverview _buildChallengeOverview(HomeDashboardModel? dashboard) {
  final now = DateTime.now();
  final year = dashboard?.year ?? now.year;
  final fallback = ChallengeOverview.empty();

  if (dashboard == null) {
    return fallback;
  }
  final yearStats = dashboard.statistics?.year;
  if (yearStats == null) {
    return fallback;
  }

  return ChallengeOverview(
    year: year,
    readingHours: yearStats.readingHours,
    booksFinished: yearStats.booksFinished,
    streakDays: dashboard.streakDays,
    quotesSaved: yearStats.quotesSaved,
    currentReadingCount: yearStats.currentReadingCount,
    activeDays: yearStats.activeDays,
    completionRate: yearStats.completionRate,
    highlightedBookTitle: yearStats.highlightedBookTitle,
    yearlyActivityLevels: yearStats.yearlyActivityLevels,
  );
}

Map<String, int> _buildMonthOffsets(int year) {
  const monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final offsets = <String, int>{};

  for (var month = 1; month <= 12; month++) {
    final firstDay = DateTime(year, month, 1);
    final weekIndex =
        ((firstDay.difference(DateTime(year, 1, 1)).inDays) +
            DateTime(year, 1, 1).weekday -
            1) ~/
        7;
    offsets[monthLabels[month - 1]] = weekIndex ~/ 2;
  }

  return offsets;
}

List<List<int>> _buildActivityColumns(ChallengeOverview overview) {
  final columns = List.generate(27, (_) => List<int>.filled(14, 0));
  final start = DateTime(overview.year, 1, 1);

  for (var index = 0; index < overview.yearlyActivityLevels.length; index++) {
    final date = start.add(Duration(days: index));
    final weekIndex = ((index + start.weekday - 1) ~/ 7);
    final column = (weekIndex ~/ 2).clamp(0, 26);
    final row = date.weekday - 1 + ((weekIndex % 2) * 7);
    columns[column][row] = overview.yearlyActivityLevels[index];
  }

  return columns;
}

Color _heatmapColor(int level) {
  switch (level) {
    case 4:
      return const Color(0xFF1473E6);
    case 3:
      return const Color(0xFF1E88FF);
    case 2:
      return const Color(0xFF53A8FF);
    case 1:
      return const Color(0xFFA5D0FF);
    default:
      return const Color(0xFFF1F3F7);
  }
}
