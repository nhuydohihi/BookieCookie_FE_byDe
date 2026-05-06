import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({
    super.key,
    this.title,
    this.author,
    this.coverImageUrl,
    this.initialNote,
    this.initialMinutes = 25,
  });

  final String? title;
  final String? author;
  final String? coverImageUrl;
  final String? initialNote;
  final int initialMinutes;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  static const int _minuteStep = 5;
  static const int _maxMinutes = 120;
  static const int _minMinutes = 5;

  late final TextEditingController _noteController;
  late int _selectedMinutes;
  bool _isReading = false;
  double? _lastDragAngle;

  int get _totalSteps => _maxMinutes ~/ _minuteStep;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes.clamp(_minMinutes, _maxMinutes);
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggleReading() {
    setState(() {
      _isReading = !_isReading;
    });
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    _lastDragAngle = _angleForOffset(details.localPosition, size);
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final currentAngle = _angleForOffset(details.localPosition, size);
    final previousAngle = _lastDragAngle;
    if (previousAngle == null) {
      _lastDragAngle = currentAngle;
      return;
    }

    var delta = currentAngle - previousAngle;
    if (delta > math.pi) {
      delta -= math.pi * 2;
    } else if (delta < -math.pi) {
      delta += math.pi * 2;
    }

    final currentSteps = (_selectedMinutes / _minuteStep).round();
    final nextSteps = (currentSteps + (delta / _anglePerStep).round()).clamp(
      _minMinutes ~/ _minuteStep,
      _totalSteps,
    );

    if (nextSteps != currentSteps) {
      setState(() {
        _selectedMinutes = nextSteps * _minuteStep;
      });
    }

    _lastDragAngle = currentAngle;
  }

  void _handlePanEnd(DragEndDetails details) {
    _lastDragAngle = null;
  }

  double get _anglePerStep => (math.pi * 2) / _totalSteps;

  double _angleForOffset(Offset offset, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final vector = offset - center;
    return math.atan2(vector.dy, vector.dx) + math.pi / 2;
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : 'Reading';
    final displayAuthor = widget.author?.trim().isNotEmpty == true
        ? widget.author!.trim()
        : 'Focus session';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TopActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Reading',
                    style: TextStyle(
                      color: AppColors.darkBlue.withValues(alpha: 0.92),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 50),
                ],
              ),
              const SizedBox(height: 24),
              _ReadingBookHeader(
                title: displayTitle,
                author: displayAuthor,
                coverImageUrl: widget.coverImageUrl,
              ),
              const SizedBox(height: 28),
              Center(
                child: _ReadingDial(
                  minutes: _selectedMinutes,
                  maxMinutes: _maxMinutes,
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleReading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isReading ? 'Reading in progress' : 'Start reading',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
              const SizedBox(height: 24),
              _InfoCard(
                title: 'Thời gian đọc hôm nay',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_selectedMinutes phút',
                        style: const TextStyle(
                          color: AppColors.darkBlue,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Mỗi nấc +5 phút',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _InfoCard(
                title: 'Ghi chú',
                child: TextField(
                  controller: _noteController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Viết ghi chú cho phiên đọc này...',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    color: AppColors.darkBrown.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingBookHeader extends StatelessWidget {
  const _ReadingBookHeader({
    required this.title,
    required this.author,
    required this.coverImageUrl,
  });

  final String title;
  final String author;
  final String? coverImageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: coverImageUrl != null && coverImageUrl!.isNotEmpty
                ? Image.network(
                    coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _CoverPlaceholder(),
                  )
                : const _CoverPlaceholder(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                author,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.darkBrown.withValues(alpha: 0.74),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadingDial extends StatelessWidget {
  const _ReadingDial({
    required this.minutes,
    required this.maxMinutes,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final int minutes;
  final int maxMinutes;
  final void Function(DragStartDetails details, Size size) onPanStart;
  final void Function(DragUpdateDetails details, Size size) onPanUpdate;
  final void Function(DragEndDetails details) onPanEnd;

  @override
  Widget build(BuildContext context) {
    const size = 230.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dialSize = Size.square(size);

        return GestureDetector(
          onPanStart: (details) => onPanStart(details, dialSize),
          onPanUpdate: (details) => onPanUpdate(details, dialSize),
          onPanEnd: onPanEnd,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _DialPainter(
                minutes: minutes,
                maxMinutes: maxMinutes,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$minutes',
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'phút',
                      style: TextStyle(
                        color: AppColors.darkBrown.withValues(alpha: 0.72),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.minutes,
    required this.maxMinutes,
  });

  final int minutes;
  final int maxMinutes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = (minutes / maxMinutes) * math.pi * 2;

    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.secondary, AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white;

    final shadowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawCircle(center, radius - 6, shadowPaint);
    canvas.drawCircle(center, radius - 14, fillPaint);
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    final handleAngle = startAngle + sweepAngle;
    final handleCenter = Offset(
      center.dx + math.cos(handleAngle) * radius,
      center.dy + math.sin(handleAngle) * radius,
    );

    canvas.drawCircle(
      handleCenter,
      13,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      handleCenter,
      8,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.minutes != minutes || oldDelegate.maxMinutes != maxMinutes;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.darkBlue),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.92),
            AppColors.darkBlue,
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Spacer(),
          Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}
