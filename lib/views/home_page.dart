import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/home_dashboard_model.dart';
import '../data/models/user_model.dart';
import '../viewmodels/home_viewmodel.dart';
import 'account_page.dart';
import 'book_detail_page.dart';
import 'library_page.dart';
import 'manual_add_book_page.dart';
import 'reading_page.dart';
import 'statistic_page.dart';
import 'widgets/add_book_menu_button.dart';
import 'widgets/app_bottom_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.user, this.token});

  final UserModel user;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(user: user, token: token)..loadDashboard(),
      child: _HomePageView(user: user, token: token),
    );
  }
}

class _HomePageView extends StatelessWidget {
  const _HomePageView({required this.user, required this.token});

  final UserModel user;
  final String? token;

  Future<void> _handleAddBookAction(
    BuildContext context,
    HomeViewModel homeVM,
    AddBookAction action,
  ) async {
    switch (action) {
      case AddBookAction.manual:
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ManualAddBookPage(user: user, token: token),
          ),
        );

        if (created == true) {
          await homeVM.loadDashboard();
        }
        break;
      case AddBookAction.searchOnline:
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ManualAddBookPage(
              user: user,
              token: token,
              initialMode: AddBookMode.searchOnline,
            ),
          ),
        );

        if (created == true) {
          await homeVM.loadDashboard();
        }
        break;
      case AddBookAction.scanIsbn:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tính năng quét ISBN đang được phát triển.'),
          ),
        );
        break;
    }
  }

  void _handleTabSelection(BuildContext context, AppTab tab) {
    switch (tab) {
      case AppTab.home:
        break;
      case AppTab.library:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LibraryPage(user: user, token: token),
          ),
        );
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
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tab.label} is coming soon.')));
    }
  }

  Future<void> _openBookDetail(BuildContext context, int userBookId) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookDetailPage(user: user, userBookId: userBookId, token: token),
      ),
    );

    if (changed == true && context.mounted) {
      await context.read<HomeViewModel>().loadDashboard();
    }
  }

  void _openReading(BuildContext context, List<CurrentReadingBook> books) {
    final currentBook = books.isNotEmpty ? books.first : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPage(
          title: currentBook?.title,
          author: currentBook?.author,
          coverImageUrl: currentBook?.coverImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Consumer<HomeViewModel>(
          builder: (context, homeVM, _) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: homeVM.loadDashboard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _HomeHeader(
                          userName: homeVM.user.name,
                          onAddBookSelected: (action) =>
                              _handleAddBookAction(context, homeVM, action),
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title: 'Current reading',
                          actionLabel:
                              '${homeVM.dashboard?.currentReading.length ?? 0} books',
                        ),
                        const SizedBox(height: 16),
                        _CurrentReadingSection(
                          books: homeVM.dashboard?.currentReading ?? const [],
                          isLoading: homeVM.isLoading,
                          onBookTap: (userBookId) =>
                              _openBookDetail(context, userBookId),
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(title: 'Streaks'),
                        const SizedBox(height: 14),
                        _StreakCard(
                          streakDays: homeVM.dashboard?.streakDays ?? 0,
                          activityCount: homeVM.dashboard?.activityCount ?? 0,
                          onStartReading: () => _openReading(
                            context,
                            homeVM.dashboard?.currentReading ?? const [],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title:
                              'Finish in ${homeVM.dashboard?.year ?? DateTime.now().year}',
                        ),
                        const SizedBox(height: 16),
                        _FinishedBooksSection(
                          books: homeVM.dashboard?.finishedInYear ?? const [],
                          isLoading: homeVM.isLoading,
                          onBookTap: (userBookId) =>
                              _openBookDetail(context, userBookId),
                        ),
                        if (homeVM.errorMessage != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            homeVM.errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
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
        currentTab: AppTab.home,
        onTabSelected: (tab) => _handleTabSelection(context, tab),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName, required this.onAddBookSelected});

  final String userName;
  final ValueChanged<AddBookAction> onAddBookSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Homepage',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hello, $userName',
              style: TextStyle(
                color: AppColors.darkBrown.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Spacer(),
        AddBookMenuButton(onSelected: onAddBookSelected),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        if (actionLabel != null)
          Text(
            actionLabel!,
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _CurrentReadingSection extends StatelessWidget {
  const _CurrentReadingSection({
    required this.books,
    required this.isLoading,
    required this.onBookTap,
  });

  final List<CurrentReadingBook> books;
  final bool isLoading;
  final ValueChanged<int> onBookTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && books.isEmpty) {
      return const SizedBox(
        height: 176,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final List<CurrentReadingBook?> displayBooks = books.isEmpty
        ? [null, null]
        : books.take(6).toList();

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final book = displayBooks[index];
          if (book == null) {
            return const _EmptyBookCard();
          }

          return _ReadingBookCard(book: book, onTap: () => onBookTap(book.id));
        },
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemCount: displayBooks.length,
      ),
    );
  }
}

class _ReadingBookCard extends StatelessWidget {
  const _ReadingBookCard({required this.book, required this.onTap});

  final CurrentReadingBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
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
                    child:
                        book.coverImageUrl != null &&
                            book.coverImageUrl!.isNotEmpty
                        ? Image.network(
                            book.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) =>
                                _BookCoverFallback(title: book.title),
                          )
                        : _BookCoverFallback(title: book.title),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _BookCoverFallback extends StatelessWidget {
  const _BookCoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.darkBlue,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBookCard extends StatelessWidget {
  const _EmptyBookCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: 0,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a book',
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streakDays,
    required this.activityCount,
    required this.onStartReading,
  });

  final int streakDays;
  final int activityCount;
  final VoidCallback onStartReading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, AppColors.primary.withValues(alpha: 0.12)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 54,
                  color: AppColors.secondary.withValues(alpha: 0.9),
                ),
                const Positioned(
                  bottom: 18,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 24,
                    color: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$streakDays days',
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activityCount == 0
                ? 'Start updating your reading to build a streak.'
                : '$activityCount reading activity day(s) recorded from your database.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStartReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start to read',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedBooksSection extends StatelessWidget {
  const _FinishedBooksSection({
    required this.books,
    required this.isLoading,
    required this.onBookTap,
  });

  final List<FinishedBook> books;
  final bool isLoading;
  final ValueChanged<int> onBookTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && books.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (books.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Text(
          'No finished books this year yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.darkBrown.withValues(alpha: 0.8),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => _FinishedBookCard(
          book: books[index],
          onTap: () => onBookTap(books[index].id),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemCount: books.length,
      ),
    );
  }
}

class _FinishedBookCard extends StatelessWidget {
  const _FinishedBookCard({required this.book, required this.onTap});

  final FinishedBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
                ? Image.network(
                    book.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) =>
                        _BookCoverFallback(title: book.title),
                  )
                : _BookCoverFallback(title: book.title),
          ),
        ),
      ),
    );
  }
}
