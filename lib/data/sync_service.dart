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
      await _reconcile();
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
      final sent = r['payload'] as String;
      final op = (r['op'] ?? 'upsert') as String;
      final payload = Map<String, dynamic>.from(jsonDecode(sent) as Map);
      for (final k in serverOnly[entity] ?? const <String>[]) {
        payload.remove(k);
      }
      try {
        await _send(entity, op, payload);
        await Store.outboxDone(seq, entity, r['rid'] as String, sent);
      } on PostgrestException catch (e) {
        // Login expired: stop and retry later instead of marking the change as rejected.
        if (e.code == 'PGRST301' || e.code == 'PGRST303') rethrow;
        // The server answered and said no (rule or permission). Keep the data, try later.
        await Store.outboxFail(seq, e.message);
      }
      // Network errors are not caught here: they stop the sync and retry next time.
    }
  }

  /// New rows use INSERT, changes to existing rows use UPDATE. (An "upsert" would need an INSERT
  /// permission even for plain edits, which employees must not have for leads and tasks.)
  Future<void> _send(String entity, String op, Map<String, dynamic> payload) async {
    if (op == 'upsert') {
      await _sb.from(entity).upsert(payload);
      return;
    }
    if (op == 'insert') {
      try {
        await _sb.from(entity).insert(payload);
        return;
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // 23505 = already uploaded earlier; continue as an update
      }
    }
    final rows = await _sb.from(entity).update(payload).eq('id', payload['id']).select('id');
    if (rows.isEmpty) {
      throw PostgrestException(
        message: 'Not saved: the record is missing or you no longer have permission '
            '(for example it was reassigned).',
        code: 'LEDIHA_NOT_SAVED',
      );
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

  /// Employees: drop local copies of records they can no longer see (reassigned leads, tasks...).
  /// Checked at most every 10 minutes; admins can see everything so they skip it.
  Future<void> _reconcile() async {
    if (AppAuth.instance.isAdmin) return;
    final last = DateTime.tryParse(await Store.getMeta('last_reconcile') ?? '');
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) return;
    for (final e in ['leads', 'followups', 'tasks']) {
      final ids = <String>{};
      var from = 0;
      while (true) {
        final rows = await _sb.from(e).select('id').order('id').range(from, from + 999);
        ids.addAll(rows.map((r) => r['id'].toString()));
        if (rows.length < 1000) break;
        from += 1000;
      }
      await Store.pruneMissing(e, ids);
    }
    await Store.setMeta('last_reconcile', DateTime.now().toIso8601String());
  }
}
