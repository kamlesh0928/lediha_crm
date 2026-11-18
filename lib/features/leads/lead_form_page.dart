import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

/// Admin: create or edit a TV repair lead.
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
      final leads = await Store.all('leads');
      if (!mounted) return;
      final dups = leads.where((l) =>
          l['id'] != widget.leadId &&
          l['is_deleted'] != true &&
          normPhone(str(l['phone'])) == norm);
      if (dups.isNotEmpty) {
        final d = dups.first;
        final ok = await confirmDialog(
          context,
          'Possible duplicate phone',
          '${d['customer_name']} (${label(str(d['status']))}) already uses this number. Save anyway?',
        );
        if (!ok || !mounted) return;
      }
    }
    final row = _existing != null
        ? Map<String, dynamic>.from(_existing!)
        : <String, dynamic>{
            'id': const Uuid().v4(),
            'created_by': AppAuth.instance.uid,
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
      appBar: AppBar(
        title: Text(widget.leadId == null ? 'New TV Repair Lead' : 'Edit TV Repair Lead'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Customer Information
                  const SectionTitle('Customer Details'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Customer Name *',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number *',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            ),
                            validator: (v) => normPhone(v).length < 10 ? 'Enter a valid phone number' : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _area,
                                  decoration: const InputDecoration(
                                    labelText: 'Area / Pincode',
                                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // TV & Complaint
                  const SectionTitle('TV Details & Problem'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _brand,
                                  decoration: const InputDecoration(
                                    labelText: 'TV Brand (e.g. Samsung)',
                                    prefixIcon: Icon(Icons.tv, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _model,
                                  decoration: const InputDecoration(
                                    labelText: 'Model / Screen Size',
                                    prefixIcon: Icon(Icons.aspect_ratio, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Quick TV Brand Chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final b in commonTvBrands.take(8))
                                InkWell(
                                  onTap: () => setState(() => _brand.text = b),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _brand.text == b
                                          ? AppColors.brandRed.withAlpha(20)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _brand.text == b ? AppColors.brandRed : Colors.grey.shade300,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      b,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _brand.text == b ? FontWeight.w700 : FontWeight.w500,
                                        color: _brand.text == b ? AppColors.brandRed : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _issue,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Problem / Complaint (e.g. No display)',
                              prefixIcon: Icon(Icons.report_problem_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Quick Issue Suggestions
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final issue in commonTvIssues.take(4))
                                InkWell(
                                  onTap: () => setState(() => _issue.text = issue),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.shade200, width: 0.8),
                                    ),
                                    child: Text(
                                      issue,
                                      style: TextStyle(fontSize: 10, color: Colors.blue.shade900),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Lead Management & Assignment
                  const SectionTitle('Lead Management'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: dropdown<String>(
                                  label: 'Lead Source',
                                  value: _source,
                                  items: stringItems(leadSources),
                                  onChanged: (v) => setState(() => _source = v ?? _source),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: dropdown<String>(
                                  label: 'Priority',
                                  value: _priority,
                                  items: stringItems(leadPriorities),
                                  onChanged: (v) => setState(() => _priority = v ?? _priority),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: dropdown<String>(
                                  label: 'Status',
                                  value: _status,
                                  items: stringItems(leadStatuses),
                                  onChanged: (v) => setState(() => _status = v ?? _status),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: dropdown<String?>(
                                  label: 'Assigned Technician',
                                  value: _assignedTo,
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                                    for (final p in _staff)
                                      DropdownMenuItem<String?>(
                                        value: p['id'].toString(),
                                        child: Text(
                                          '${p['full_name']}${p['is_active'] == true ? '' : ' (inactive)'}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() => _assignedTo = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brandTeal,
                              side: const BorderSide(color: AppColors.brandTeal),
                            ),
                            icon: const Icon(Icons.event),
                            label: Text(
                              _nextFollowup == null
                                  ? 'Schedule Follow-up / Pickup'
                                  : 'Follow-up: ${fmtDateTime(_nextFollowup)}',
                            ),
                            onPressed: () async {
                              final d = await pickDateTime(context, initial: _nextFollowup);
                              if (d != null) setState(() => _nextFollowup = d);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Technician Notes (parts, quotation, remarks)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _save,
                    child: const Text('Save TV Repair Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
