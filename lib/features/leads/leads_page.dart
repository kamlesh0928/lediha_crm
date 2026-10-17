import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import 'lead_detail_page.dart';
import 'lead_form_page.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  String _q = '';
  String _filter = 'all';

  Future<Map<String, dynamic>> _load() async => {
        'leads': await Q.leads(),
        'names': await Q.names(),
      };

  @override
  Widget build(BuildContext context) {
    final admin = AppAuth.instance.isAdmin;
    final filters = ['all', if (admin) 'unassigned', 'hot', ...leadStatuses];
    return Scaffold(
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LeadFormPage())),
              icon: const Icon(Icons.add),
              label: const Text('Add lead'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search name or phone'),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(label(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Live<Map<String, dynamic>>(
              load: _load,
              builder: (context, data) {
                final all = data['leads'] as List<Rec>;
                final names = data['names'] as Map<String, String>;
                final phoneCount = <String, int>{};
                for (final l in all) {
                  final n = normPhone(str(l['phone']));
                  if (n.isNotEmpty) phoneCount[n] = (phoneCount[n] ?? 0) + 1;
                }
                final q = _q.trim().toLowerCase();
                final list = all.where((l) {
                  final open = l['status'] != 'converted' && l['status'] != 'lost';
                  final okFilter = switch (_filter) {
                    'all' => true,
                    'unassigned' => l['assigned_to'] == null && open,
                    'hot' => l['priority'] == 'hot' && open,
                    _ => l['status'] == _filter,
                  };
                  if (!okFilter) return false;
                  if (q.isEmpty) return true;
                  return (l['customer_name'] ?? '').toString().toLowerCase().contains(q) ||
                      (l['phone'] ?? '').toString().contains(q);
                }).toList();
                if (list.isEmpty) return const EmptyState('No leads match.');
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final l = list[i];
                    final dup = (phoneCount[normPhone(str(l['phone']))] ?? 0) > 1;
                    final assignee = names[l['assigned_to']];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => LeadDetailPage(leadId: l['id'].toString()))),
                        title: Row(children: [
                          if (l['priority'] == 'hot')
                            const Icon(Icons.local_fire_department,
                                size: 18, color: Colors.deepOrange),
                          Expanded(
                            child: Text(str(l['customer_name']) ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          if (dup)
                            const Tooltip(
                                message: 'Possible duplicate',
                                child: Icon(Icons.warning_amber, size: 18, color: Colors.orange)),
                        ]),
                        subtitle: Text(
                            '${str(l['phone']) ?? 'No phone'} \u00B7 ${label(str(l['source']))}'
                            '${assignee != null ? ' \u00B7 $assignee' : (AppAuth.instance.isAdmin ? ' \u00B7 Unassigned' : '')}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Pill(label(str(l['status'])), color: statusColor(str(l['status']))),
                            if (l['next_followup_at'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(fmtDateTime(l['next_followup_at']),
                                    style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
