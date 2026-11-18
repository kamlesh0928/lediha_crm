import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
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
        title: const Text('TV Repair Details'),
        actions: [
          if (admin)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Lead',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LeadFormPage(leadId: leadId)),
              ),
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

          Widget info(String k, String? v, {IconData? icon, Color? color}) => (v == null || v.isEmpty)
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: color ?? AppColors.brandTeal),
                        const SizedBox(width: 8),
                      ],
                      SizedBox(
                        width: 100,
                        child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(
                          v,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color ?? AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Top Customer & TV Banner Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (lead['priority'] == 'hot') ...[
                                      const Icon(Icons.local_fire_department, size: 20, color: AppColors.brandRed),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        '${lead['lead_no'] != null ? '#${lead['lead_no']} \u00B7 ' : ''}${str(lead['customer_name']) ?? ''}',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (lead['tv_brand'] != null && (lead['tv_brand'] as String).isNotEmpty)
                                  TvBadge(
                                    brand: str(lead['tv_brand']),
                                    model: str(lead['tv_model']),
                                  ),
                              ],
                            ),
                          ),
                          Pill(label(str(lead['status'])), color: statusColor(str(lead['status']))),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Call & WhatsApp Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandTeal,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onPressed: () => callNumber(phone),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Call Customer'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                              onPressed: () => whatsappNumber(phone),
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // TV & Repair Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      info('Phone', phone, icon: Icons.phone),
                      info('Area / Address', str(lead['area']), icon: Icons.location_on_outlined),
                      info('TV Problem', str(lead['issue']), icon: Icons.report_problem, color: Colors.deepOrange.shade800),
                      info('Lead Source', label(str(lead['source'])), icon: Icons.source),
                      info('Assigned To', names[lead['assigned_to']] ?? 'Unassigned', icon: Icons.person_outline),
                      info('Received On', fmtDateTime(lead['received_at']), icon: Icons.access_time),
                      info('Next Follow-up', lead['next_followup_at'] == null ? null : fmtDateTime(lead['next_followup_at']), icon: Icons.event),
                      info('Closed Date', lead['closed_at'] == null ? null : fmtDateTime(lead['closed_at']), icon: Icons.done_all),
                      info('Lost Reason', str(lead['lost_reason']), icon: Icons.cancel_outlined, color: Colors.red),
                    ],
                  ),
                ),
              ),

              const SectionTitle('Update TV Repair Status'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      dropdown<String>(
                        label: 'Service Status',
                        value: str(lead['status']),
                        items: stringItems(leadStatuses),
                        onChanged: (v) async {
                          if (v == null || v == lead['status']) return;
                          String? reason;
                          if (v == 'lost') {
                            reason = await askText(context, 'Why was the TV repair lost / cancelled?', required: false);
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
                          label: 'Assigned Technician',
                          value: str(lead['assigned_to']),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                            for (final p in staff)
                              DropdownMenuItem<String?>(
                                value: p['id'].toString(),
                                child: Text(str(p['full_name']) ?? ''),
                              ),
                          ],
                          onChanged: (v) => _patch(lead, {'assigned_to': v}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SectionTitle('Repair & Quotation Notes'),
              if ((str(lead['notes']) ?? '').isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        str(lead['notes'])!,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandTeal,
                  side: const BorderSide(color: AppColors.brandTeal),
                ),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add Repair Note / Quote'),
                onPressed: () async {
                  final t = await askText(context, 'Add repair note');
                  if (t == null) return;
                  final stamp = '[${fmtDateTime(DateTime.now())} \u00B7 ${AppAuth.instance.name ?? ''}] $t';
                  final old = str(lead['notes']) ?? '';
                  await _patch(lead, {'notes': old.isEmpty ? stamp : '$old\n$stamp'});
                },
              ),

              const SectionTitle('Follow-ups & Deliveries'),
              if (fus.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No follow-up or delivery scheduled yet.', style: TextStyle(color: Colors.grey)),
                ),
              for (final f in fus) FollowupTile(f: f, lead: lead, names: names),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
                icon: const Icon(Icons.event_available),
                label: const Text('Schedule Pickup / Delivery / Follow-up'),
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
