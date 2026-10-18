import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/sync_service.dart';

/// Admin only: people, accounts and workload.
class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  Future<Map<String, dynamic>> _load() async => {
        'people': await Q.profiles(),
        'leads': await Q.leads(),
        'tasks': await Q.tasks(),
      };

  Future<String?> _call(Map<String, dynamic> body) async {
    try {
      await Supabase.instance.client.functions.invoke('manage-employee', body: body);
      return null;
    } on FunctionException catch (e) {
      final d = e.details;
      return d is Map && d['error'] != null ? d['error'].toString() : 'Request failed (${e.status}).';
    } catch (_) {
      return 'No internet. Account changes need a connection.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add employee'),
      ),
      body: Live<Map<String, dynamic>>(
        load: _load,
        builder: (context, data) {
          final people = data['people'] as List<Rec>;
          final leads = data['leads'] as List<Rec>;
          final tasks = data['tasks'] as List<Rec>;
          return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            for (final p in people)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text('${p['full_name']}  ${p['employee_code'] != null ? '(${p['employee_code']})' : ''}'),
                  subtitle: Text(
                      '${label(str(p['role']))} \u00B7 ${str(p['phone']) ?? str(p['email']) ?? ''}\n'
                      'Open leads: ${leads.where((l) => l['assigned_to'] == p['id'] && l['status'] != 'converted' && l['status'] != 'lost').length}'
                      '   Open tasks: ${tasks.where((t) => t['assigned_to'] == p['id'] && t['status'] != 'completed').length}'),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                      value: p['is_active'] == true,
                      onChanged: (v) => Store.put('profiles', {...p, 'is_active': v}),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'reset') {
                          final pw = await askText(context, 'New password (min 8 characters)');
                          if (pw == null) return;
                          if (!context.mounted) return;
                          if (pw.length < 8) {
                            toast(context, 'Password is too short.');
                            return;
                          }
                          final err = await _call({'action': 'reset_password', 'user_id': p['id'], 'password': pw});
                          if (context.mounted) toast(context, err ?? 'Password changed.');
                        }
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset password'))],
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController(), phone = TextEditingController();
    final email = TextEditingController(), pass = TextEditingController();
    String role = 'employee';
    String? error;
    bool busy = false;
    await showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setS) => AlertDialog(
          title: const Text('Add employee'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
              const SizedBox(height: 8),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Login email *')),
              const SizedBox(height: 8),
              TextField(controller: pass, decoration: const InputDecoration(labelText: 'Starting password * (min 8)')),
              const SizedBox(height: 8),
              dropdown<String>(
                  label: 'Role',
                  value: role,
                  items: stringItems(const ['employee', 'admin']),
                  onChanged: (v) => setS(() => role = v ?? role)),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty || email.text.trim().isEmpty || pass.text.length < 8) {
                        setS(() => error = 'Fill name, email and a password of 8+ characters.');
                        return;
                      }
                      setS(() {
                        busy = true;
                        error = null;
                      });
                      final err = await _call({
                        'action': 'create',
                        'full_name': name.text.trim(),
                        'phone': phone.text.trim(),
                        'email': email.text.trim(),
                        'password': pass.text,
                        'role': role,
                      });
                      if (err != null) {
                        setS(() {
                          busy = false;
                          error = err;
                        });
                        return;
                      }
                      if (dc.mounted) Navigator.pop(dc);
                      SyncService.instance.syncAll();
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
