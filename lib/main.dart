import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config_error.dart';
import 'core/env.dart';
import 'data/app_auth.dart';
import 'data/store.dart';
import 'data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  if (!Env.isConfigured) {
    runApp(const ConfigErrorApp());
    return;
  }
  if (Env.looksLikeSecretKey) {
    runApp(const ConfigErrorApp(
      details: 'The key in your config looks like a SECRET key. Use the PUBLISHABLE key '
          '(starts with sb_publishable_). Secret keys must never be placed in the app.',
    ));
    return;
  }
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
    await Store.init();
    await AppAuth.instance.init();
  } catch (e) {
    runApp(ConfigErrorApp(details: 'Start-up failed: $e'));
    return;
  }
  SyncService.instance.start();
  runApp(const LedihaApp());
}
