import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/library_book_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/library_viewmodel.dart';
import 'book_detail_page.dart';
import 'home_page.dart';
import 'manual_add_book_page.dart';
import 'statistic_page.dart';
import 'widgets/app_bottom_bar.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.user, this.token});

  final UserModel user;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryViewModel(user: user, token: token)..loadLibrary(),
      child: _LibraryPageView(user: user, token: token),
    );
  }
}

class _LibraryPageView extends StatefulWidget {
  const _LibraryPageView({required this.user, required this.token});

  final UserModel user;
  final String? token;

  @override
  State<_LibraryPageView> createState() => _LibraryPageViewState();
}

class _LibraryPageViewState extends State<_LibraryPageView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddBook(
    BuildContext context,
    LibraryViewModel libraryVM,
  ) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ManualAddBookPage(user: widget.user, token: widget.token),
      ),
    );

    if (created == true) {
      await libraryVM.loadLibrary();
    }
  }

  Future<void> _openBookDetail(BuildContext context, int userBookId) async {
    final libraryVM = context.read<LibraryViewModel>();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailPage(
          user: widget.user,
          userBookId: userBookId,
          token: widget.token,
        ),
      ),
    );

    if (changed == true) {
      await libraryVM.loadLibrary();
    }
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
        break;
      case AppTab.statistic:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StatisticPage(user: widget.user, token: widget.token),
          ),
        );
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
        child: Consumer<LibraryViewModel>(
          builder: (context, libraryVM, _) {
            final filteredBooks = libraryVM.books.where((book) {
              final query = _searchQuery.trim().toLowerCase();
              if (query.isEmpty) return true;

              return book.title.toLowerCase().contains(query) ||
                  book.author.toLowerCase().contains(query);
            }).toList();

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: libraryVM.loadLibrary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _LibraryHeader(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          onAddTap: () => _openAddBook(context, libraryVM),
                        ),
                        const SizedBox(height: 24),
                        _LibrarySummary(
                          totalBooks: libraryVM.books.length,
                          visibleBooks: filteredBooks.length,
                        ),
                        const SizedBox(height: 20),
                        if (libraryVM.isLoading && libraryVM.books.isEmpty)
                          const SizedBox(
                            height: 260,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else if (libraryVM.errorMessage != null &&
                            libraryVM.books.isEmpty)
                          _LibraryMessageCard(message: libraryVM.errorMessage!)
                        else if (filteredBooks.isEmpty)
                          _LibraryMessageCard(
                            message: libraryVM.books.isEmpty
                                ? 'Your library is empty. Add your first book to get started.'
                                : 'No books match your search.',
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredBooks.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.62,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 18,
                                ),
                            itemBuilder: (context, index) {
                              return _LibraryBookCard(
                                book: filteredBooks[index],
                                onTap: () => _openBookDetail(
                                  context,
                                  filteredBooks[index].id,
                                ),
                              );
                            },
                          ),
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
        currentTab: AppTab.library,
        onTabSelected: (tab) => _handleTabSelection(context, tab),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.controller,
    required this.onChanged,
    required this.onAddTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Library',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onAddTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search books or authors',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(
                color: Colors.grey.shade300, // xám nhạt
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              borderSide: BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({required this.totalBooks, required this.visibleBooks});

  final int totalBooks;
  final int visibleBooks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$visibleBooks book${visibleBooks == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          'Total: $totalBooks',
          style: TextStyle(
            color: AppColors.darkBrown.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({required this.book, required this.onTap});

  final LibraryBookModel book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.shade300, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.cream,
                    child:
                        book.coverImageUrl != null &&
                            book.coverImageUrl!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.network(
                              book.coverImageUrl!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, error, stackTrace) =>
                                  _LibraryBookFallback(title: book.title),
                            ),
                          )
                        : _LibraryBookFallback(title: book.title),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.darkBrown.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatusChip(label: _statusLabel(book.status)),
                        const Spacer(),
                        _RatingStars(rating: book.rating ?? 0),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryBookFallback extends StatelessWidget {
  const _LibraryBookFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'My Book',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final filled = index < rating.clamp(0, 3);
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: 16,
            color: AppColors.secondary,
          ),
        );
      }),
    );
  }
}

class _LibraryMessageCard extends StatelessWidget {
  const _LibraryMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.darkBrown.withValues(alpha: 0.82),
          fontWeight: FontWeight.w700,
          height: 1.4,
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
