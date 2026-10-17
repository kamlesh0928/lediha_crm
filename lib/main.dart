import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/env.dart';
import 'data/app_auth.dart';
import 'data/store.dart';
import 'data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  await Store.init();
  await AppAuth.instance.init();
  SyncService.instance.start();
  runApp(const LedihaApp());
}
