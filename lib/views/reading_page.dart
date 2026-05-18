import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import 'note_scan_page.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({
    super.key,
    this.title,
    this.author,
    this.coverImageUrl,
    this.initialNote,
    this.initialMinutes = 25,
    this.userId,
    this.userBookId,
    this.token,
  });

  final String? title;
  final String? author;
  final String? coverImageUrl;
  final String? initialNote;
  final int initialMinutes;
  final int? userId;
  final int? userBookId;
  final String? token;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  static const int _minuteStep = 5;
  static const int _maxMinutes = 120;
  static const int _minMinutes = 5;

  late final TextEditingController _noteController;
  FixedExtentScrollController? _timeController;
  late int _selectedMinutes;
  late int _remainingSeconds;
  late int _elapsedStopwatchSeconds;
  bool _isReading = false;
  bool _isSavingSession = false;
  bool _isScanningNote = false;
  bool _isExiting = false;
  bool _allowPagePop = false;
  Timer? _countdownTimer;
  _ReadingMode _readingMode = _ReadingMode.timer;
  final ApiService _apiService = ApiService();
  int _syncedElapsedSeconds = 0;
  bool _isLoadingSessions = false;
  List<_ReadingSession> _readingSessions = const [];

  int get _itemCount => (_maxMinutes - _minMinutes) ~/ _minuteStep + 1;
  int get _selectedIndex => (_selectedMinutes - _minMinutes) ~/ _minuteStep;

  @override
  void initState() {
    super.initState();
    _selectedMinutes =
        (widget.initialMinutes.clamp(_minMinutes, _maxMinutes) as num).toInt();
    _remainingSeconds = _selectedMinutes * 60;
    _elapsedStopwatchSeconds = 0;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _ensureTimeController();
    unawaited(_loadReadingSessions());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _noteController.dispose();
    _timeController?.dispose();
    super.dispose();
  }

  FixedExtentScrollController _ensureTimeController() {
    return _timeController ??= FixedExtentScrollController(
      initialItem: _selectedIndex,
    );
  }

  Future<void> _toggleReading() async {
    if (_isReading && _readingMode == _ReadingMode.stopwatch) {
      _countdownTimer?.cancel();
      setState(() {
        _isReading = false;
      });
      final didSave = await _syncCurrentProgress(finalize: true);
      if (didSave || _elapsedStopwatchSeconds <= 0) {
        _resetStopwatch();
      }
      return;
    }

    if (_isReading) {
      _countdownTimer?.cancel();
      setState(() {
        _isReading = false;
      });
      await _syncCurrentProgress(finalize: false);
      return;
    }

    final totalSeconds = _selectedMinutes * 60;
    if (_readingMode == _ReadingMode.timer &&
        (_remainingSeconds <= 0 || _remainingSeconds > totalSeconds)) {
      _remainingSeconds = totalSeconds;
      _syncedElapsedSeconds = 0;
    }

    setState(() {
      _isReading = true;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_readingMode == _ReadingMode.timer) {
          if (_remainingSeconds <= 1) {
            _remainingSeconds = 0;
            _isReading = false;
          } else {
            _remainingSeconds -= 1;
          }
          return;
        }

        _elapsedStopwatchSeconds += 1;
      });

      if (_readingMode == _ReadingMode.timer && !_isReading) {
        timer.cancel();
        unawaited(_syncCurrentProgress(finalize: true));
      }
    });
  }

  void _resetStopwatch() {
    if (!mounted) {
      _elapsedStopwatchSeconds = 0;
      _syncedElapsedSeconds = 0;
      return;
    }

    setState(() {
      _elapsedStopwatchSeconds = 0;
      _syncedElapsedSeconds = 0;
    });
  }

  void _handleTimeChanged(int index) {
    if (_isReading) {
      return;
    }

    final nextMinutes = _minMinutes + (index * _minuteStep);
    if (nextMinutes == _selectedMinutes) {
      return;
    }

    setState(() {
      _selectedMinutes = nextMinutes;
      _remainingSeconds = nextMinutes * 60;
      _elapsedStopwatchSeconds = 0;
      _syncedElapsedSeconds = 0;
    });
  }

  Future<void> _handleModeChanged(_ReadingMode mode) async {
    if (mode == _readingMode || _isReading || _isSavingSession) {
      return;
    }

    setState(() {
      _readingMode = mode;
      _remainingSeconds = _selectedMinutes * 60;
      _elapsedStopwatchSeconds = 0;
      _syncedElapsedSeconds = 0;
    });
  }

  int get _elapsedSeconds {
    if (_readingMode == _ReadingMode.stopwatch) {
      return _elapsedStopwatchSeconds;
    }

    final totalSeconds = _selectedMinutes * 60;
    return (totalSeconds - _remainingSeconds).clamp(0, totalSeconds);
  }

  int get _liveUnsyncedSeconds =>
      math.max(_elapsedSeconds - _syncedElapsedSeconds, 0);

  int get _todayReadingSeconds {
    final now = DateTime.now();
    final persistedSeconds = _readingSessions
        .where((session) => _isSameDay(session.createdAt, now))
        .fold<int>(0, (sum, session) => sum + session.durationSeconds);

    return persistedSeconds + _liveUnsyncedSeconds;
  }

  int get _totalReadingSeconds {
    final persistedSeconds = _readingSessions.fold<int>(
      0,
      (sum, session) => sum + session.durationSeconds,
    );

    return persistedSeconds + _liveUnsyncedSeconds;
  }

  Future<void> _loadReadingSessions() async {
    final userId = widget.userId;
    final userBookId = widget.userBookId;

    if (userId == null || userBookId == null) {
      return;
    }

    setState(() {
      _isLoadingSessions = true;
    });

    try {
      final response = await _apiService.get(
        '/user-books/$userBookId/reading-sessions?userId=$userId',
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      final rawData = response['data'];
      final sessions = rawData is List
          ? rawData
                .whereType<Map>()
                .map(
                  (item) =>
                      _ReadingSession.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <_ReadingSession>[];

      if (!mounted) {
        _readingSessions = sessions;
        _isLoadingSessions = false;
        return;
      }

      setState(() {
        _readingSessions = sessions;
        _isLoadingSessions = false;
      });
    } catch (_) {
      if (!mounted) {
        _isLoadingSessions = false;
        return;
      }

      setState(() {
        _isLoadingSessions = false;
      });
    }
  }

  Future<void> _openNoteScanner() async {
    if (_isScanningNote) {
      return;
    }

    setState(() {
      _isScanningNote = true;
    });

    try {
      final scannedText = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const NoteScanPage()),
      );

      if (!mounted || scannedText == null || scannedText.trim().isEmpty) {
        return;
      }

      final currentNote = _noteController.text.trim();
      final nextNote = currentNote.isEmpty
          ? scannedText.trim()
          : '$currentNote\n\n${scannedText.trim()}';

      setState(() {
        _noteController.text = nextNote;
        _noteController.selection = TextSelection.collapsed(
          offset: _noteController.text.length,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm nội dung OCR vào ghi chú.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanningNote = false;
        });
      } else {
        _isScanningNote = false;
      }
    }
  }

  Future<bool> _syncCurrentProgress({required bool finalize}) async {
    if (_isSavingSession) {
      return false;
    }

    final userId = widget.userId;
    final userBookId = widget.userBookId;

    if (userId == null || userBookId == null) {
      return false;
    }

    final unsavedSeconds = _elapsedSeconds - _syncedElapsedSeconds;
    if (unsavedSeconds <= 0) {
      return false;
    }

    final durationSeconds = unsavedSeconds;

    if (durationSeconds <= 0) {
      return false;
    }

    if (mounted) {
      setState(() {
        _isSavingSession = true;
      });
    } else {
      _isSavingSession = true;
    }

    try {
      final response = await _apiService.post(
        '/user-books/$userBookId/reading-sessions',
        {
          'user_id': userId,
          'duration_seconds': durationSeconds,
          'pages_read': 0,
        },
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      final rawSession = response['data'];
      if (rawSession is Map) {
        final session = _ReadingSession.fromJson(
          Map<String, dynamic>.from(rawSession),
        );
        _readingSessions = [session, ..._readingSessions];
      }

      if (finalize) {
        _syncedElapsedSeconds = _elapsedSeconds;
      } else {
        _syncedElapsedSeconds += durationSeconds;
      }
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được phiên đọc lên server.')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSession = false;
        });
      } else {
        _isSavingSession = false;
      }
    }
  }

  Future<void> _handleExit() async {
    if (_isSavingSession || _isExiting) {
      return;
    }

    _isExiting = true;

    _countdownTimer?.cancel();

    if (_isReading) {
      setState(() {
        _isReading = false;
      });
    }

    await _syncCurrentProgress(finalize: true);

    if (!mounted) {
      return;
    }

    setState(() {
      _allowPagePop = true;
    });

    Navigator.of(context).pop();
  }

  double get _progressValue {
    if (_readingMode == _ReadingMode.stopwatch) {
      final totalSeconds = _selectedMinutes * 60;
      if (totalSeconds <= 0) {
        return 0.0;
      }

      return ((_elapsedStopwatchSeconds / totalSeconds).clamp(0.0, 1.0) as num)
          .toDouble();
    }

    if (!_isReading) {
      return 1.0;
    }

    final totalSeconds = _selectedMinutes * 60;
    if (totalSeconds <= 0) {
      return 0.0;
    }

    return ((_remainingSeconds / totalSeconds).clamp(0.0, 1.0) as num)
        .toDouble();
  }

  String get _centerLabel {
    final totalSeconds = _readingMode == _ReadingMode.stopwatch
        ? _elapsedStopwatchSeconds
        : (_isReading ? _remainingSeconds : _selectedMinutes * 60);
    final safeSeconds = math.max(totalSeconds, 0);
    final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : 'Reading';
    final displayAuthor = widget.author?.trim().isNotEmpty == true
        ? widget.author!.trim()
        : 'Focus session';

    return PopScope(
      canPop: _allowPagePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isExiting) {
          unawaited(_handleExit());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TopActionButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => _handleExit(),
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
                  child: _ReadingModeToggle(
                    mode: _readingMode,
                    isEnabled: !_isReading && !_isSavingSession,
                    onChanged: _handleModeChanged,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: _ReadingDial(
                    centerLabel: _centerLabel,
                    progressValue: _progressValue,
                    selectedMinutes: _selectedMinutes,
                    controller: _ensureTimeController(),
                    itemCount: _itemCount,
                    minuteStep: _minuteStep,
                    minMinutes: _minMinutes,
                    isReading: _isReading,
                    onSelectedItemChanged: _handleTimeChanged,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingSession ? null : () => _toggleReading(),
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
                      _isReading
                          ? (_readingMode == _ReadingMode.timer
                                ? 'Pause timer'
                                : 'End stopwatch')
                          : (_readingMode == _ReadingMode.timer
                                ? 'Start timer'
                                : 'Start stopwatch'),
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
                  title: 'Thời gian đọc',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hôm nay',
                                  style: TextStyle(
                                    color: AppColors.darkBrown.withValues(
                                      alpha: 0.74,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLoadingSessions
                                      ? 'Đang tải...'
                                      : _formatDuration(_todayReadingSeconds),
                                  style: const TextStyle(
                                    color: AppColors.darkBlue,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isReading)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Đang đọc',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tổng của cuốn sách',
                        style: TextStyle(
                          color: AppColors.darkBrown.withValues(alpha: 0.74),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLoadingSessions
                            ? 'Đang tải...'
                            : _formatDuration(_totalReadingSeconds),
                        style: const TextStyle(
                          color: AppColors.darkBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _InfoCard(
                  title: 'Ghi chú',
                  trailing: Tooltip(
                    message: _isScanningNote
                        ? 'Đang quét ảnh...'
                        : 'OCR từ ảnh',
                    child: _CardActionButton(
                      icon: _isScanningNote
                          ? Icons.hourglass_top_rounded
                          : Icons.camera_alt_rounded,
                      onTap: _isScanningNote ? null : _openNoteScanner,
                    ),
                  ),
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
    required this.centerLabel,
    required this.progressValue,
    required this.selectedMinutes,
    required this.controller,
    required this.itemCount,
    required this.minuteStep,
    required this.minMinutes,
    required this.isReading,
    required this.onSelectedItemChanged,
  });

  final String centerLabel;
  final double progressValue;
  final int selectedMinutes;
  final FixedExtentScrollController controller;
  final int itemCount;
  final int minuteStep;
  final int minMinutes;
  final bool isReading;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    const size = 260.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(size),
            painter: _DialPainter(progressValue: progressValue),
          ),
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 104,
                  child: ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 42,
                    diameterRatio: 1.28,
                    perspective: 0.003,
                    physics: isReading
                        ? const NeverScrollableScrollPhysics()
                        : const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: onSelectedItemChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: itemCount,
                      builder: (context, index) {
                        final value = minMinutes + (index * minuteStep);
                        final isSelected = value == selectedMinutes;

                        return Center(
                          child: Text(
                            '${value.toString().padLeft(2, '0')}m',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.transparent
                                  : AppColors.darkBrown.withValues(alpha: 0.10),
                              fontSize: isSelected ? 38 : 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 138,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.primary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Text(
                    centerLabel,
                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
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

class _ReadingModeToggle extends StatelessWidget {
  const _ReadingModeToggle({
    required this.mode,
    required this.isEnabled,
    required this.onChanged,
  });

  final _ReadingMode mode;
  final bool isEnabled;
  final ValueChanged<_ReadingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeIconButton(
            icon: Icons.hourglass_top_rounded,
            isSelected: mode == _ReadingMode.timer,
            isEnabled: isEnabled,
            tooltip: 'Timer',
            onTap: () => onChanged(_ReadingMode.timer),
          ),
          const SizedBox(width: 6),
          _ModeIconButton(
            icon: Icons.timer_outlined,
            isSelected: mode == _ReadingMode.stopwatch,
            isEnabled: isEnabled,
            tooltip: 'Stopwatch',
            onTap: () => onChanged(_ReadingMode.stopwatch),
          ),
        ],
      ),
    );
  }
}

class _ModeIconButton extends StatelessWidget {
  const _ModeIconButton({
    required this.icon,
    required this.isSelected,
    required this.isEnabled,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.24)
                    : AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled
                  ? (isSelected ? AppColors.primary : AppColors.darkBrown)
                  : AppColors.darkBrown.withValues(alpha: 0.32),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.progressValue});

  final double progressValue;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    const startAngle = -math.pi / 2;
    final sweepAngle = progressValue * math.pi * 2;

    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;

    final progressPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progressValue != progressValue;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...?trailing == null ? null : <Widget>[trailing!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({required this.icon, required this.onTap});

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

class _ReadingSession {
  const _ReadingSession({
    required this.durationSeconds,
    required this.createdAt,
  });

  final int durationSeconds;
  final DateTime createdAt;

  factory _ReadingSession.fromJson(Map<String, dynamic> json) {
    final parsedDurationSeconds = json['duration_seconds'] is num
        ? (json['duration_seconds'] as num).toInt()
        : ((json['duration_minutes'] as num?)?.toInt() ?? 0) * 60;

    return _ReadingSession(
      durationSeconds: parsedDurationSeconds,
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
    );
  }
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

enum _ReadingMode { timer, stopwatch }

String _formatDuration(int totalSeconds) {
  final safeSeconds = math.max(totalSeconds, 0);
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;

  if (hours > 0) {
    if (minutes == 0 && seconds == 0) {
      return '$hours giờ 00 phút 00 giây';
    }

    return '$hours giờ $minutes phút ${seconds.toString().padLeft(2, '0')} giây';
  }

  if (minutes > 0) {
    return '$minutes phút ${seconds.toString().padLeft(2, '0')} giây';
  }

  if (seconds > 0) {
    return '$seconds giây';
  }

  return '0 giây';
}
