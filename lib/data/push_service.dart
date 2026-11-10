import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/permissions.dart';
import 'store.dart';
import 'sync_service.dart';

/// Push notifications (Firebase Cloud Messaging). Completely optional: if Firebase is not set up
/// (no android/app/google-services.json) everything here quietly does nothing.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _listening = false;

  /// Called once after sign-in. Asks for the notification permission (with our explanation) only
  /// the first time; afterwards the user can change it under More > App permissions.
  Future<void> start(BuildContext context) async {
    if (await Permissions.state(AppPermission.notifications) != PermState.granted) {
      if (await Store.getMeta('notif_asked') == '1') return; // do not nag
      await Store.setMeta('notif_asked', '1');
      if (!context.mounted) return;
      final r = await Permissions.ask(context, AppPermission.notifications);
      if (r != AskResult.granted) return;
    }
    await register();
  }

  /// Gets this phone's token and stores it on the server for the signed-in person.
  Future<void> register() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      final token = await fm.getToken();
      if (token == null) return;
      await _upload(token);
      if (!_listening) {
        _listening = true;
        fm.onTokenRefresh.listen(_upload);
        // App open: refresh data right away so the bell and lists update.
        FirebaseMessaging.onMessage.listen((_) => SyncService.instance.syncSoon());
      }
    } catch (e) {
      debugPrint('Push not available: $e');
    }
  }

  Future<void> _upload(String token) async {
    try {
      await Supabase.instance.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('Could not save push token (will retry next start): $e');
    }
  }

  /// On logout: stop sending this person's alerts to this phone (gives up after 5 seconds offline).
  Future<void> unregister() async {
    try {
      await _unregister().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _unregister() async {
    if (Firebase.apps.isEmpty) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await Supabase.instance.client.rpc('unregister_device_token', params: {'p_token': token});
    }
  }
}
