import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../data/models/book_note_model.dart';
import '../data/models/book_quote_model.dart';
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
  static const int _entryPreviewLimit = 2;
  static const int _minuteStep = 5;
  static const int _maxMinutes = 120;
  static const int _minMinutes = 5;

  late final TextEditingController _noteController;
  late final TextEditingController _quoteController;
  FixedExtentScrollController? _timeController;
  late int _selectedMinutes;
  late int _remainingSeconds;
  late int _elapsedStopwatchSeconds;
  bool _isReading = false;
  bool _isSavingSession = false;
  bool _isSavingNote = false;
  bool _isSavingQuote = false;
  bool _isScanningNote = false;
  bool _isExiting = false;
  bool _allowPagePop = false;
  bool _hasPersistedSession = false;
  Timer? _countdownTimer;
  _ReadingMode _readingMode = _ReadingMode.timer;
  final ApiService _apiService = ApiService();
  bool _isLoadingSessions = false;
  List<_ReadingSession> _readingSessions = const [];
  List<BookQuoteModel> _savedQuotes = const [];
  List<BookNoteModel> _savedNotes = const [];
  String _savedNoteValue = '';
  String _savedQuoteValue = '';
  bool _showAllQuotes = false;
  bool _showAllNotes = false;

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
    _quoteController = TextEditingController();
    _savedNoteValue = _noteController.text.trim();
    _ensureTimeController();
    unawaited(_loadReadingSessions());
    unawaited(_loadSavedEntries());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _noteController.dispose();
    _quoteController.dispose();
    _timeController?.dispose();
    super.dispose();
  }

  FixedExtentScrollController _ensureTimeController() {
    return _timeController ??= FixedExtentScrollController(
      initialItem: _selectedIndex,
    );
  }

  Future<void> _startOrContinueReading() async {
    if (_isReading || _isSavingSession) {
      return;
    }

    final totalSeconds = _selectedMinutes * 60;
    if (_readingMode == _ReadingMode.timer &&
        (_remainingSeconds <= 0 || _remainingSeconds > totalSeconds)) {
      _remainingSeconds = totalSeconds;
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
        unawaited(_endReadingSession());
      }
    });
  }

  void _pauseReading() {
    if (!_isReading) {
      return;
    }

    _countdownTimer?.cancel();
    setState(() {
      _isReading = false;
    });
  }

  void _resetReadingProgress() {
    if (!mounted) {
      _remainingSeconds = _selectedMinutes * 60;
      _elapsedStopwatchSeconds = 0;
      return;
    }

    setState(() {
      _remainingSeconds = _selectedMinutes * 60;
      _elapsedStopwatchSeconds = 0;
      _isReading = false;
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
    });
  }

  int get _elapsedSeconds {
    if (_readingMode == _ReadingMode.stopwatch) {
      return _elapsedStopwatchSeconds;
    }

    final totalSeconds = _selectedMinutes * 60;
    return (totalSeconds - _remainingSeconds).clamp(0, totalSeconds);
  }

  bool get _hasReadingProgress => _elapsedSeconds > 0;
  bool get _canResumeReading =>
      !_isReading &&
      (_readingMode != _ReadingMode.timer || _remainingSeconds > 0);

  int get _todayReadingSeconds {
    final now = DateTime.now();
    final persistedSeconds = _readingSessions
        .where((session) => _isSameDay(session.createdAt, now))
        .fold<int>(0, (sum, session) => sum + session.durationSeconds);

    return persistedSeconds + _elapsedSeconds;
  }

  int get _totalReadingSeconds {
    final persistedSeconds = _readingSessions.fold<int>(
      0,
      (sum, session) => sum + session.durationSeconds,
    );

    return persistedSeconds + _elapsedSeconds;
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

  Future<void> _loadSavedEntries() async {
    final userId = widget.userId;
    final userBookId = widget.userBookId;

    if (userId == null || userBookId == null) {
      return;
    }

    try {
      final quoteResponse = await _apiService.get(
        '/quotes/book/$userBookId?userId=$userId',
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      final noteResponse = await _apiService.get(
        '/notes/book/$userBookId?userId=$userId',
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      final rawQuotes = quoteResponse['data'];
      final rawNotes = noteResponse['data'];

      final nextQuotes = rawQuotes is List
          ? rawQuotes
                .whereType<Map>()
                .map(
                  (item) =>
                      BookQuoteModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.content.trim().isNotEmpty)
                .toList()
          : <BookQuoteModel>[];

      final nextNotes = rawNotes is List
          ? rawNotes
                .whereType<Map>()
                .map(
                  (item) =>
                      BookNoteModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.content.trim().isNotEmpty)
                .toList()
          : <BookNoteModel>[];

      if (!mounted) {
        _savedQuotes = nextQuotes;
        _savedNotes = nextNotes;
        return;
      }

      setState(() {
        _savedQuotes = nextQuotes;
        _savedNotes = nextNotes;
      });
    } catch (_) {
      // Keep the page usable even if loading saved entries fails.
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

      final currentQuote = _quoteController.text.trim();
      final nextQuote = currentQuote.isEmpty
          ? scannedText.trim()
          : '$currentQuote\n\n${scannedText.trim()}';

      setState(() {
        _quoteController.text = nextQuote;
        _quoteController.selection = TextSelection.collapsed(
          offset: _quoteController.text.length,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm nội dung OCR vào quote.')),
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

  Future<bool> _syncCurrentProgress() async {
    if (_isSavingSession) {
      return false;
    }

    final userId = widget.userId;
    final userBookId = widget.userBookId;

    if (userId == null || userBookId == null) {
      return false;
    }

    final durationSeconds = _elapsedSeconds;

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
      _hasPersistedSession = true;
      await _loadReadingSessions();
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

  bool get _hasUnsavedNote => _noteController.text.trim() != _savedNoteValue;
  bool get _hasUnsavedQuote =>
      _quoteController.text.trim().isNotEmpty &&
      _quoteController.text.trim() != _savedQuoteValue;

  Future<void> _saveNote() async {
    if (_isSavingNote) {
      return;
    }

    final userId = widget.userId;
    final userBookId = widget.userBookId;

    if (userId == null || userBookId == null) {
      return;
    }

    setState(() {
      _isSavingNote = true;
    });

    try {
      final result = await _apiService.post(
        '/notes',
        {
          'user_id': userId,
          'user_book_id': userBookId,
          'content': _noteController.text.trim(),
        },
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        setState(() {
          _savedNoteValue = '';
          _noteController.clear();
        });
        await _loadSavedEntries();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu note.')));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không lưu được note.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
        });
      } else {
        _isSavingNote = false;
      }
    }
  }

  Future<void> _saveQuote() async {
    if (_isSavingQuote) {
      return;
    }

    final userId = widget.userId;
    final userBookId = widget.userBookId;
    final content = _quoteController.text.trim();

    if (userId == null || userBookId == null || content.isEmpty) {
      return;
    }

    setState(() {
      _isSavingQuote = true;
    });

    try {
      final result = await _apiService.post(
        '/quotes',
        {
          'user_id': userId,
          'user_book_id': userBookId,
          'content': content,
          'ocr_text': content,
          'ocr_status': 'manual',
        },
        headers: widget.token == null
            ? null
            : {'Authorization': 'Bearer ${widget.token}'},
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        setState(() {
          _savedQuoteValue = content;
          _quoteController.clear();
        });
        await _loadSavedEntries();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu quote.')));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không lưu được quote.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingQuote = false;
        });
      } else {
        _isSavingQuote = false;
      }
    }
  }

  Future<void> _endReadingSession() async {
    if (_isSavingSession) {
      return;
    }

    _countdownTimer?.cancel();

    if (_isReading && mounted) {
      setState(() {
        _isReading = false;
      });
    } else {
      _isReading = false;
    }

    final didSave = await _syncCurrentProgress();
    if (didSave || !_hasReadingProgress) {
      _resetReadingProgress();
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

    await _syncCurrentProgress();

    if (!mounted) {
      return;
    }

    setState(() {
      _allowPagePop = true;
    });

    Navigator.of(context).pop(_hasPersistedSession);
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
                    onPressed: _isSavingSession
                        ? null
                        : (_isReading
                              ? _pauseReading
                              : (_canResumeReading
                                    ? _startOrContinueReading
                                    : null)),
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
                          ? 'Pause'
                          : (_hasReadingProgress ? 'Continue' : 'Start'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (_hasReadingProgress || _isReading) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSavingSession ? null : _endReadingSession,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkBlue,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _readingMode == _ReadingMode.timer
                            ? 'End timer'
                            : 'End stopwatch',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
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
                _ReadingEntryCard(
                  title: 'Quote',
                  accentColor: const Color(0xFF2196F3),
                  icon: Icons.format_quote_rounded,
                  actionLabel: _isSavingQuote ? 'Đang lưu...' : 'Save',
                  actionEnabled:
                      !_isSavingQuote && !_isScanningNote && _hasUnsavedQuote,
                  onActionTap: _saveQuote,
                  entries: _savedQuotes.map((item) => item.content).toList(),
                  entriesExpanded: _showAllQuotes,
                  onToggleEntries: _savedQuotes.length > _entryPreviewLimit
                      ? () {
                          setState(() {
                            _showAllQuotes = !_showAllQuotes;
                          });
                        }
                      : null,
                  emptyEntriesText: 'Chưa có quote nào được lưu.',
                  headerAction: Tooltip(
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
                    controller: _quoteController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'OCR hoặc nhập tay quote của bạn...',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: AppColors.darkBrown.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 18),
                _ReadingEntryCard(
                  title: 'Note',
                  accentColor: const Color(0xFFFFC107),
                  icon: Icons.edit_note_rounded,
                  actionLabel: _isSavingNote ? 'Đang lưu...' : 'Save',
                  actionEnabled: !_isSavingNote && _hasUnsavedNote,
                  onActionTap: _saveNote,
                  entries: _savedNotes.map((item) => item.content).toList(),
                  entriesExpanded: _showAllNotes,
                  onToggleEntries: _savedNotes.length > _entryPreviewLimit
                      ? () {
                          setState(() {
                            _showAllNotes = !_showAllNotes;
                          });
                        }
                      : null,
                  emptyEntriesText: 'Chưa có note nào được lưu.',
                  child: TextField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Viết note cho cuốn sách này...',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: AppColors.darkBrown.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                    onChanged: (_) => setState(() {}),
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
  const _InfoCard({required this.title, required this.child});

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

class _ReadingEntryCard extends StatelessWidget {
  static const int _previewLimit = 2;

  const _ReadingEntryCard({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.child,
    required this.actionLabel,
    required this.actionEnabled,
    required this.onActionTap,
    required this.entries,
    required this.entriesExpanded,
    required this.emptyEntriesText,
    this.headerAction,
    this.onToggleEntries,
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final Widget child;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback onActionTap;
  final List<String> entries;
  final bool entriesExpanded;
  final String emptyEntriesText;
  final Widget? headerAction;
  final VoidCallback? onToggleEntries;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = entriesExpanded
        ? entries
        : entries.take(_previewLimit).toList();
    final hasOverflow = entries.length > _previewLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (headerAction != null) ...[
                headerAction!,
                const SizedBox(width: 8),
              ],
              if (hasOverflow)
                IconButton(
                  onPressed: onToggleEntries,
                  icon: Icon(
                    entriesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.accent,
                  ),
                  tooltip: entriesExpanded ? 'Ẩn bớt' : 'Hiển thị thêm',
                ),
              _SaveButton(
                label: actionLabel,
                enabled: actionEnabled,
                onTap: onActionTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(22),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _SavedEntryBox(
              text: emptyEntriesText,
              accentColor: accentColor,
              isPlaceholder: true,
            )
          else
            Column(
              children: [
                for (var index = 0; index < visibleEntries.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == visibleEntries.length - 1 ? 0 : 10,
                    ),
                    child: _SavedEntryBox(
                      text: visibleEntries[index],
                      accentColor: accentColor,
                    ),
                  ),
                if (hasOverflow && !entriesExpanded) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Hiển thị ${entries.length - _previewLimit} mục nữa',
                      style: TextStyle(
                        color: AppColors.accent.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SavedEntryBox extends StatelessWidget {
  const _SavedEntryBox({
    required this.text,
    required this.accentColor,
    this.isPlaceholder = false,
  });

  final String text;
  final Color accentColor;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: isPlaceholder ? 0.16 : 0.22),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isPlaceholder
                      ? AppColors.darkBrown.withValues(alpha: 0.62)
                      : AppColors.darkBrown.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
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

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
