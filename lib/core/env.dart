import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Supabase connection settings.
///
/// Two ways to provide them (the first one found wins):
///  1. `--dart-define-from-file=env.json` on the run/build command (good for CI and release builds)
///  2. the file `assets/config/env.json` (git-ignored; simplest for daily work - just press Run)
///
/// NOTE: `assets/config/env.json` is packed INTO the app when it is built. Adding or editing the
/// file does nothing for an app that is already installed - you must rebuild and reinstall
/// (`flutter run` again, or `flutter build apk`), not just hot-restart.
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
  static String _problem = '';

  /// Human-readable reason why the settings could not be loaded (empty when fine).
  static String get problem => _problem;

  /// Call once at start-up, before reading the values below.
  static Future<void> load() async {
    _problem = '';
    _url = _urlDefine.trim();
    _key = (_publishableDefine.isNotEmpty ? _publishableDefine : _legacyDefine).trim();
    if (_url.isNotEmpty && _key.isNotEmpty) return;

    String raw;
    try {
      raw = await rootBundle.loadString('assets/config/env.json');
    } catch (_) {
      _problem = 'assets/config/env.json is NOT inside this build of the app.\n'
          '- Check the exact name: it must be env.json, not env.json.txt '
          '(Windows hides extensions by default).\n'
          '- Check the folder: <project>/assets/config/env.json (not the project root, not lib/).\n'
          '- Then STOP the app and rebuild/reinstall it (flutter run). '
          'Hot restart or opening an old install will not pick the file up.';
      return;
    }

    try {
      // Strip a UTF-8 BOM and zero-width characters that Notepad/PowerShell can add,
      // and replace "smart quotes" that appear when text is pasted from chat/Word.
      raw = raw
          .replaceAll('\uFEFF', '')
          .replaceAll('\u200B', '')
          .replaceAll('\u201C', '"')
          .replaceAll('\u201D', '"')
          .trim();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _problem = 'env.json must be a JSON object { ... }.';
        return;
      }
      final data = Map<String, dynamic>.from(decoded);
      if (_url.isEmpty) _url = (data['SUPABASE_URL'] ?? '').toString().trim();
      if (_key.isEmpty) {
        _key = (data['SUPABASE_PUBLISHABLE_KEY'] ?? data['SUPABASE_ANON_KEY'] ?? '')
            .toString()
            .trim();
      }
    } catch (e) {
      _problem = 'env.json was found but is not valid JSON ($e).\n'
          'Check for a missing/extra comma or a missing quote.';
      return;
    }

    if (_url.isEmpty) {
      _problem = 'env.json has no SUPABASE_URL (key name must be exactly SUPABASE_URL).';
    } else if (!_url.startsWith('https://')) {
      _problem = 'SUPABASE_URL must start with https:// (got "${_url.length > 40 ? _url.substring(0, 40) : _url}").';
    } else if (_url.contains('YOUR-PROJECT') || _url.contains('xxxx')) {
      _problem = 'SUPABASE_URL is still the example value.';
    } else if (_key.isEmpty) {
      _problem = 'env.json has no SUPABASE_PUBLISHABLE_KEY (key name must be exactly that).';
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
