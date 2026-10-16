import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/auth_state.dart';
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
    final admin = AuthState.instance.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const TaskFormPage())),
              icon: const Icon(Icons.add),
              label: const Text('New task'))
          : null,
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              for (final f in ['open', 'overdue', 'completed', 'all'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                      label: Text(label(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f)),
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
              if (list.isEmpty) return const EmptyState('No tasks here.');
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final t = list[i];
                  final over = isOverdue(t);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      onTap: () => _openTask(context, t, names),
                      title: Text(str(t['title']) ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${admin ? '${names[t['assigned_to']] ?? ''} \u00B7 ' : ''}Due ${fmtDateTime(t['due_at'])}',
                          style: TextStyle(color: over ? Colors.red : null)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Pill(label(str(t['status'])), color: statusColor(str(t['status']))),
                          if (over) const Pill('Overdue', color: Colors.red),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  void _openTask(BuildContext context, Rec t, Map<String, String> names) {
    final admin = AuthState.instance.isAdmin;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sc) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(str(t['title']) ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if ((str(t['description']) ?? '').isNotEmpty) Text(str(t['description'])!),
          const SizedBox(height: 6),
          Text('Assigned to: ${names[t['assigned_to']] ?? '-'}'),
          Text('Priority: ${label(str(t['priority']))}   Due: ${fmtDateTime(t['due_at'])}'),
          if ((str(t['completion_note']) ?? '').isNotEmpty) Text('Completion note: ${t['completion_note']}'),
          if ((str(t['reopen_reason']) ?? '').isNotEmpty) Text('Reopened because: ${t['reopen_reason']}'),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            if (t['status'] == 'pending' || t['status'] == 'reopened')
              FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(sc);
                    Store.put('tasks', {...t, 'status': 'in_progress'});
                  },
                  child: const Text('Start')),
            if (t['status'] != 'completed')
              FilledButton(
                  onPressed: () async {
                    Navigator.pop(sc);
                    final note = await askText(context, 'Completion note',
                        hint: 'What was done?', required: false);
                    if (note == null) return;
                    await Store.put('tasks', {
                      ...t,
                      'status': 'completed',
                      'completion_note': note.isEmpty ? null : note,
                    });
                  },
                  child: const Text('Mark completed')),
            if (admin && t['status'] == 'completed')
              OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(sc);
                    final why = await askText(context, 'Why reopen this task?');
                    if (why == null) return;
                    await Store.put('tasks', {...t, 'status': 'reopened', 'reopen_reason': why});
                  },
                  child: const Text('Reopen')),
          ]),
        ]),
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
      'created_by': AuthState.instance.uid,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Task title *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 10),
          TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          dropdown<String>(
            label: 'Assign to *',
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
              onChanged: (v) => setState(() => _priority = v ?? _priority)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Due: ${fmtDateTime(_due)}'),
              onPressed: () async {
                final d = await pickDateTime(context, initial: _due);
                if (d != null) setState(() => _due = d);
              }),
          const SizedBox(height: 10),
          dropdown<String?>(
            label: 'Linked lead (optional)',
            value: _leadId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final l in _leads)
                DropdownMenuItem<String?>(
                    value: l['id'].toString(),
                    child: Text('${l['customer_name']} \u00B7 ${l['phone'] ?? ''}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _leadId = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () {
                if (_assignee == null) {
                  toast(context, 'Choose who this task is for.');
                  return;
                }
                _save();
              },
              child: const Text('Create task')),
        ]),
      ),
    );
  }
}
