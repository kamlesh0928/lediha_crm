import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/csv_export.dart';
import '../../data/queries.dart';
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
      final k = key(r);
      if (k.isNotEmpty && k != '-') {
        m[k] = (m[k] ?? 0) + 1;
      }
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Widget _block(String title, Map<String, int> counts, {Color? color}) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final c = color ?? AppColors.brandRed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            if (counts.isEmpty)
              const Text('No data available', style: TextStyle(color: Colors.grey, fontSize: 12)),
            for (final e in counts.entries.take(7))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        e.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : e.value / total,
                          minHeight: 8,
                          backgroundColor: c.withAlpha(25),
                          valueColor: AlwaysStoppedAnimation<Color>(c),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${e.value}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TV Service Reports & Analytics')),
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
            days[k] = (days[k] ?? 0.0) + (r['kind'] == 'income' ? 1 : -1) * toNum(r['amount']);
          }
          final lastDays = days.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              // Export CSV Buttons
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Export CSV Reports', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandRed),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('TV Leads CSV', style: TextStyle(fontSize: 12)),
                            onPressed: () => CsvExport.share(['leads']),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandTeal),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Attendance CSV', style: TextStyle(fontSize: 12)),
                            onPressed: () => CsvExport.share(['attendance']),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Tasks CSV', style: TextStyle(fontSize: 12)),
                            onPressed: () => CsvExport.share(['tasks']),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade800),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Cash Book CSV', style: TextStyle(fontSize: 12)),
                            onPressed: () => CsvExport.share(['finance_entries']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              _block('TV Brands Breakdown', _count(leads, (l) => str(l['tv_brand']) ?? ''), color: AppColors.brandRed),
              _block('Common TV Repair Complaints', _count(leads, (l) => str(l['issue']) ?? ''), color: AppColors.brandTeal),
              _block('TV Leads by Status', _count(leads, (l) => label(str(l['status']))), color: Colors.blue.shade700),
              _block('Leads by Source', _count(leads, (l) => label(str(l['source']))), color: Colors.orange.shade800),
              _block('Workload by Technician', _count(leads, (l) => names[l['assigned_to']] ?? 'Unassigned'), color: AppColors.brandRedDark),
              _block('Service Tasks by Status', _count(tasks, (t) => isOverdue(t) ? 'Overdue' : label(str(t['status']))), color: Colors.purple),

              const SectionTitle('Recent Net Daily Cash Flow'),
              if (lastDays.isEmpty)
                const EmptyState('No financial entries recorded yet.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final k in lastDays.take(10))
                        ListTile(
                          dense: true,
                          title: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(
                            money(days[k]!),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: days[k]! >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}
