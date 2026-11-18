import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'data/app_auth.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';

class LedihaApp extends StatelessWidget {
  const LedihaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LEDiHA - Your TV Repair Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ListenableBuilder(
        listenable: AppAuth.instance,
        builder: (_, _) =>
            AppAuth.instance.loggedIn ? const HomeShell() : const LoginPage(),
      ),
    );
  }
}
