import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/login_page.dart';

void main() {
  runApp(const BookieCookieApp());
}

class BookieCookieApp extends StatelessWidget {
  const BookieCookieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bookie Cookie',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.cream,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppColors.darkBlue,
            error: Colors.redAccent,
            onError: Colors.white,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.cream,
            foregroundColor: AppColors.darkBlue,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppColors.darkBlue,
            contentTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            hintStyle: TextStyle(
              color: AppColors.darkBrown.withValues(alpha: 0.58),
            ),
            prefixIconColor: AppColors.primary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.4,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(
                alpha: 0.45,
              ),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          dividerColor: AppColors.border,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppColors.primary,
            selectionColor: Color(0x33FFA726),
            selectionHandleColor: AppColors.primary,
          ),
        ),
        home: const LoginPage(),
      ),
    );
  }
}
