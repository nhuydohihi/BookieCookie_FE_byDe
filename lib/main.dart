import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        home: const LoginPage(),
      ),
    );
  }
}
