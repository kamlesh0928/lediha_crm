import 'package:flutter/material.dart';

/// Shown instead of a crash when the app was started without env.json.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('LEDiHA CRM - setup needed')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The app does not know your Supabase address yet.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 12),
                  Text('1. Copy env.json.example to env.json (project root).\n'
                      '2. Put your Project URL and your PUBLISHABLE key in it:\n'
                      '   SUPABASE_URL = https://xxxx.supabase.co\n'
                      '   SUPABASE_PUBLISHABLE_KEY = sb_publishable_...\n'
                      '3. Start the app with the flag\n'
                      '   --dart-define-from-file=env.json\n\n'
                      'Terminal:  flutter run --dart-define-from-file=env.json\n'
                      'Android Studio: Run > Edit Configurations > Additional run args.\n'
                      'VS Code: press F5 (launch.json already has it).'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
