import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

bool isOverdue(Rec t) {
  final due = parseDt(t['due_at']);
  return t['status'] != 'completed' && due != null && due.isBefore(DateTime.now());
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String _filter = 'open';

  Future<Map<String, dynamic>> _load() async => {'tasks': await Q.tasks(), 'names': await Q.names()};

  @override
  Widget build(BuildContext context) {
    final admin = AppAuth.instance.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('TV Service & Repair Tasks')),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskFormPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Service Task', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                for (final f in ['open', 'overdue', 'completed', 'all'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label(f)),
                      selected: _filter == f,
                      selectedColor: AppColors.brandRed.withAlpha(25),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w500,
                        color: _filter == f ? AppColors.brandRed : AppColors.textPrimary,
                      ),
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
                final names = data['names'] as Map<String, String>;
                final list = (data['tasks'] as List<Rec>).where((t) {
                  return switch (_filter) {
                    'open' => t['status'] != 'completed',
                    'overdue' => isOverdue(t),
                    'completed' => t['status'] == 'completed',
                    _ => true,
                  };
                }).toList();

                if (list.isEmpty) return const EmptyState('No service tasks found here.');

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, top: 4),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final over = isOverdue(t);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: over
                              ? Colors.red.shade50
                              : (t['status'] == 'completed'
                                  ? Colors.green.shade50
                                  : AppColors.brandTealLight),
                          child: Icon(
                            t['status'] == 'completed'
                                ? Icons.check_circle
                                : (over ? Icons.error_outline : Icons.handyman),
                            color: t['status'] == 'completed'
                                ? Colors.green
                                : (over ? Colors.red : AppColors.brandTeal),
                            size: 20,
                          ),
                        ),
                        onTap: () => _openTask(context, t, names),
                        title: Text(
                          str(t['title']) ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${admin ? '${names[t['assigned_to']] ?? 'Staff'} \u00B7 ' : ''}Due ${fmtDateTime(t['due_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: over ? Colors.red.shade700 : AppColors.textSecondary,
                            fontWeight: over ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Pill(label(str(t['status'])), color: statusColor(str(t['status']))),
                            if (over)
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Pill('Overdue', color: Colors.red),
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

  void _openTask(BuildContext context, Rec t, Map<String, String> names) {
    final admin = AppAuth.instance.isAdmin;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sc) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    str(t['title']) ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Pill(label(str(t['status'])), color: statusColor(str(t['status']))),
              ],
            ),
            const SizedBox(height: 8),
            if ((str(t['description']) ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(str(t['description'])!, style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            const SizedBox(height: 8),
            Text('Assigned Technician: ${names[t['assigned_to']] ?? '-'}', style: const TextStyle(fontSize: 13)),
            Text('Priority: ${label(str(t['priority']))}   Due: ${fmtDateTime(t['due_at'])}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if ((str(t['completion_note']) ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Completion Note: ${t['completion_note']}',
                    style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
              ),
            if ((str(t['reopen_reason']) ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Reopened because: ${t['reopen_reason']}',
                    style: const TextStyle(fontSize: 13, color: Colors.red)),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (t['status'] == 'pending' || t['status'] == 'reopened')
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brandTealLight),
                    onPressed: () {
                      Navigator.pop(sc);
                      Store.put('tasks', {...t, 'status': 'in_progress'});
                    },
                    child: const Text('Start Work (In Progress)', style: TextStyle(color: AppColors.brandTealDark)),
                  ),
                if (t['status'] != 'completed')
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                    onPressed: () async {
                      Navigator.pop(sc);
                      final note = await askText(
                        context,
                        'Service Completion Note',
                        hint: 'e.g. Backlight strips replaced & tested for 2 hours',
                        required: false,
                      );
                      if (note == null) return;
                      await Store.put('tasks', {
                        ...t,
                        'status': 'completed',
                        'completion_note': note.isEmpty ? null : note,
                      });
                    },
                    child: const Text('Mark Completed'),
                  ),
                if (admin && t['status'] == 'completed')
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(sc);
                      final why = await askText(context, 'Why reopen this task?');
                      if (why == null) return;
                      await Store.put('tasks', {...t, 'status': 'reopened', 'reopen_reason': why});
                    },
                    child: const Text('Reopen Task'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _assignee, _leadId;
  String _priority = 'medium';
  DateTime _due = DateTime.now().add(const Duration(hours: 4));
  List<Rec> _staff = [], _leads = [];

  static const _quickTaskTemplates = [
    'LED Backlight Replacement',
    'Panel Screen Bonding / COF',
    'Motherboard Repair / Component Level',
    'Power Supply Board Servicing',
    'TV Pickup from Customer Home',
    'TV Delivery & Wall Mount Setup',
    'Software Flashing / Boot Loop Fix',
    'Speaker / Audio IC Replacement',
  ];

  @override
  void initState() {
    super.initState();
    () async {
      _staff = await Q.staff();
      _leads = await Q.leads();
      if (mounted) setState(() {});
    }();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await Store.put('tasks', {
      'id': const Uuid().v4(),
      'title': _title.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'assigned_to': _assignee,
      'priority': _priority,
      'due_at': _due.toUtc().toIso8601String(),
      'status': 'pending',
      'lead_id': _leadId,
      'created_by': AppAuth.instance.uid,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New TV Service Task')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick Template Chips
            const SectionTitle('Quick TV Task Templates'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _quickTaskTemplates)
                  ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onPressed: () => setState(() => _title.text = t),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Task Title *', prefixIcon: Icon(Icons.handyman, size: 20)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Repair Instructions / Description',
                prefixIcon: Icon(Icons.description_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            dropdown<String>(
              label: 'Assign to Technician *',
              value: _assignee,
              items: [
                for (final p in _staff)
                  DropdownMenuItem(value: p['id'].toString(), child: Text(str(p['full_name']) ?? ''))
              ],
              onChanged: (v) => setState(() => _assignee = v),
            ),
            const SizedBox(height: 10),
            dropdown<String>(
              label: 'Priority',
              value: _priority,
              items: stringItems(leadPriorities.where((p) => p != 'hot').toList()),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Due Date & Time: ${fmtDateTime(_due)}'),
              onPressed: () async {
                final d = await pickDateTime(context, initial: _due);
                if (d != null) setState(() => _due = d);
              },
            ),
            const SizedBox(height: 10),
            dropdown<String?>(
              label: 'Linked Customer / TV Lead (optional)',
              value: _leadId,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('None')),
                for (final l in _leads)
                  DropdownMenuItem<String?>(
                    value: l['id'].toString(),
                    child: Text(
                      '${l['customer_name']} \u00B7 ${l['tv_brand'] ?? ''} ${l['tv_model'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _leadId = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                if (_assignee == null) {
                  toast(context, 'Please choose a technician for this task.');
                  return;
                }
                _save();
              },
              child: const Text('Create Service Task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
