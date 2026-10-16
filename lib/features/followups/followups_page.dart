import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/auth_state.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../leads/lead_detail_page.dart';

IconData kindIcon(String? k) => switch (k) {
      'hot_lead' => Icons.local_fire_department,
      'pickup' => Icons.local_shipping_outlined,
      'work_pending' => Icons.build_circle_outlined,
      'work_done' => Icons.check_circle_outline,
      'delivery' => Icons.home_outlined,
      _ => Icons.phone_in_talk_outlined,
    };

Future<void> callNumber(String? phone) async {
  if (phone == null || phone.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: phone));
}

Future<void> whatsappNumber(String? phone) async {
  final n = waNumber(phone);
  if (n.isEmpty) return;
  await launchUrl(Uri.parse('https://wa.me/$n'), mode: LaunchMode.externalApplication);
}

/// Schedule a follow-up (delivery, pickup, work pending ...) for a lead.
Future<void> showFollowupDialog(BuildContext context, Rec lead, {String kind = 'general'}) async {
  var k = kind;
  DateTime when = DateTime.now().add(const Duration(hours: 1));
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (dc, setS) => AlertDialog(
        title: const Text('Schedule follow-up'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            dropdown<String>(
              label: 'Type',
              value: k,
              items: [
                for (final x in followupKinds)
                  DropdownMenuItem(value: x, child: Text(followupKindLabels[x]!))
              ],
              onChanged: (v) => setS(() => k = v ?? k),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(fmtDateTime(when)),
              onPressed: () async {
                final d = await pickDateTime(dc, initial: when);
                if (d != null) setS(() => when = d);
              },
            ),
            const SizedBox(height: 10),
            TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Save')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final me = AuthState.instance.uid;
  await Store.put('followups', {
    'lead_id': lead['id'],
    'assigned_to': lead['assigned_to'] ?? me,
    'kind': k,
    'scheduled_at': when.toUtc().toIso8601String(),
    'status': 'open',
    'note': note.text.trim().isEmpty ? null : note.text.trim(),
    'created_by': me,
  });
  await Store.put('leads', {
    ...lead,
    'next_followup_at': when.toUtc().toIso8601String(),
    if (k == 'hot_lead') 'priority': 'hot',
  });
}

class FollowupsPage extends StatelessWidget {
  const FollowupsPage({super.key});

  static const _tabs = [
    ['today', 'Due today'],
    ['hot_lead', 'Hot leads'],
    ['pickup', "Today's pickup"],
    ['work_pending', 'Work pending'],
    ['work_done', 'Work done'],
    ['delivery', 'Delivery'],
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Column(children: [
        Material(
          color: Colors.white,
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in _tabs) Tab(text: t[1])],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            for (final t in _tabs) FollowupList(kind: t[0]),
          ]),
        ),
      ]),
    );
  }
}

class FollowupList extends StatelessWidget {
  const FollowupList({super.key, required this.kind, this.limit});
  final String kind;
  final int? limit;

  Future<Map<String, dynamic>> _load() async => {
        'fus': await Q.followups(),
        'leads': await Q.leadsById(),
        'names': await Q.names(),
      };

  @override
  Widget build(BuildContext context) {
    return Live<Map<String, dynamic>>(
      load: _load,
      builder: (context, data) {
        final fus = data['fus'] as List<Rec>;
        final leads = data['leads'] as Map<String, Rec>;
        final names = data['names'] as Map<String, String>;

        // Hot leads tab: every open lead marked hot.
        if (kind == 'hot_lead') {
          final hot = leads.values
              .where((l) =>
                  l['is_deleted'] != true &&
                  l['priority'] == 'hot' &&
                  l['status'] != 'converted' &&
                  l['status'] != 'lost' &&
                  (AuthState.instance.isAdmin || l['assigned_to'] == AuthState.instance.uid))
              .toList();
          if (hot.isEmpty) return const EmptyState('No hot leads right now.');
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final l in hot)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.local_fire_department, color: Colors.deepOrange)),
                    title: Text(str(l['customer_name']) ?? '-'),
                    subtitle: Text(
                        '${str(l['phone']) ?? ''}\n${str(l['issue']) ?? ''}${l['next_followup_at'] != null ? '\nNext: ${fmtDateTime(l['next_followup_at'])}' : ''}'),
                    isThreeLine: true,
                    trailing: IconButton(
                        icon: const Icon(Icons.call), onPressed: () => callNumber(str(l['phone']))),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LeadDetailPage(leadId: l['id'].toString()))),
                  ),
                ),
            ],
          );
        }

        final end = endOfToday();
        var open = fus.where((f) => f['status'] != 'done').toList();
        if (kind == 'today') {
          open = open.where((f) => parseDt(f['scheduled_at'])!.isBefore(end)).toList();
        } else {
          open = open.where((f) => f['kind'] == kind).toList();
        }
        if (limit != null && open.length > limit!) open = open.sublist(0, limit!);
        final done = kind == 'today' || limit != null
            ? <Rec>[]
            : (fus.where((f) => f['status'] == 'done' && f['kind'] == kind).toList()
              ..sort((a, b) => (b['completed_at'] ?? '').toString().compareTo((a['completed_at'] ?? '').toString())));
        if (open.isEmpty && done.isEmpty) {
          return EmptyState(kind == 'today'
              ? 'Nothing due today. \u{1F389}'
              : 'No ${followupKindLabels[kind]!.toLowerCase()} follow-ups yet.\nSchedule them from a lead.');
        }
        return ListView(
          shrinkWrap: limit != null,
          physics: limit != null ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final f in open)
              FollowupTile(f: f, lead: leads[f['lead_id']], names: names),
            if (done.isNotEmpty)
              ExpansionTile(
                title: Text('Completed (${done.length})'),
                children: [
                  for (final f in done.take(20))
                    FollowupTile(f: f, lead: leads[f['lead_id']], names: names),
                ],
              ),
          ],
        );
      },
    );
  }
}

class FollowupTile extends StatelessWidget {
  const FollowupTile({super.key, required this.f, required this.lead, required this.names});
  final Rec f;
  final Rec? lead;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final when = parseDt(f['scheduled_at']);
    final done = f['status'] == 'done';
    final overdue = !done && when != null && when.isBefore(DateTime.now());
    final phone = str(lead?['phone']);
    final note = str(f['note']) ?? '';
    final who = AuthState.instance.isAdmin ? names[f['assigned_to']] : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Icon(kindIcon(str(f['kind'])))),
        title: Text(str(lead?['customer_name']) ?? 'Unknown customer'),
        subtitle: Text.rich(TextSpan(children: [
          TextSpan(text: '${followupKindLabels[f['kind']] ?? 'Follow-up'} \u00B7 '),
          TextSpan(
              text: done ? 'Done ${fmtDateTime(f['completed_at'])}' : fmtDateTime(when),
              style: TextStyle(color: overdue ? Colors.red : null, fontWeight: overdue ? FontWeight.w700 : null)),
          if (who != null) TextSpan(text: ' \u00B7 $who'),
          if (note.isNotEmpty) TextSpan(text: '\n$note'),
        ])),
        isThreeLine: note.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _action(context, v),
          itemBuilder: (_) => [
            if (phone != null && phone.isNotEmpty)
              const PopupMenuItem(value: 'call', child: Text('Call')),
            if (phone != null && phone.isNotEmpty)
              const PopupMenuItem(value: 'wa', child: Text('WhatsApp')),
            if (!done) const PopupMenuItem(value: 'done', child: Text('Mark done')),
            if (!done) const PopupMenuItem(value: 'resched', child: Text('Reschedule')),
            const PopupMenuItem(value: 'open', child: Text('Open lead')),
          ],
        ),
        onTap: lead == null ? null : () => _action(context, 'open'),
      ),
    );
  }

  Future<void> _action(BuildContext context, String a) async {
    final phone = str(lead?['phone']);
    switch (a) {
      case 'call':
        await callNumber(phone);
      case 'wa':
        await whatsappNumber(phone);
      case 'open':
        if (lead != null) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => LeadDetailPage(leadId: lead!['id'].toString())));
        }
      case 'done':
        final outcome = await askText(context, 'What happened?',
            hint: 'e.g. Delivered, customer paid', required: false);
        if (outcome == null) return;
        await Store.put('followups', {
          ...f,
          'status': 'done',
          'outcome': outcome.isEmpty ? null : outcome,
          'completed_at': nowIso(),
        });
      case 'resched':
        final d = await pickDateTime(context, initial: parseDt(f['scheduled_at']));
        if (d == null) return;
        await Store.put('followups', {...f, 'scheduled_at': d.toUtc().toIso8601String()});
    }
  }
}
