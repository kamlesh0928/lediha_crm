import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_auth.dart';
import 'csv_export.dart';
import 'store.dart';

/// Two-way sync: upload the outbox, then download what changed on the server.
/// Safe to call any time - it does nothing when offline or already running.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Tables copied to every phone (RLS decides which rows each person receives).
  /// location_pings is upload-only on purpose: it is large and the admin map reads it online.
  static const entities = [
    'profiles', 'leads', 'followups', 'tasks', 'attendance',
    'messages', 'finance_entries', 'notifications',
  ];

  /// Columns the database fills in itself - never sent back.
  static const serverOnly = {
    'leads': ['lead_no', 'phone_norm'],
    'tasks': ['task_no'],
  };

  final ValueNotifier<String> status = ValueNotifier('Not synced yet');
  final ValueNotifier<DateTime?> lastSync = ValueNotifier(null);

  SupabaseClient get _sb => Supabase.instance.client;
  bool _busy = false;
  Timer? _debounce;
  RealtimeChannel? _channel;

  void start() {
    Store.onLocalWrite = syncSoon;
    Timer.periodic(const Duration(seconds: 60), (_) => syncAll());
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) syncAll();
    });
    syncAll();
  }

  void syncSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncAll);
  }

  /// Live updates (chat, new leads, notifications) while the app is open.
  void listen() {
    try {
      _channel?.unsubscribe();
      RealtimeChannel ch = _sb.channel('lediha-live');
      for (final t in ['messages', 'notifications', 'leads', 'tasks', 'followups']) {
        ch = ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: t,
          callback: (_) => syncSoon(),
        );
      }
      _channel = ch.subscribe();
    } catch (_) {}
  }

  Future<void> syncAll() async {
    if (_busy || _sb.auth.currentSession == null || !AppAuth.instance.loggedIn) return;
    _busy = true;
    status.value = 'Syncing...';
    try {
      await _push();
      await _pull();
      lastSync.value = DateTime.now();
      status.value = 'Up to date';
      await AppAuth.instance.checkStillActive();
      CsvExport.autoDaily();
    } on PostgrestException catch (e) {
      status.value = 'Server error: ${e.message}';
    } catch (_) {
      status.value = 'Offline - changes are saved on this phone';
    } finally {
      _busy = false;
    }
  }

  Future<void> _push() async {
    for (final r in await Store.outbox()) {
      final entity = r['entity'] as String;
      final seq = r['seq'] as int;
      final payload = Map<String, dynamic>.from(jsonDecode(r['payload'] as String) as Map);
      for (final k in serverOnly[entity] ?? const <String>[]) {
        payload.remove(k);
      }
      try {
        await _sb.from(entity).upsert(payload);
        await Store.outboxDone(seq, entity, r['rid'] as String);
      } on PostgrestException catch (e) {
        // The server answered and said no (rule or permission). Keep the data, try later.
        await Store.outboxFail(seq, e.message);
      }
      // Network errors are not caught here: they stop the sync and retry next time.
    }
  }

  Future<void> _pull() async {
    for (final e in entities) {
      var cursor = await Store.getMeta('cursor_$e');
      String? lastSeen;
      while (true) {
        final c = cursor;
        final rows = c == null
            ? await _sb.from(e).select().order('updated_at', ascending: true).limit(500)
            : await _sb
                .from(e)
                .select()
                .gt('updated_at', c)
                .order('updated_at', ascending: true)
                .limit(500);
        if (rows.isEmpty) break;
        await Store.merge(e, rows);
        lastSeen = rows.last['updated_at'].toString();
        cursor = lastSeen;
        if (rows.length < 500) break;
      }
      if (lastSeen != null) {
        // Small overlap so a row committed late is never missed.
        final back = DateTime.parse(lastSeen).subtract(const Duration(seconds: 5));
        await Store.setMeta('cursor_$e', back.toUtc().toIso8601String());
      }
    }
  }
}
