import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../attendance/attendance_page.dart';
import '../finance/finance_page.dart';
import '../followups/followups_page.dart';
import '../leads/lead_form_page.dart';
import '../location/my_location_page.dart';
import '../location/team_map_page.dart';
import '../tasks/tasks_page.dart';

/// [onGo] switches the bottom tab: 1 = Leads, 2 = Follow-ups.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onGo});
  final void Function(int tab) onGo;

  Future<Map<String, dynamic>> _load() async => {
        'leads': await Q.leads(),
        'fus': await Q.followups(),
        'tasks': await Q.tasks(),
        'att': await Q.attendance(),
        'people': await Q.staff(),
        'fin': await Q.finance(),
      };

  @override
  Widget build(BuildContext context) {
    final admin = AppAuth.instance.isAdmin;
    final userName = AppAuth.instance.name ?? 'Team Member';

    return Live<Map<String, dynamic>>(
      load: _load,
      builder: (context, d) {
        final leads = d['leads'] as List<Rec>;
        final fus = d['fus'] as List<Rec>;
        final tasks = d['tasks'] as List<Rec>;
        final att = d['att'] as List<Rec>;
        final people = d['people'] as List<Rec>;
        final fin = d['fin'] as List<Rec>;
        final today = dateKey(DateTime.now());
        final end = endOfToday();

        bool isOpen(Rec l) => l['status'] != 'converted' && l['status'] != 'lost';
        final openLeads = leads.where(isOpen).toList();
        final dueFus = fus.where((f) => f['status'] != 'done' && parseDt(f['scheduled_at'])!.isBefore(end)).toList();
        final openTasks = tasks.where((t) => t['status'] != 'completed').toList();
        final overdueTasks = tasks.where(isOverdue).toList();
        final hot = openLeads.where((l) => l['priority'] == 'hot').length;

        // Specific TV repair follow-up lists
        final pickups = fus.where((f) => f['kind'] == 'pickup' && f['status'] != 'done').length;
        final workPending = fus.where((f) => f['kind'] == 'work_pending' && f['status'] != 'done').length;
        final workDone = fus.where((f) => f['kind'] == 'work_done' && f['status'] != 'done').length;
        final deliveries = fus.where((f) => f['kind'] == 'delivery' && f['status'] != 'done').length;

        final cards = <Widget>[
          if (admin) ...[
            Kpi('New TV Inquiries', '${leads.where((l) => l['status'] == 'new').length}',
                color: AppColors.statusNew, icon: Icons.tv, onTap: () => onGo(1)),
            Kpi('Hot TV Leads', '$hot',
                color: AppColors.brandRed, icon: Icons.local_fire_department, onTap: () => onGo(2)),
            Kpi("Today's Pickups", '$pickups',
                color: AppColors.statusContacted, icon: Icons.local_shipping, onTap: () => onGo(2)),
            Kpi('Workshop Pending', '$workPending',
                color: AppColors.brandTeal, icon: Icons.build_circle, onTap: () => onGo(2)),
            Kpi('Ready for Delivery', '$workDone',
                color: Colors.green.shade700, icon: Icons.check_circle, onTap: () => onGo(2)),
            Kpi('Pending Deliveries', '$deliveries',
                color: Colors.indigo, icon: Icons.home_repair_service, onTap: () => onGo(2)),
            Kpi('Active Technicians',
                '${att.where((a) => a['work_date'] == today && a['check_in_at'] != null).length}/${people.where((p) => p['role'] == 'employee').length}',
                color: AppColors.brandRedDark,
                icon: Icons.person_pin_circle,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamMapPage()))),
            Kpi('Net Cash Today',
                money(fin.where((r) => r['entry_date'] == today).fold(
                    0.0, (a, r) => a + (r['kind'] == 'income' ? 1 : -1) * toNum(r['amount']))),
                color: Colors.teal.shade800,
                icon: Icons.payments,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePage()))),
          ] else ...[
            Kpi('My Assigned Leads', '${openLeads.length}',
                color: AppColors.statusNew, icon: Icons.tv, onTap: () => onGo(1)),
            Kpi('Hot TV Leads', '$hot',
                color: AppColors.brandRed, icon: Icons.local_fire_department, onTap: () => onGo(2)),
            Kpi('Follow-ups Due', '${dueFus.length}',
                color: Colors.purple, icon: Icons.event_available, onTap: () => onGo(2)),
            Kpi('My Service Tasks', '${openTasks.length}${overdueTasks.isNotEmpty ? ' (${overdueTasks.length} overdue)' : ''}',
                color: overdueTasks.isNotEmpty ? Colors.red : AppColors.brandTeal, icon: Icons.handyman,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()))),
          ],
        ];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            // Welcome & Brand Banner
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandRed, Color(0xFFC62828)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandRed.withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $userName \u{1F44B}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              admin
                                  ? 'Workshop & Field Service Management'
                                  : 'Field Service Technician',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.brandYellowLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.today, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              fmtDate(DateTime.now()),
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (admin)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16, color: AppColors.brandRed),
                          label: const Text('Add TV Lead', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          backgroundColor: Colors.white,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LeadFormPage()),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.map, size: 16, color: AppColors.brandTeal),
                        label: Text(
                          admin ? 'Live Technician Map' : 'My GPS Route',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        backgroundColor: Colors.white,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => admin ? const TeamMapPage() : const MyLocationPage(),
                          ),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.handyman, size: 16, color: AppColors.brandYellowDark),
                        label: const Text('Tasks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        backgroundColor: Colors.white,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TasksPage()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Employee Check-in Card (with live GPS status)
            if (!admin) ...[
              const AttendanceControl(),
              const SizedBox(height: 8),
            ],

            // KPI Grid
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cards,
            ),

            const SizedBox(height: 4),

            // Next TV Follow-ups Section
            SectionTitle(
              'Next TV Follow-ups & Deliveries',
              trailing: TextButton(
                onPressed: () => onGo(2),
                child: const Text('View All', style: TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const FollowupList(kind: 'today', limit: 5),
          ],
        );
      },
    );
  }
}
