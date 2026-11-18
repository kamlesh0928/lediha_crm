import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/csv_export.dart';
import '../../data/store.dart';
import '../../data/sync_service.dart';
import '../attendance/attendance_page.dart';
import '../employees/employees_page.dart';
import '../finance/finance_page.dart';
import '../leads/lead_import_page.dart';
import '../location/my_location_page.dart';
import '../location/team_map_page.dart';
import '../tasks/tasks_page.dart';
import 'notifications_page.dart';
import 'online_list_page.dart';
import 'permissions_page.dart';
import 'reports_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final a = AppAuth.instance;

    Widget sectionHeader(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        );

    Widget tile(IconData i, String t, VoidCallback f, {String? sub, Widget? trailing, Color? iconColor}) =>
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.brandRed).withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(i, color: iconColor ?? AppColors.brandRed, size: 20),
          ),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 12)),
          trailing: trailing ?? const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          onTap: f,
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        // Branded Profile Header
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandRed, AppColors.brandYellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    (a.name ?? 'L').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name ?? 'Staff User',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Pill(
                          label(a.role),
                          color: a.isAdmin ? AppColors.brandRed : AppColors.brandTeal,
                          icon: a.isAdmin ? Icons.admin_panel_settings : Icons.handyman,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LEDiHA CRM',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // TV Service Section
        sectionHeader('Service & Field Operations'),
        tile(Icons.task_alt, 'Service Tasks', () => _go(context, const TasksPage()),
            sub: 'TV repairs, board replacements & parts assignments'),
        tile(Icons.access_time, 'Attendance & Shifts', () => _go(context, const AttendancePage()),
            sub: 'Check-in, check-out and shift history'),
        tile(
          Icons.my_location,
          'My Location & Route',
          () => _go(context, const MyLocationPage()),
          sub: 'Live GPS tracking, route of the day & GPS toggle',
          iconColor: AppColors.brandTeal,
        ),
        tile(Icons.payments_outlined, 'Cash Book (Income & Expenses)', () => _go(context, const FinancePage()),
            sub: 'Repair payments received, advance and spare parts cost'),

        // Admin Management Section
        if (a.isAdmin) ...[
          sectionHeader('Admin Controls'),
          tile(
            Icons.map_outlined,
            'Team Live Tracking (GPS)',
            () => _go(context, const TeamMapPage()),
            sub: 'View all field technicians live on map and route history',
            iconColor: AppColors.brandTeal,
          ),
          tile(Icons.badge_outlined, 'Employee Management', () => _go(context, const EmployeesPage()),
              sub: 'Add technicians, passwords & active status'),
          tile(Icons.upload_file, 'Import Leads (CSV / Excel)', () => _go(context, const LeadImportPage()),
              sub: 'Bulk upload customer inquiries & phone numbers'),
          tile(Icons.bar_chart, 'Reports & Analytics', () => _go(context, const ReportsPage()),
              sub: 'Leads by brand/source, technician workload & daily cash'),
          tile(Icons.hub_outlined, 'Social Media Leads Log',
              () => _go(context, OnlineListPage(title: 'Meta & WhatsApp Log', table: 'meta_events', orderBy: 'received_at', tile: metaEventTile)),
              sub: 'Facebook, Instagram & WhatsApp webhook events'),
          tile(Icons.history, 'System Audit Log',
              () => _go(context, OnlineListPage(title: 'Audit Log', table: 'audit_logs', orderBy: 'created_at', tile: auditTile)),
              sub: 'Full history of changes and deletions'),
          tile(Icons.file_download_outlined, 'Export All Data (CSV)', () async {
            final n = await CsvExport.share(CsvExport.all);
            if (context.mounted && n == 0) toast(context, 'Nothing to export yet.');
          }, sub: 'Share database backup files to WhatsApp/Drive'),
        ],

        // App & System Section
        sectionHeader('App Settings & Sync'),
        tile(Icons.notifications_none, 'Notifications', () => _go(context, const NotificationsPage()),
            sub: 'Task and lead assignment alerts'),
        tile(Icons.privacy_tip_outlined, 'App Permissions', () => _go(context, const PermissionsPage()),
            sub: 'GPS Location & Push Notification settings'),

        ValueListenableBuilder<String>(
          valueListenable: SyncService.instance.status,
          builder: (_, s, _) => ValueListenableBuilder<int>(
            valueListenable: Store.pendingCount,
            builder: (_, n, _) => tile(
              Icons.sync,
              'Sync Database Now',
              () => SyncService.instance.syncAll(),
              sub: '$s${n > 0 ? ' \u00B7 $n changes waiting' : ''}',
              iconColor: Colors.blue.shade700,
            ),
          ),
        ),

        FutureBuilder<int>(
          future: Store.failedCount(),
          builder: (context, snap) => (snap.data ?? 0) > 0
              ? tile(
                  Icons.warning_amber,
                  'Discard Rejected Syncs (${snap.data})',
                  () async {
                    if (await confirmDialog(
                      context,
                      'Discard rejected changes?',
                      'These edits were refused by the server. They will be removed from this phone.',
                    )) {
                      await Store.discardFailed();
                      SyncService.instance.syncAll();
                    }
                  },
                  sub: 'Tap to review and clear',
                  iconColor: Colors.orange,
                )
              : const SizedBox.shrink(),
        ),

        tile(
          Icons.logout,
          'Log Out',
          () async {
            final n = Store.pendingCount.value;
            final ok = await confirmDialog(
              context,
              'Log Out of LEDiHA CRM?',
              n > 0
                  ? '$n offline change(s) are not uploaded yet. They stay on this phone until you log in again.'
                  : 'You will need your password to log in again.',
            );
            if (ok) await AppAuth.instance.logout();
          },
          sub: 'Signed in as ${a.name ?? ''}',
          iconColor: Colors.red,
        ),

        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              Image.asset('assets/images/logo.png', height: 32, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              const SizedBox(height: 4),
              const Text(
                'LEDiHA CRM v1.0.0 \u00B7 Your TV Repair Partner',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
