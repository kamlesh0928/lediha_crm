import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Supabase connection settings.
///
/// Two ways to provide them (the first one found wins):
///  1. `--dart-define-from-file=env.json` on the run/build command (good for CI and release builds)
///  2. the file `assets/config/env.json` (git-ignored; simplest for daily work - just press Run)
///
/// Only the PUBLISHABLE key (sb_publishable_...) belongs in the app.
/// NEVER put the secret key (sb_secret_...) or the old service_role key here.
class Env {
  static const _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _publishableDefine = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  // Old name, still accepted so existing files keep working.
  static const _legacyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String _url = '';
  static String _key = '';

  /// Call once at start-up, before reading the values below.
  static Future<void> load() async {
    _url = _urlDefine.trim();
    _key = (_publishableDefine.isNotEmpty ? _publishableDefine : _legacyDefine).trim();
    if (_url.isNotEmpty && _key.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString('assets/config/env.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (_url.isEmpty) _url = (data['SUPABASE_URL'] ?? '').toString().trim();
      if (_key.isEmpty) {
        _key = (data['SUPABASE_PUBLISHABLE_KEY'] ?? data['SUPABASE_ANON_KEY'] ?? '')
            .toString()
            .trim();
      }
    } catch (_) {
      // File not present: fine, isConfigured will be false.
    }
  }

  static String get supabaseUrl => _url;
  static String get supabasePublishableKey => _key;

  /// True when a Supabase URL and a publishable key are available.
  static bool get isConfigured => _url.startsWith('https://') && _key.isNotEmpty;

  /// True when someone pasted a secret key into the app by mistake.
  static bool get looksLikeSecretKey =>
      _key.startsWith('sb_secret_') || _key.contains('service_role');
}
