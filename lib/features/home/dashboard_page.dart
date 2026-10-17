import 'package:flutter/material.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../attendance/attendance_page.dart';
import '../followups/followups_page.dart';
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

        final cards = <Widget>[
          if (admin) ...[
            Kpi('New leads', '${leads.where((l) => l['status'] == 'new').length}', onTap: () => onGo(1)),
            Kpi('Unassigned', '${openLeads.where((l) => l['assigned_to'] == null).length}',
                color: Colors.orange.shade800, onTap: () => onGo(1)),
            Kpi('Follow-ups due', '${dueFus.length}', color: Colors.purple, onTap: () => onGo(2)),
            Kpi('Hot leads', '$hot', color: Colors.deepOrange, onTap: () => onGo(2)),
            Kpi('Present today',
                '${att.where((a) => a['work_date'] == today && a['check_in_at'] != null).length}/${people.where((p) => p['role'] == 'employee').length}'),
            Kpi('Open tasks', '${openTasks.length}',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()))),
            Kpi('Overdue tasks', '${overdueTasks.length}', color: Colors.red),
            Kpi(
                'Net today',
                money(fin.where((r) => r['entry_date'] == today).fold(
                    0.0, (a, r) => a + (r['kind'] == 'income' ? 1 : -1) * toNum(r['amount'])))),
          ] else ...[
            Kpi('My open leads', '${openLeads.length}', onTap: () => onGo(1)),
            Kpi('Follow-ups due', '${dueFus.length}', color: Colors.purple, onTap: () => onGo(2)),
            Kpi('Hot leads', '$hot', color: Colors.deepOrange, onTap: () => onGo(2)),
            Kpi('My open tasks', '${openTasks.length}',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()))),
          ],
        ];
        return ListView(padding: const EdgeInsets.all(12), children: [
          if (!admin) const AttendanceControl(),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cards,
          ),
          const SectionTitle('Next follow-ups'),
          const FollowupList(kind: 'today', limit: 5),
        ]);
      },
    );
  }
}
