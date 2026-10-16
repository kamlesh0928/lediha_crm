import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Local-first storage. Every screen reads from here (works offline).
/// Every write lands here first, then waits in the outbox until it reaches Supabase.
class Store {
  static late Database _db;

  /// Bumped on every change so screens (see `Live`) reload.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  /// Number of changes still waiting to be uploaded.
  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Set by SyncService so a local write triggers an upload attempt.
  static VoidCallback? onLocalWrite;

  static Future<void> init() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'lediha.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute('CREATE TABLE cache(entity TEXT NOT NULL, id TEXT NOT NULL, '
            'json TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(entity, id))');
        await d.execute('CREATE TABLE outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, '
            'entity TEXT NOT NULL, rid TEXT NOT NULL, payload TEXT NOT NULL, '
            'attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT)');
        await d.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
      },
    );
    await _refreshPending();
  }

  static Future<void> _refreshPending() async {
    pendingCount.value =
        Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM outbox')) ?? 0;
  }

  // ---------- reads ----------
  static Future<List<Map<String, dynamic>>> all(String entity) async {
    final rows =
        await _db.query('cache', columns: ['json'], where: 'entity = ?', whereArgs: [entity]);
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['json'] as String) as Map))
        .toList();
  }

  static Future<Map<String, dynamic>?> byId(String entity, String id) async {
    final rows = await _db.query('cache',
        columns: ['json'], where: 'entity = ? AND id = ?', whereArgs: [entity, id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['json'] as String) as Map);
  }

  // ---------- writes ----------
  /// Save a row locally and queue it for upload. [cache] = false is for high-volume,
  /// write-only data (location pings) that does not need to be kept on the phone.
  static Future<void> put(String entity, Map<String, dynamic> row, {bool cache = true}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    row['id'] ??= const Uuid().v4();
    row['created_at'] ??= now;
    row['updated_at'] = now;
    final id = row['id'].toString();
    await _db.transaction((txn) async {
      if (cache) {
        await txn.insert(
          'cache',
          {'entity': entity, 'id': id, 'json': jsonEncode(row), 'dirty': 1},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      // Coalesce: only the newest full copy of a row needs to be uploaded.
      await txn.delete('outbox', where: 'entity = ? AND rid = ?', whereArgs: [entity, id]);
      await txn.insert('outbox', {'entity': entity, 'rid': id, 'payload': jsonEncode(row)});
    });
    await _refreshPending();
    version.value++;
    onLocalWrite?.call();
  }

  /// Store rows received from the server. Rows with unsent local edits are left alone.
  static Future<void> merge(String entity, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _db.transaction((txn) async {
      for (final r in rows) {
        final id = r['id'].toString();
        final ex = await txn.query('cache',
            columns: ['dirty'], where: 'entity = ? AND id = ?', whereArgs: [entity, id]);
        if (ex.isNotEmpty && ex.first['dirty'] == 1) continue;
        await txn.insert(
          'cache',
          {'entity': entity, 'id': id, 'json': jsonEncode(r), 'dirty': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    version.value++;
  }

  // ---------- outbox ----------
  static Future<List<Map<String, Object?>>> outbox() => _db.query('outbox', orderBy: 'seq');

  static Future<void> outboxDone(int seq, String entity, String rid) async {
    await _db.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
    final left = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM outbox WHERE entity = ? AND rid = ?', [entity, rid])) ??
        0;
    if (left == 0) {
      await _db.rawUpdate(
          'UPDATE cache SET dirty = 0 WHERE entity = ? AND id = ?', [entity, rid]);
    }
    await _refreshPending();
  }

  static Future<void> outboxFail(int seq, String err) async {
    await _db.rawUpdate(
        'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE seq = ?', [err, seq]);
  }

  static Future<int> failedCount() async =>
      Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM outbox WHERE attempts > 2')) ??
      0;

  /// Gives up on changes the server keeps rejecting, then re-downloads everything.
  static Future<void> discardFailed() async {
    final bad = await _db.query('outbox', where: 'attempts > 2');
    for (final r in bad) {
      await _db.rawUpdate('UPDATE cache SET dirty = 0 WHERE entity = ? AND id = ?',
          [r['entity'], r['rid']]);
    }
    await _db.delete('outbox', where: 'attempts > 2');
    await _db.delete('meta', where: "k LIKE 'cursor_%'");
    await _refreshPending();
    version.value++;
  }

  // ---------- meta ----------
  static Future<String?> getMeta(String k) async {
    final r = await _db.query('meta', where: 'k = ?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  static Future<void> setMeta(String k, String v) async {
    await _db.insert('meta', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Used when a different person logs in on the same phone.
  static Future<void> wipe() async {
    await _db.delete('cache');
    await _db.delete('outbox');
    await _db.delete('meta');
    await _refreshPending();
    version.value++;
  }
}
