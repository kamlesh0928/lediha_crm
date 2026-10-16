import 'package:flutter/material.dart';
import 'data/auth_state.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';

class LedihaApp extends StatelessWidget {
  const LedihaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Screen-glow teal on a cool grey: this is a tool for people on the shop floor.
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C86));
    return MaterialApp(
      title: 'LEDiHA CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF3F6F7),
        appBarTheme: AppBarTheme(backgroundColor: scheme.primary, foregroundColor: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: ListenableBuilder(
        listenable: AuthState.instance,
        builder: (_, __) =>
        AuthState.instance.loggedIn ? const HomeShell() : const LoginPage(),
      ),
    );
  }
}
