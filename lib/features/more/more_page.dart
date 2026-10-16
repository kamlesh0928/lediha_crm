import 'package:flutter/material.dart';
import '../../core/util.dart';
import '../../data/auth_state.dart';
import '../../data/csv_export.dart';
import '../../data/store.dart';
import '../../data/sync_service.dart';
import '../../core/widgets.dart';
import '../attendance/attendance_page.dart';
import '../employees/employees_page.dart';
import '../finance/finance_page.dart';
import '../location/team_map_page.dart';
import '../tasks/tasks_page.dart';
import 'notifications_page.dart';
import 'online_list_page.dart';
import 'reports_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final a = AuthState.instance;
    Widget tile(IconData i, String t, VoidCallback f, {String? sub}) => ListTile(
        leading: Icon(i), title: Text(t), subtitle: sub == null ? null : Text(sub), onTap: f);
    return ListView(children: [
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(a.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(label(a.role)),
      ),
      const Divider(),
      tile(Icons.task_alt, 'Tasks', () => _go(context, const TasksPage())),
      tile(Icons.access_time, 'Attendance', () => _go(context, const AttendancePage())),
      tile(Icons.payments_outlined, 'Income & expenses', () => _go(context, const FinancePage())),
      tile(Icons.notifications_none, 'Notifications', () => _go(context, const NotificationsPage())),
      if (a.isAdmin) ...[
        const Divider(),
        tile(Icons.map_outlined, 'Team location', () => _go(context, const TeamMapPage())),
        tile(Icons.badge_outlined, 'Employees', () => _go(context, const EmployeesPage())),
        tile(Icons.bar_chart, 'Reports', () => _go(context, const ReportsPage())),
        tile(Icons.hub_outlined, 'Facebook / Instagram / WhatsApp log',
            () => _go(context, OnlineListPage(title: 'Lead sources log', table: 'meta_events', orderBy: 'received_at', tile: metaEventTile))),
        tile(Icons.history, 'Audit log',
            () => _go(context, OnlineListPage(title: 'Audit log', table: 'audit_logs', orderBy: 'created_at', tile: auditTile))),
      ],
      const Divider(),
      if (a.isAdmin)
        tile(Icons.file_download_outlined, 'Export ALL data (CSV)', () async {
          final n = await CsvExport.share(CsvExport.all);
          if (context.mounted && n == 0) toast(context, 'Nothing to export yet.');
        }, sub: 'Also saved on this phone every day you open the app'),
      ValueListenableBuilder<String>(
        valueListenable: SyncService.instance.status,
        builder: (_, s, __) => ValueListenableBuilder<int>(
          valueListenable: Store.pendingCount,
          builder: (_, n, __) => tile(Icons.sync, 'Sync now', () => SyncService.instance.syncAll(),
              sub: '$s${n > 0 ? '\n$n change(s) waiting to upload' : ''}'),
        ),
      ),
      FutureBuilder<int>(
        future: Store.failedCount(),
        builder: (context, snap) => (snap.data ?? 0) > 0
            ? tile(Icons.warning_amber, 'Some changes could not sync (${snap.data})', () async {
                if (await confirmDialog(context, 'Discard rejected changes?',
                    'These edits were refused by the server (for example, a lead that was reassigned). They will be removed from this phone.')) {
                  await Store.discardFailed();
                  SyncService.instance.syncAll();
                }
              }, sub: 'Tap to review')
            : const SizedBox.shrink(),
      ),
      tile(Icons.logout, 'Log out', () async {
        final n = Store.pendingCount.value;
        final ok = await confirmDialog(
            context,
            'Log out?',
            n > 0
                ? '$n change(s) are not uploaded yet. They stay on this phone and upload when you log in again with the same account.'
                : 'You will need to sign in again.');
        if (ok) await AuthState.instance.logout();
      }),
      const SizedBox(height: 24),
    ]);
  }
}
