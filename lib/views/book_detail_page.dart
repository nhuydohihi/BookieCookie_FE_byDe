import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/book_detail_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/book_detail_viewmodel.dart';
import 'manual_add_book_page.dart';
import 'quote_scan_page.dart';
import 'reading_page.dart';

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({
    super.key,
    required this.user,
    required this.userBookId,
    this.token,
  });

  final UserModel user;
  final int userBookId;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          BookDetailViewModel(user: user, userBookId: userBookId, token: token)
            ..loadDetail(),
      child: _BookDetailView(user: user, token: token),
    );
  }
}

class _BookDetailView extends StatefulWidget {
  const _BookDetailView({required this.user, required this.token});

  final UserModel user;
  final String? token;

  @override
  State<_BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends State<_BookDetailView> {
  bool _didChange = false;
  bool _showAllQuotes = false;
  bool _showAllNotes = false;

  Future<void> _openEdit(
    BuildContext context,
    BookDetailViewModel viewModel,
  ) async {
    final detail = viewModel.detail;
    if (detail == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualAddBookPage(
          user: widget.user,
          token: widget.token,
          initialBook: detail,
        ),
      ),
    );

    if (updated == true) {
      _didChange = true;
      await viewModel.loadDetail();
    }
  }

  Future<void> _startReading(
    BuildContext context,
    BookDetailViewModel viewModel,
  ) async {
    final success = await viewModel.startReading();
    if (!context.mounted) return;

    if (success) {
      _didChange = true;
      final detail = viewModel.detail;
      final didSaveSession = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingPage(
            title: detail?.title,
            author: detail?.author,
            coverImageUrl: detail?.coverImageUrl,
            userId: widget.user.id,
            userBookId: detail?.id ?? viewModel.userBookId,
            token: widget.token,
          ),
        ),
      );

      if (didSaveSession == true) {
        _didChange = true;
        await viewModel.loadDetail();
      }
    } else if (viewModel.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
    }
  }

  Future<void> _openQuoteScanner(
    BuildContext context,
    BookDetailViewModel viewModel,
  ) async {
    final detail = viewModel.detail;
    if (detail == null) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteScanPage(
          user: widget.user,
          userBookId: detail.id,
          bookTitle: detail.title,
          token: widget.token,
        ),
      ),
    );

    if (created == true && context.mounted) {
      _didChange = true;
      await viewModel.loadDetail();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote đã được thêm vào sách này.')),
      );
    }
  }

  Future<void> _openNoteEditor(
    BuildContext context,
    BookDetailViewModel viewModel,
  ) async {
    final detail = viewModel.detail;
    if (detail == null) return;

    final controller = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final hasChanged = controller.text.trim().isNotEmpty;

              return Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Save Note',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 8,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Viết note của bạn...',
                        filled: true,
                        fillColor: const Color(0xFFF7F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !hasChanged || viewModel.isSavingNote
                            ? null
                            : () async {
                                final didSave = await viewModel.saveNote(
                                  controller.text.trim(),
                                );
                                if (!context.mounted) return;
                                if (didSave) {
                                  Navigator.pop(sheetContext, true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Không lưu được note.'),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          viewModel.isSavingNote ? 'Đang lưu...' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    controller.dispose();

    if (saved == true) {
      _didChange = true;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu note.')));
    }
  }

  void _handleBack() {
    Navigator.pop(context, _didChange);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _didChange);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Consumer<BookDetailViewModel>(
            builder: (context, viewModel, _) {
              if (viewModel.isLoading && viewModel.detail == null) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (viewModel.errorMessage != null && viewModel.detail == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      viewModel.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              final detail = viewModel.detail;
              final notes = viewModel.notes;
              final quotes = viewModel.quotes;
              if (detail == null) {
                return const SizedBox.shrink();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _DetailActionButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: _handleBack,
                        ),
                        const Spacer(),
                        _DetailActionButton(
                          icon: Icons.edit_rounded,
                          onTap: () => _openEdit(context, viewModel),
                        ),
                        const SizedBox(width: 10),
                        _DetailActionButton(
                          icon: Icons.format_quote_rounded,
                          onTap: () => _openQuoteScanner(context, viewModel),
                        ),
                        const SizedBox(width: 10),
                        _DetailActionButton(
                          icon: Icons.play_arrow_rounded,
                          onTap: viewModel.isStartingReading
                              ? null
                              : () => _startReading(context, viewModel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 220,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 0.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child:
                              detail.coverImageUrl != null &&
                                  detail.coverImageUrl!.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Image.network(
                                    detail.coverImageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stackTrace) =>
                                        _DetailCoverFallback(
                                          title: detail.title,
                                        ),
                                  ),
                                )
                              : _DetailCoverFallback(title: detail.title),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _BookMetaSection(detail: detail),
                    const SizedBox(height: 28),
                    _DetailBlock(
                      title: 'Đánh giá',
                      child: Row(
                        children: [
                          _StatusPill(label: _statusLabel(detail.status)),
                          const SizedBox(width: 12),
                          _RatingRow(rating: detail.rating ?? 0),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InsightCard(
                      title: 'Quote',
                      icon: Icons.format_quote_rounded,
                      accentColor: const Color(0xFF2196F3),
                      emptyText: 'Chưa có quote nào cho cuốn sách này.',
                      entries: quotes
                          .map((quote) => quote.content.trim())
                          .where((content) => content.isNotEmpty)
                          .toList(),
                      isExpanded: _showAllQuotes,
                      onToggleExpanded: quotes.length > 2
                          ? () {
                              setState(() {
                                _showAllQuotes = !_showAllQuotes;
                              });
                            }
                          : null,
                      onAddTap: () => _openQuoteScanner(context, viewModel),
                    ),
                    const SizedBox(height: 20),
                    _InsightCard(
                      title: 'Note',
                      icon: Icons.edit_note_rounded,
                      accentColor: const Color(0xFFFFC107),
                      emptyText: 'Chưa có note nào cho cuốn sách này.',
                      entries: notes
                          .map((note) => note.content.trim())
                          .where((content) => content.isNotEmpty)
                          .toList(),
                      isExpanded: _showAllNotes,
                      onToggleExpanded: notes.length > 2
                          ? () {
                              setState(() {
                                _showAllNotes = !_showAllNotes;
                              });
                            }
                          : null,
                      onAddTap: () => _openNoteEditor(context, viewModel),
                    ),
                    if (detail.description != null &&
                        detail.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _DetailBlock(
                        title: 'Mô tả',
                        child: Text(
                          detail.description!,
                          style: TextStyle(
                            color: AppColors.darkBrown.withValues(alpha: 0.84),
                            fontSize: 15,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BookMetaSection extends StatelessWidget {
  const _BookMetaSection({required this.detail});

  final BookDetailModel detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.title,
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            _MetaChip(icon: Icons.person_outline_rounded, text: detail.author),
            if (detail.publishedYear != null)
              _MetaChip(
                icon: Icons.auto_stories_outlined,
                text: 'Published ${detail.publishedYear}',
              ),
            if (detail.startDate != null && detail.startDate!.isNotEmpty)
              _MetaChip(
                icon: Icons.play_circle_outline_rounded,
                text: detail.startDate!,
              ),
            if (detail.finishDate != null && detail.finishDate!.isNotEmpty)
              _MetaChip(
                icon: Icons.check_circle_outline_rounded,
                text: detail.finishDate!,
              ),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300, width: 0.7),
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

class _DetailCoverFallback extends StatelessWidget {
  const _DetailCoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final filled = index < rating.clamp(0, 5);
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: AppColors.secondary,
            size: 20,
          ),
        );
      }),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.entries,
    required this.emptyText,
    required this.isExpanded,
    required this.onAddTap,
    this.onToggleExpanded,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> entries;
  final String emptyText;
  final bool isExpanded;
  final VoidCallback onAddTap;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = isExpanded ? entries : entries.take(2).toList();
    final hasOverflow = entries.length > 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
              if (hasOverflow)
                IconButton(
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.accent,
                    size: 28,
                  ),
                  tooltip: isExpanded ? 'Ẩn bớt' : 'Hiển thị thêm',
                ),
              IconButton(
                onPressed: onAddTap,
                icon: const Icon(Icons.add_rounded, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: entries.isEmpty
                ? _InsightEntryBox(
                    text: emptyText,
                    accentColor: accentColor,
                    isPlaceholder: true,
                  )
                : Column(
                    children: [
                      for (
                        var index = 0;
                        index < visibleEntries.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == visibleEntries.length - 1 ? 0 : 12,
                          ),
                          child: _InsightEntryBox(
                            text: visibleEntries[index],
                            accentColor: accentColor,
                          ),
                        ),
                      if (hasOverflow && !isExpanded) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'Hiển thị ${entries.length - 2} mục nữa',
                            style: TextStyle(
                              color: AppColors.accent.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InsightEntryBox extends StatelessWidget {
  const _InsightEntryBox({
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: isPlaceholder ? 0.18 : 0.24),
          width: 1,
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
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'reading':
      return 'Reading';
    case 'finished':
      return 'Finished';
    case 'abandoned':
      return 'Dropped';
    default:
      return 'Planned';
  }
}
