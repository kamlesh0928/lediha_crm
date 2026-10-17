import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../followups/followups_page.dart';
import 'lead_form_page.dart';

class LeadDetailPage extends StatelessWidget {
  const LeadDetailPage({super.key, required this.leadId});
  final String leadId;

  Future<Map<String, dynamic>> _load() async => {
        'lead': await Store.byId('leads', leadId),
        'fus': (await Q.followups()).where((f) => f['lead_id'] == leadId).toList(),
        'names': await Q.names(),
        'staff': await Q.profiles(),
      };

  Future<void> _patch(Rec lead, Map<String, dynamic> changes) =>
      Store.put('leads', {...lead, ...changes});

  @override
  Widget build(BuildContext context) {
    final admin = AppAuth.instance.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead'),
        actions: [
          if (admin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => LeadFormPage(leadId: leadId))),
            ),
        ],
      ),
      body: Live<Map<String, dynamic>>(
        load: _load,
        builder: (context, data) {
          final lead = data['lead'] as Rec?;
          if (lead == null) return const EmptyState('This lead is not available.');
          final fus = data['fus'] as List<Rec>;
          final names = data['names'] as Map<String, String>;
          final staff = data['staff'] as List<Rec>;
          final phone = str(lead['phone']);
          Widget info(String k, String? v) => (v == null || v.isEmpty)
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 110,
                        child: Text(k, style: const TextStyle(color: Colors.black54))),
                    Expanded(child: Text(v)),
                  ]),
                );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                      '${lead['lead_no'] != null ? '#${lead['lead_no']}  ' : ''}${str(lead['customer_name']) ?? ''}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                Pill(label(str(lead['status'])), color: statusColor(str(lead['status']))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: FilledButton.icon(
                        onPressed: () => callNumber(phone),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => whatsappNumber(phone),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'))),
              ]),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    info('Phone', phone),
                    info('Email', str(lead['email'])),
                    info('Area', str(lead['area'])),
                    info('TV', [str(lead['tv_brand']), str(lead['tv_model'])]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' ')),
                    info('Problem', str(lead['issue'])),
                    info('Source', label(str(lead['source']))),
                    info('Campaign', str(lead['campaign'])),
                    info('Received', fmtDateTime(lead['received_at'])),
                    info('Assigned to', names[lead['assigned_to']] ?? 'Unassigned'),
                    info('Next follow-up', lead['next_followup_at'] == null ? null : fmtDateTime(lead['next_followup_at'])),
                    info('Closed', lead['closed_at'] == null ? null : fmtDateTime(lead['closed_at'])),
                    info('Lost reason', str(lead['lost_reason'])),
                  ]),
                ),
              ),
              const SectionTitle('Update'),
              dropdown<String>(
                label: 'Status',
                value: str(lead['status']),
                items: stringItems(leadStatuses),
                onChanged: (v) async {
                  if (v == null || v == lead['status']) return;
                  String? reason;
                  if (v == 'lost') {
                    reason = await askText(context, 'Why was it lost?', required: false);
                    if (reason == null) return;
                  }
                  await _patch(lead, {
                    'status': v,
                    if (v == 'converted' || v == 'lost') 'closed_at': nowIso(),
                    if (v == 'lost') 'lost_reason': reason,
                  });
                },
              ),
              const SizedBox(height: 10),
              dropdown<String>(
                label: 'Priority',
                value: str(lead['priority']),
                items: stringItems(leadPriorities),
                onChanged: (v) => v == null ? null : _patch(lead, {'priority': v}),
              ),
              if (admin) ...[
                const SizedBox(height: 10),
                dropdown<String?>(
                  label: 'Assigned to',
                  value: str(lead['assigned_to']),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    for (final p in staff)
                      DropdownMenuItem<String?>(
                          value: p['id'].toString(), child: Text(str(p['full_name']) ?? '')),
                  ],
                  onChanged: (v) => _patch(lead, {'assigned_to': v}),
                ),
              ],
              const SectionTitle('Notes'),
              if ((str(lead['notes']) ?? '').isNotEmpty)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(width: double.infinity, child: Text(str(lead['notes'])!)))),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add note'),
                onPressed: () async {
                  final t = await askText(context, 'Add note');
                  if (t == null) return;
                  final stamp =
                      '[${fmtDateTime(DateTime.now())} \u00B7 ${AppAuth.instance.name ?? ''}] $t';
                  final old = str(lead['notes']) ?? '';
                  await _patch(lead, {'notes': old.isEmpty ? stamp : '$old\n$stamp'});
                },
              ),
              const SectionTitle('Follow-ups'),
              if (fus.isEmpty) const Text('No follow-ups scheduled.', style: TextStyle(color: Colors.grey)),
              for (final f in fus) FollowupTile(f: f, lead: lead, names: names),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.event_available),
                label: const Text('Schedule follow-up'),
                onPressed: () => showFollowupDialog(context, lead),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
