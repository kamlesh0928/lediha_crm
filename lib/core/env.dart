/// Values come from `--dart-define-from-file=env.json` (see README).
/// Only the public anon/publishable key belongs here - NEVER the service_role key.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
