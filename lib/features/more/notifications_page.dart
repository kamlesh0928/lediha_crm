import 'package:flutter/material.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../leads/lead_detail_page.dart';
import '../tasks/tasks_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(
          onPressed: () async {
            for (final n in (await Q.notifications()).where((n) => n['read_at'] == null)) {
              await Store.put('notifications', {...n, 'read_at': nowIso()});
            }
          },
          child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
        ),
      ]),
      body: Live<List<Rec>>(
        load: Q.notifications,
        builder: (context, list) {
          if (list.isEmpty) return const EmptyState('No notifications yet.');
          return ListView(children: [
            for (final n in list)
              ListTile(
                tileColor: n['read_at'] == null ? Colors.teal.withAlpha(18) : null,
                leading: Icon(n['kind'] == 'task_assigned' ? Icons.task_alt : Icons.person_add_alt),
                title: Text(str(n['title']) ?? ''),
                subtitle: Text('${str(n['body']) ?? ''}\n${fmtDateTime(n['created_at'])}'),
                isThreeLine: true,
                onTap: () {
                  if (n['read_at'] == null) Store.put('notifications', {...n, 'read_at': nowIso()});
                  if (n['ref_table'] == 'leads' && n['ref_id'] != null) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => LeadDetailPage(leadId: n['ref_id'].toString())));
                  } else if (n['ref_table'] == 'tasks') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()));
                  }
                },
              ),
          ]);
        },
      ),
    );
  }
}
