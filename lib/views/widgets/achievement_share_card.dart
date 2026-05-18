import 'package:flutter/material.dart';

import '../../data/models/achievement_model.dart';

class AchievementShareCard extends StatelessWidget {
  const AchievementShareCard({super.key, required this.achievement});

  final AchievementModel achievement;

  @override
  Widget build(BuildContext context) {
    final unlockedDate = achievement.achievedAt == null
        ? 'Unlocked today'
        : 'Unlocked on ${_formatDate(achievement.achievedAt!)}';
    final milestoneValue = achievement.targetValue.toString();
    final milestoneLabel = _milestoneLabel(achievement.targetType);

    return AspectRatio(
      aspectRatio: 4 / 7.4,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 360,
          height: 666,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF171B3A),
                    Color(0xFF232B59),
                    Color(0xFF31245A),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    top: -40,
                    left: -10,
                    child: _SoftGlow(size: 150, color: Color(0x33FFFFFF)),
                  ),
                  const Positioned(
                    top: 80,
                    right: -30,
                    child: _SoftGlow(size: 180, color: Color(0x22A98BFF)),
                  ),
                  const Positioned(
                    bottom: 90,
                    left: -35,
                    child: _SoftGlow(size: 170, color: Color(0x22FF8EC5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            'READER ACHIEVEMENT',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _AchievementBadgeSeal(),
                        const SizedBox(height: 26),
                        Text(
                          'Achievement Completed',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: milestoneValue,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  height: 0.95,
                                ),
                              ),
                              TextSpan(
                                text: ' $milestoneLabel',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          achievement.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _InfoColumn(
                                  label: 'Milestone',
                                  value:
                                      '${achievement.targetValue} ${_targetLabel(achievement.targetType)}',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              Expanded(
                                child: _InfoColumn(
                                  label: 'Status',
                                  value: unlockedDate,
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '#BookieCookie',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
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
      ),
    );
  }
}

class _AchievementBadgeSeal extends StatelessWidget {
  const _AchievementBadgeSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Image.asset('assets/images/badge.png', fit: BoxFit.contain),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

String _milestoneLabel(String targetType) {
  switch (targetType) {
    case 'reading_hours':
      return 'Hours';
    case 'books_finished':
      return 'Books';
    case 'streak_days':
      return 'Days';
    case 'quotes_saved':
      return 'Quotes';
    default:
      return 'Points';
  }
}

String _targetLabel(String targetType) {
  switch (targetType) {
    case 'reading_hours':
      return 'hours';
    case 'books_finished':
      return 'books';
    case 'streak_days':
      return 'days streak';
    case 'quotes_saved':
      return 'quotes';
    default:
      return 'points';
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}
