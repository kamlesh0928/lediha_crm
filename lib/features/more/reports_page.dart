import 'package:flutter/material.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/csv_export.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../tasks/tasks_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  Future<Map<String, dynamic>> _load() async => {
        'leads': await Q.leads(),
        'tasks': await Q.tasks(),
        'names': await Q.names(),
        'fin': await Q.finance(),
      };

  Map<String, int> _count(List<Rec> rows, String Function(Rec) key) {
    final m = <String, int>{};
    for (final r in rows) {
      m[key(r)] = (m[key(r)] ?? 0) + 1;
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Widget _block(String title, Map<String, int> counts) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(title),
      if (counts.isEmpty) const Text('No data', style: TextStyle(color: Colors.grey)),
      for (final e in counts.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 120, child: Text(e.key, overflow: TextOverflow.ellipsis)),
            Expanded(
                child: LinearProgressIndicator(
                    value: total == 0 ? 0 : e.value / total, minHeight: 10)),
            SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.end)),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Live<Map<String, dynamic>>(
        load: _load,
        builder: (context, d) {
          final leads = d['leads'] as List<Rec>;
          final tasks = d['tasks'] as List<Rec>;
          final names = d['names'] as Map<String, String>;
          final fin = d['fin'] as List<Rec>;
          final days = <String, double>{};
          for (final r in fin) {
            final k = (r['entry_date'] ?? '').toString();
            days[k] = (days[k] ?? 0) + (r['kind'] == 'income' ? 1 : -1) * toNum(r['amount']);
          }
          final lastDays = days.keys.toList()..sort((a, b) => b.compareTo(a));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export leads CSV'),
                  onPressed: () => CsvExport.share(['leads'])),
              OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Attendance CSV'),
                  onPressed: () => CsvExport.share(['attendance'])),
              OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Tasks CSV'),
                  onPressed: () => CsvExport.share(['tasks'])),
              OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Income/expense CSV'),
                  onPressed: () => CsvExport.share(['finance_entries'])),
            ]),
            _block('Leads by status', _count(leads, (l) => label(str(l['status'])))),
            _block('Leads by source', _count(leads, (l) => label(str(l['source'])))),
            _block('Leads by employee',
                _count(leads, (l) => names[l['assigned_to']] ?? 'Unassigned')),
            _block('Tasks by status', _count(tasks, (t) => isOverdue(t) ? 'Overdue' : label(str(t['status'])))),
            _block('Tasks by employee', _count(tasks, (t) => names[t['assigned_to']] ?? '-')),
            const SectionTitle('Net money per day (latest 10)'),
            if (lastDays.isEmpty) const Text('No entries yet', style: TextStyle(color: Colors.grey)),
            for (final k in lastDays.take(10))
              ListTile(dense: true, title: Text(k), trailing: Text(money(days[k]!))),
          ]);
        },
      ),
    );
  }
}
