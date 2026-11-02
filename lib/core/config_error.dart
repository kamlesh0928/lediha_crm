import 'package:flutter/material.dart';

/// Shown instead of a crash when the app is not configured or cannot start.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, this.details});

  /// Extra technical text (for example the exception) shown at the bottom.
  final String? details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('LEDiHA CRM - setup needed')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The app cannot connect to Supabase yet.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text(
                  'Easiest fix (no run flags needed):\n'
                  '1. Create the file  assets/config/env.json  in the project.\n'
                  '2. Put this inside, with your own values:\n'
                  '   {\n'
                  '     "SUPABASE_URL": "https://xxxx.supabase.co",\n'
                  '     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."\n'
                  '   }\n'
                  '3. Stop the app and press Run again (a hot reload is not enough).\n\n'
                  'Use the PUBLISHABLE key, never the secret key.\n\n'
                  'Alternative: run with  --dart-define-from-file=env.json\n\n'
                  'Full steps are in SETUP.md.',
                ),
                if (details != null) ...[
                  const SizedBox(height: 16),
                  const Text('Technical details:', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  SelectableText(details!, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
