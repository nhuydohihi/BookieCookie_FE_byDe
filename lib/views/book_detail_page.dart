import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/book_detail_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/book_detail_viewmodel.dart';
import 'manual_add_book_page.dart';
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
      create: (_) => BookDetailViewModel(
        user: user,
        userBookId: userBookId,
        token: token,
      )..loadDetail(),
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

  Future<void> _openEdit(BuildContext context, BookDetailViewModel viewModel) async {
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

  Future<void> _startReading(BuildContext context, BookDetailViewModel viewModel) async {
    final success = await viewModel.startReading();
    if (!context.mounted) return;

    if (success) {
      _didChange = true;
      final detail = viewModel.detail;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingPage(
            title: detail?.title,
            author: detail?.author,
            coverImageUrl: detail?.coverImageUrl,
            initialNote: detail?.note,
            userId: widget.user.id,
            userBookId: detail?.id ?? viewModel.userBookId,
            token: widget.token,
          ),
        ),
      );
    } else if (viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage!)),
      );
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
                          child: detail.coverImageUrl != null &&
                                  detail.coverImageUrl!.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Image.network(
                                    detail.coverImageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stackTrace) =>
                                        _DetailCoverFallback(title: detail.title),
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
                    _DetailBlock(
                      title: 'Ghi chú',
                      trailing: detail.note == null || detail.note!.trim().isEmpty
                          ? null
                          : const _NoteTag(label: 'Note'),
                      child: Text(
                        (detail.note == null || detail.note!.trim().isEmpty)
                            ? 'Chưa có ghi chú cho cuốn sách này.'
                            : detail.note!,
                        style: TextStyle(
                          color: AppColors.darkBrown.withValues(alpha: 0.84),
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (detail.description != null &&
                        detail.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _DetailBlock(
                        title: 'Mô tả',
                        trailing: const _NoteTag(label: 'Quotes'),
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
            if (detail.readingYear != null)
              _MetaChip(
                icon: Icons.calendar_today_rounded,
                text: '${detail.readingYear}',
              ),
            if (detail.publishedYear != null)
              _MetaChip(
                icon: Icons.auto_stories_outlined,
                text: 'Published ${detail.publishedYear}',
              ),
            if (detail.startDate != null && detail.startDate!.isNotEmpty)
              _MetaChip(icon: Icons.play_circle_outline_rounded, text: detail.startDate!),
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
  const _DetailBlock({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

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
            ...?trailing == null ? null : [trailing!],
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

class _NoteTag extends StatelessWidget {
  const _NoteTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300, width: 0.7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkBlue,
          fontWeight: FontWeight.w700,
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
