import 'package:flutter/material.dart';
import 'theme.dart';

/// Shown instead of a crash when the app is not configured or cannot start.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, this.details});

  /// Extra technical text (for example the exception) shown at the bottom.
  final String? details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('LEDiHA CRM - Setup Needed'),
          backgroundColor: AppColors.brandRed,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 50,
                        errorBuilder: (_, _, _) => const Icon(Icons.tv, size: 48, color: AppColors.brandRed),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your tv Repair Partner',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'The app cannot connect to Supabase backend yet.',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Text(
                    'Configuration Steps:\n'
                    '1. Create the file  assets/config/env.json  in the project.\n'
                    '2. Add your Supabase credentials:\n'
                    '   {\n'
                    '     "SUPABASE_URL": "https://xxxx.supabase.co",\n'
                    '     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."\n'
                    '   }\n'
                    '3. Restart the app (full restart required).\n\n'
                    'Note: Use the PUBLISHABLE key, never the secret key.',
                    style: TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'),
                  ),
                ),
                if (details != null) ...[
                  const SizedBox(height: 16),
                  const Text('What went wrong:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SelectableText(details!, style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
