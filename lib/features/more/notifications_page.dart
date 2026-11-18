import 'package:flutter/material.dart';
import '../../core/theme.dart';
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
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              for (final n in (await Q.notifications()).where((n) => n['read_at'] == null)) {
                await Store.put('notifications', {...n, 'read_at': nowIso()});
              }
            },
            child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Live<List<Rec>>(
        load: Q.notifications,
        builder: (context, list) {
          if (list.isEmpty) {
            return const EmptyState('No notifications yet.', icon: Icons.notifications_none);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final n = list[i];
              final unread = n['read_at'] == null;
              return Card(
                color: unread ? AppColors.brandRed.withAlpha(10) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: unread ? AppColors.brandRed.withAlpha(80) : AppColors.divider,
                    width: unread ? 1.2 : 0.8,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: unread ? AppColors.brandRed.withAlpha(20) : Colors.grey.shade100,
                    child: Icon(
                      n['kind'] == 'task_assigned' ? Icons.task_alt : Icons.tv,
                      color: unread ? AppColors.brandRed : Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    str(n['title']) ?? '',
                    style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${str(n['body']) ?? ''}\n${fmtDateTime(n['created_at'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: unread
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.brandRed,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () {
                    if (unread) Store.put('notifications', {...n, 'read_at': nowIso()});
                    if (n['ref_table'] == 'leads' && n['ref_id'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LeadDetailPage(leadId: n['ref_id'].toString())),
                      );
                    } else if (n['ref_table'] == 'tasks') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
