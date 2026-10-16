import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/auth_state.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

/// Admin: create or edit a lead.
class LeadFormPage extends StatefulWidget {
  const LeadFormPage({super.key, this.leadId});
  final String? leadId;

  @override
  State<LeadFormPage> createState() => _LeadFormPageState();
}

class _LeadFormPageState extends State<LeadFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _area = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _issue = TextEditingController();
  final _notes = TextEditingController();
  String _source = 'manual', _status = 'new', _priority = 'medium';
  String? _assignedTo;
  DateTime? _nextFollowup;
  Rec? _existing;
  List<Rec> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _staff = await Q.profiles();
    if (widget.leadId != null) {
      final l = await Store.byId('leads', widget.leadId!);
      if (l != null) {
        _existing = l;
        _name.text = str(l['customer_name']) ?? '';
        _phone.text = str(l['phone']) ?? '';
        _email.text = str(l['email']) ?? '';
        _area.text = str(l['area']) ?? '';
        _brand.text = str(l['tv_brand']) ?? '';
        _model.text = str(l['tv_model']) ?? '';
        _issue.text = str(l['issue']) ?? '';
        _notes.text = str(l['notes']) ?? '';
        _source = str(l['source']) ?? 'manual';
        _status = str(l['status']) ?? 'new';
        _priority = str(l['priority']) ?? 'medium';
        _assignedTo = str(l['assigned_to']);
        _nextFollowup = parseDt(l['next_followup_at']);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final norm = normPhone(_phone.text);
    if (norm.isNotEmpty) {
      final dups = (await Store.all('leads')).where((l) =>
          l['id'] != widget.leadId &&
          l['is_deleted'] != true &&
          normPhone(str(l['phone'])) == norm);
      if (dups.isNotEmpty) {
        final d = dups.first;
        final ok = await confirmDialog(
            context,
            'Possible duplicate',
            '${d['customer_name']} (${label(str(d['status']))}) already uses this number. Save anyway?');
        if (!ok) return;
      }
    }
    final row = _existing != null
        ? Map<String, dynamic>.from(_existing!)
        : <String, dynamic>{
            'id': const Uuid().v4(),
            'created_by': AuthState.instance.uid,
            'received_at': nowIso(),
            'is_deleted': false,
          };
    String? nz(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    row.addAll({
      'customer_name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': nz(_email),
      'area': nz(_area),
      'tv_brand': nz(_brand),
      'tv_model': nz(_model),
      'issue': nz(_issue),
      'notes': nz(_notes),
      'source': _source,
      'status': _status,
      'priority': _priority,
      'assigned_to': _assignedTo,
      'next_followup_at': _nextFollowup?.toUtc().toIso8601String(),
    });
    if ((_status == 'converted' || _status == 'lost') && row['closed_at'] == null) {
      row['closed_at'] = nowIso();
    }
    await Store.put('leads', row);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.leadId == null ? 'New lead' : 'Edit lead')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionTitle('Customer'),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Customer name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone *'),
                    validator: (v) => normPhone(v).length < 10 ? 'Enter a valid phone number' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _area,
                      decoration: const InputDecoration(labelText: 'Area / pincode')),
                  const SectionTitle('TV & problem'),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _brand,
                            decoration: const InputDecoration(labelText: 'TV brand'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            controller: _model,
                            decoration: const InputDecoration(labelText: 'Model'))),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _issue,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Problem / complaint')),
                  const SectionTitle('Lead'),
                  dropdown<String>(
                      label: 'Source',
                      value: _source,
                      items: stringItems(leadSources),
                      onChanged: (v) => setState(() => _source = v ?? _source)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: dropdown<String>(
                            label: 'Status',
                            value: _status,
                            items: stringItems(leadStatuses),
                            onChanged: (v) => setState(() => _status = v ?? _status))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: dropdown<String>(
                            label: 'Priority',
                            value: _priority,
                            items: stringItems(leadPriorities),
                            onChanged: (v) => setState(() => _priority = v ?? _priority))),
                  ]),
                  const SizedBox(height: 10),
                  dropdown<String?>(
                    label: 'Assigned to',
                    value: _assignedTo,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                      for (final p in _staff)
                        DropdownMenuItem<String?>(
                            value: p['id'].toString(),
                            child: Text(
                                '${p['full_name']}${p['is_active'] == true ? '' : ' (inactive)'}')),
                    ],
                    onChanged: (v) => setState(() => _assignedTo = v),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_nextFollowup == null
                        ? 'Set next follow-up'
                        : 'Next follow-up: ${fmtDateTime(_nextFollowup)}'),
                    onPressed: () async {
                      final d = await pickDateTime(context, initial: _nextFollowup);
                      if (d != null) setState(() => _nextFollowup = d);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _notes,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notes')),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _save, child: const Text('Save lead')),
                ],
              ),
            ),
    );
  }
}
