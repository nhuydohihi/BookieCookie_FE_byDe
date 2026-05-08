import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../data/models/user_model.dart';
import '../viewmodels/account_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'edit_profile_page.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'login_page.dart';
import 'statistic_page.dart';
import 'widgets/app_bottom_bar.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.user, this.token});

  final UserModel user;
  final String? token;

  void _handleTabSelection(
    BuildContext context,
    AppTab tab,
    UserModel activeUser,
  ) {
    switch (tab) {
      case AppTab.home:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(user: activeUser, token: token),
          ),
        );
        break;
      case AppTab.library:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LibraryPage(user: activeUser, token: token),
          ),
        );
        break;
      case AppTab.statistic:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StatisticPage(user: activeUser, token: token),
          ),
        );
        break;
      case AppTab.account:
        break;
      case AppTab.challenge:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge is coming soon.')),
        );
        break;
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    context.read<AuthViewModel>().logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          AccountViewModel(initialUser: user, token: token)..loadProfile(),
      child: Consumer<AccountViewModel>(
        builder: (context, accountVM, _) {
          final profile = accountVM.displayUser;
          final bio = (profile.bio?.trim().isNotEmpty ?? false)
              ? profile.bio!.trim()
              : 'Book lover building a cozy reading journey one page at a time.';

          return Scaffold(
            backgroundColor: AppColors.cream,
            body: SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: accountVM.loadProfile,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const _AccountHeader(),
                          const SizedBox(height: 20),
                          if (accountVM.isLoading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: LinearProgressIndicator(
                                color: AppColors.primary,
                                backgroundColor: Color(0x1AFFA726),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                            ),
                          _ProfileHeroCard(user: profile, bio: bio),
                          if (accountVM.errorMessage != null) ...[
                            const SizedBox(height: 20),
                            _InfoCard(
                              title: 'Thông báo',
                              children: [
                                Text(
                                  accountVM.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final updatedUser =
                                    await Navigator.push<UserModel>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditProfilePage(
                                          user: profile,
                                          token: token,
                                        ),
                                      ),
                                    );

                                if (updatedUser != null && context.mounted) {
                                  context.read<AuthViewModel>().currentUser =
                                      updatedUser;
                                  await accountVM.loadProfile();
                                }
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Chỉnh sửa hồ sơ'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: AppColors.accent,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                backgroundColor: AppColors.surface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleLogout(context),
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Log out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: AppBottomBar(
              currentTab: AppTab.account,
              onTabSelected: (tab) =>
                  _handleTabSelection(context, tab, profile),
            ),
          );
        },
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Quản lý thông tin cá nhân và góc đọc sách của bạn.',
          style: TextStyle(
            color: AppColors.darkBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user, required this.bio});

  final UserModel user;
  final String bio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.surfaceSoft],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _AvatarBadge(user: user),
          const SizedBox(height: 18),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.darkBlue,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.78),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkBlue,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(user.name);

    return Container(
      width: 110,
      height: 110,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        child: user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty
            ? ClipOval(
                child: Image.network(
                  user.avatarUrl!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _AvatarFallback(initials: initials),
                ),
              )
            : _AvatarFallback(initials: initials),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceSoft,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 8),
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

String _buildInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'BK';
  }

  if (parts.length == 1) {
    final first = parts.first;
    return first.substring(0, first.length > 1 ? 2 : 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
