import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/util.dart';
import 'app_auth.dart';
import 'queries.dart';
import 'store.dart';

/// Writes readable CSV files from the data on the phone (works fully offline).
class CsvExport {
  static const all = [
    'leads', 'followups', 'tasks', 'attendance', 'finance_entries',
    'messages', 'profiles', 'notifications',
  ];

  static const _personCols = {
    'assigned_to', 'created_by', 'user_id', 'sender_id', 'recipient_id', 'corrected_by'
  };

  static Future<Directory> _dir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'exports', dateKey(DateTime.now())));
    await d.create(recursive: true);
    return d;
  }

  static Future<List<File>> write(List<String> entities) async {
    final names = await Q.names();
    final dir = await _dir();
    final files = <File>[];
    for (final e in entities) {
      final rows = await Store.all(e);
      if (rows.isEmpty) continue;
      final keys = <String>{};
      for (final r in rows) {
        keys.addAll(r.keys);
      }
      final cols = ['id', ...(keys.where((k) => k != 'id').toList()..sort())];
      final personCols = cols.where(_personCols.contains).toList();
      final data = <List<dynamic>>[
        [...cols, ...personCols.map((k) => '${k}_name')]
      ];
      for (final r in rows) {
        data.add([
          ...cols.map((k) => r[k]),
          ...personCols.map((k) => names[r[k]] ?? ''),
        ]);
      }
      final f = File(p.join(dir.path, '$e.csv'));
      // BOM so Excel opens Hindi/Unicode text correctly.
      await f.writeAsString('\uFEFF${const ListToCsvConverter().convert(data)}');
      files.add(f);
    }
    return files;
  }

  static Future<int> share(List<String> entities) async {
    final files = await write(entities);
    if (files.isEmpty) return 0;
    await Share.shareXFiles(files.map((f) => XFile(f.path)).toList(),
        subject: 'LEDiHA CRM export');
    return files.length;
  }

  /// Admin phone keeps a fresh CSV copy of everything once a day (when the app is used).
  static Future<void> autoDaily() async {
    if (!AppAuth.instance.isAdmin) return;
    final today = dateKey(DateTime.now());
    if (await Store.getMeta('last_auto_export') == today) return;
    try {
      await write(all);
      await Store.setMeta('last_auto_export', today);
    } catch (_) {}
  }
}
