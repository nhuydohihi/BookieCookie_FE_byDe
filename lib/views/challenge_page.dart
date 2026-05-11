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
