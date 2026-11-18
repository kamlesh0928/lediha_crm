import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/sync_service.dart';
import '../location/team_map_page.dart';

/// Admin only: Technician team members, accounts, and workload.
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
      appBar: AppBar(title: const Text('Service Technicians & Staff')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Technician', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Live<Map<String, dynamic>>(
        load: _load,
        builder: (context, data) {
          final people = data['people'] as List<Rec>;
          final leads = data['leads'] as List<Rec>;
          final tasks = data['tasks'] as List<Rec>;

          if (people.isEmpty) return const EmptyState('No employees or technicians found.');

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: people.length,
            itemBuilder: (_, i) {
              final p = people[i];
              final openLeads = leads
                  .where((l) => l['assigned_to'] == p['id'] && l['status'] != 'converted' && l['status'] != 'lost')
                  .length;
              final openTasks = tasks
                  .where((t) => t['assigned_to'] == p['id'] && t['status'] != 'completed')
                  .length;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: p['role'] == 'admin'
                                ? AppColors.brandRed.withAlpha(20)
                                : AppColors.brandTeal.withAlpha(20),
                            child: Icon(
                              p['role'] == 'admin' ? Icons.admin_panel_settings : Icons.handyman,
                              color: p['role'] == 'admin' ? AppColors.brandRed : AppColors.brandTeal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${p['full_name']} ${p['employee_code'] != null ? '(${p['employee_code']})' : ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                    ),
                                    Pill(
                                      label(str(p['role'])),
                                      color: p['role'] == 'admin' ? AppColors.brandRed : AppColors.brandTeal,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${str(p['phone']) ?? str(p['email']) ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$openLeads TV Leads',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.brandTealLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$openTasks Tasks',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandTealDark),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.map, size: 20, color: AppColors.brandTeal),
                                tooltip: 'Track Technician on Map',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TeamMapPage(selectedUserId: p['id'].toString())),
                                ),
                              ),
                              Switch(
                                value: p['is_active'] == true,
                                activeThumbColor: AppColors.brandTeal,
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
                                    if (context.mounted) toast(context, err ?? 'Password changed successfully.');
                                  }
                                },
                                itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset Password'))],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Service Technician', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 8),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Login Email *')),
                const SizedBox(height: 8),
                TextField(controller: pass, decoration: const InputDecoration(labelText: 'Starting Password * (min 8)')),
                const SizedBox(height: 8),
                dropdown<String>(
                  label: 'Role',
                  value: role,
                  items: stringItems(const ['employee', 'admin']),
                  onChanged: (v) => setS(() => role = v ?? role),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
              onPressed: busy
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty || email.text.trim().isEmpty || pass.text.length < 8) {
                        setS(() => error = 'Please fill full name, email and password (8+ chars).');
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
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
