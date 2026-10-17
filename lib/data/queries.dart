import 'app_auth.dart';
import 'store.dart';

typedef Rec = Map<String, dynamic>;

/// Read helpers. Employees only ever see their own records (the database enforces
/// this too - this is just so stale cached rows disappear from their screens).
class Q {
  static AppAuth get _me => AppAuth.instance;

  static List<Rec> sorted(List<Rec> l, String key, {bool desc = true}) {
    l.sort((a, b) {
      final x = (a[key] ?? '').toString(), y = (b[key] ?? '').toString();
      return desc ? y.compareTo(x) : x.compareTo(y);
    });
    return l;
  }

  static Future<List<Rec>> leads() async {
    final rows = (await Store.all('leads')).where((r) => r['is_deleted'] != true);
    final mine = _me.isAdmin ? rows : rows.where((r) => r['assigned_to'] == _me.uid);
    return sorted(mine.toList(), 'created_at');
  }

  static Future<List<Rec>> followups() async {
    final rows = await Store.all('followups');
    final mine = _me.isAdmin ? rows : rows.where((r) => r['assigned_to'] == _me.uid).toList();
    return sorted(mine.toList(), 'scheduled_at', desc: false);
  }

  static Future<List<Rec>> tasks() async {
    final rows = await Store.all('tasks');
    final mine = _me.isAdmin ? rows : rows.where((r) => r['assigned_to'] == _me.uid).toList();
    return sorted(mine.toList(), 'due_at', desc: false);
  }

  static Future<List<Rec>> attendance() async {
    final rows = await Store.all('attendance');
    final mine = _me.isAdmin ? rows : rows.where((r) => r['user_id'] == _me.uid).toList();
    return sorted(mine.toList(), 'work_date');
  }

  static Future<List<Rec>> finance() async {
    final rows = (await Store.all('finance_entries')).where((r) => r['is_deleted'] != true);
    final mine = _me.isAdmin ? rows : rows.where((r) => r['created_by'] == _me.uid);
    return sorted(mine.toList(), 'created_at');
  }

  static Future<List<Rec>> notifications() async {
    final rows = (await Store.all('notifications')).where((r) => r['user_id'] == _me.uid);
    return sorted(rows.toList(), 'created_at');
  }

  static Future<List<Rec>> profiles() async =>
      sorted(await Store.all('profiles'), 'full_name', desc: false);

  /// Active people (for assignment and chat).
  static Future<List<Rec>> staff() async =>
      (await profiles()).where((p) => p['is_active'] == true).toList();

  static Future<Map<String, String>> names() async => {
        for (final p in await Store.all('profiles')) p['id'].toString(): (p['full_name'] ?? '').toString()
      };

  static Future<Map<String, Rec>> leadsById() async =>
      {for (final l in await Store.all('leads')) l['id'].toString(): l};
}
