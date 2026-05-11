import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/achievement_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/challenge_viewmodel.dart';
import 'account_page.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'statistic_page.dart';
import 'widgets/app_bottom_bar.dart';

class ChallengePage extends StatelessWidget {
  const ChallengePage({super.key, required this.user, this.token});

  final UserModel user;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ChallengeViewModel(user: user, token: token)..loadChallenges(),
      child: _ChallengePageView(user: user, token: token),
    );
  }
}

class _ChallengePageView extends StatelessWidget {
  const _ChallengePageView({required this.user, required this.token});

  final UserModel user;
  final String? token;

  void _handleTabSelection(BuildContext context, AppTab tab) {
    switch (tab) {
      case AppTab.home:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(user: user, token: token),
          ),
        );
        break;
      case AppTab.library:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LibraryPage(user: user, token: token),
          ),
        );
        break;
      case AppTab.challenge:
        break;
      case AppTab.statistic:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StatisticPage(user: user, token: token),
          ),
        );
        break;
      case AppTab.account:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AccountPage(user: user, token: token),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Consumer<ChallengeViewModel>(
          builder: (context, challengeVM, _) {
            final nextAchievement = challengeVM.nextAchievement;
            final unlocked = challengeVM.achievements
                .where((item) => item.isUnlocked)
                .toList();
            final overview = challengeVM.overview;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: challengeVM.loadChallenges,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _ChallengeHero(
                          unlockedCount: challengeVM.unlockedCount,
                          totalCount: challengeVM.achievements.length,
                        ),
                        const SizedBox(height: 22),
                        if (challengeVM.isLoading &&
                            challengeVM.achievements.isEmpty)
                          const SizedBox(
                            height: 180,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else ...[
                          _YearReadingCard(
                            overview: overview,
                            medalCount: challengeVM.unlockedCount,
                          ),
                          const SizedBox(height: 28),
                          _ReadingHighlightsSection(overview: overview),
                          const SizedBox(height: 28),
                          if (nextAchievement != null)
                            _FeaturedChallengeCard(
                              achievement: nextAchievement,
                            ),
                          const SizedBox(height: 28),
                          const _SectionTitle(title: 'Medal Cabinet'),
                          const SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: challengeVM.achievements.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.82,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemBuilder: (context, index) {
                              return _AchievementCard(
                                achievement: challengeVM.achievements[index],
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          const _SectionTitle(title: 'Unlocked'),
                          const SizedBox(height: 14),
                          if (unlocked.isEmpty)
                            const _EmptyUnlockCard()
                          else
                            ...unlocked.map(
                              (achievement) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _UnlockedAchievementTile(
                                  achievement: achievement,
                                ),
                              ),
                            ),
                        ],
                        if (challengeVM.errorMessage != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            challengeVM.errorMessage!,
                            style: TextStyle(
                              color: AppColors.darkBrown.withValues(
                                alpha: 0.76,
                              ),
                              fontWeight: FontWeight.w700,
                              height: 1.4,
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
        currentTab: AppTab.challenge,
        onTabSelected: (tab) => _handleTabSelection(context, tab),
      ),
    );
  }
}

class _YearReadingCard extends StatelessWidget {
  const _YearReadingCard({required this.overview, required this.medalCount});

  final ChallengeOverview overview;
  final int medalCount;

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
              _MetricPill(icon: Icons.verified_rounded, label: '$medalCount'),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                              color: AppColors.darkBrown.withValues(alpha: 0.7),
                              fontSize: 12,
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
                              padding: const EdgeInsets.only(bottom: _cellGap),
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

class _ReadingHighlightsSection extends StatelessWidget {
  const _ReadingHighlightsSection({required this.overview});

  final ChallengeOverview overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Achieve'),
        const SizedBox(height: 14),
        _ReadingHighlightTile(
          icon: Icons.local_fire_department_rounded,
          tint: AppColors.secondary,
          title: overview.streakDays > 0
              ? '${overview.streakDays} days in a row'
              : 'Start your first streak',
          description: overview.streakDays > 0
              ? 'You kept your reading habit alive for ${overview.streakDays} consecutive day(s).'
              : 'Read today to begin your streak and light up the first medal run.',
        ),
        const SizedBox(height: 12),
        _ReadingHighlightTile(
          icon: Icons.emoji_events_rounded,
          tint: AppColors.primary,
          title: '${overview.booksFinished} books completed',
          description: overview.booksFinished > 0
              ? 'You have already finished ${overview.booksFinished} book(s) in ${overview.year}.'
              : 'Your first finished book of the year will show up here.',
        ),
        const SizedBox(height: 12),
        _ReadingHighlightTile(
          icon: Icons.auto_stories_rounded,
          tint: AppColors.accent,
          title: overview.currentReadingCount > 0
              ? '${overview.currentReadingCount} books in progress'
              : 'Build your active shelf',
          description: overview.currentReadingCount > 0
              ? 'You are currently reading ${overview.currentReadingCount} book(s), with ${overview.readingHours} estimated reading hour(s) logged.'
              : 'Add books to your library and your active reading shelf will appear here.',
        ),
      ],
    );
  }
}

class _ReadingHighlightTile extends StatelessWidget {
  const _ReadingHighlightTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
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
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({required this.unlockedCount, required this.totalCount});

  final int unlockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.surfaceSoft,
            AppColors.primary.withValues(alpha: 0.16),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Challenge',
            style: TextStyle(
              color: AppColors.darkBlue,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete reading milestones and collect medals for every win.',
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.76),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const _HeroBadgeOrb(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlockedCount / $totalCount medals unlocked',
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: totalCount == 0 ? 0 : unlockedCount / totalCount,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.10,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadgeOrb extends StatelessWidget {
  const _HeroBadgeOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        color: Colors.white,
        size: 42,
      ),
    );
  }
}

class _FeaturedChallengeCard extends StatelessWidget {
  const _FeaturedChallengeCard({required this.achievement});

  final AchievementModel achievement;

  @override
  Widget build(BuildContext context) {
    final tint = _tintForAchievement(
      achievement.targetType,
      achievement.isUnlocked,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _MedalIconBadge(achievement: achievement, size: 70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next to unlock',
                  style: TextStyle(
                    color: AppColors.darkBrown.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.name,
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: AppColors.darkBrown.withValues(alpha: 0.76),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: achievement.progress,
                    backgroundColor: tint.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(tint),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${achievement.progressValue}/${achievement.targetValue} ${_targetLabel(achievement.targetType)}',
                  style: TextStyle(color: tint, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.darkBlue,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final AchievementModel achievement;

  @override
  Widget build(BuildContext context) {
    final tint = _tintForAchievement(
      achievement.targetType,
      achievement.isUnlocked,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MedalIconBadge(achievement: achievement, size: 58),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: achievement.isUnlocked
                      ? AppColors.accent.withValues(alpha: 0.10)
                      : AppColors.darkBrown.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  achievement.isUnlocked ? 'Unlocked' : 'In progress',
                  style: TextStyle(
                    color: achievement.isUnlocked
                        ? AppColors.accent
                        : AppColors.darkBrown,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            achievement.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.76),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: achievement.progress,
              backgroundColor: tint.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${achievement.progressValue}/${achievement.targetValue} ${_targetLabel(achievement.targetType)}',
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalIconBadge extends StatelessWidget {
  const _MedalIconBadge({required this.achievement, required this.size});

  final AchievementModel achievement;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = _tintForAchievement(
      achievement.targetType,
      achievement.isUnlocked,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: achievement.isUnlocked
              ? [tint.withValues(alpha: 0.95), AppColors.darkBlue]
              : [Colors.grey.shade300, Colors.grey.shade500],
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: achievement.isUnlocked ? 0.18 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        iconForAchievement(achievement.iconUrl, achievement.targetType),
        color: Colors.white,
        size: size * 0.44,
      ),
    );
  }
}

class _UnlockedAchievementTile extends StatelessWidget {
  const _UnlockedAchievementTile({required this.achievement});

  final AchievementModel achievement;

  @override
  Widget build(BuildContext context) {
    final tint = _tintForAchievement(achievement.targetType, true);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tint.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          _MedalIconBadge(achievement: achievement, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.achievedAt == null
                      ? 'Unlocked'
                      : 'Unlocked on ${_formatDate(achievement.achievedAt!)}',
                  style: TextStyle(
                    color: AppColors.darkBrown.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: tint),
        ],
      ),
    );
  }
}

class _EmptyUnlockCard extends StatelessWidget {
  const _EmptyUnlockCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No medals unlocked yet. Finish your first challenge to start your collection.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.darkBrown.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

Color _tintForAchievement(String targetType, bool isUnlocked) {
  if (!isUnlocked) {
    return AppColors.darkBrown;
  }

  switch (targetType) {
    case 'reading_hours':
      return AppColors.accent;
    case 'books_finished':
      return AppColors.primary;
    case 'streak_days':
      return AppColors.secondary;
    case 'quotes_saved':
      return AppColors.darkBlue;
    default:
      return AppColors.primary;
  }
}

String _targetLabel(String targetType) {
  switch (targetType) {
    case 'reading_hours':
      return 'hours';
    case 'books_finished':
      return 'books';
    case 'streak_days':
      return 'days';
    case 'quotes_saved':
      return 'quotes';
    default:
      return 'progress';
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

Map<String, int> _buildMonthOffsets(int year) {
  const monthLabels = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];
  final offsets = <String, int>{};

  for (var month = 1; month <= 12; month++) {
    final firstDay = DateTime(year, month, 1);
    final weekIndex =
        ((firstDay.difference(DateTime(year, 1, 1)).inDays) +
            DateTime(year, 1, 1).weekday -
            1) ~/
        7;
    offsets[monthLabels[month - 1]] = weekIndex;
  }

  return offsets;
}

List<List<int>> _buildActivityColumns(ChallengeOverview overview) {
  final columns = List.generate(53, (_) => List<int>.filled(7, 0));
  final start = DateTime(overview.year, 1, 1);

  for (var index = 0; index < overview.yearlyActivityLevels.length; index++) {
    final date = start.add(Duration(days: index));
    final column = ((index + start.weekday - 1) ~/ 7).clamp(0, 52);
    final row = date.weekday - 1;
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
