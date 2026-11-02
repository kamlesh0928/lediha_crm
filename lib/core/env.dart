/// Values come from `--dart-define-from-file=env.json` (see README).
/// Only the PUBLISHABLE key (starts with sb_publishable_) belongs in the app.
/// NEVER put the secret key (sb_secret_...) or the old service_role key here.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  // Old name, still accepted so existing env.json files keep working.
  static const _legacyName = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabasePublishableKey =>
      _publishable.isNotEmpty ? _publishable : _legacyName;

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;
}
