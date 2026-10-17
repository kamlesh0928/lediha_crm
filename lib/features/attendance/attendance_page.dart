import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../location/location_service.dart';

bool isLate(Rec r) {
  final cin = parseDt(r['check_in_at']);
  if (cin == null) return false;
  final limit = DateTime(cin.year, cin.month, cin.day, shiftStartHour, shiftStartMinute)
      .add(const Duration(minutes: lateGraceMinutes));
  return cin.isAfter(limit);
}

Future<bool> _consent(BuildContext context) async {
  if (await Store.getMeta('loc_consent') == '1') return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dc) => AlertDialog(
      title: const Text('Location is recorded'),
      content: const Text(
          'While you are checked in, this app saves your location every few minutes so the '
          'company can see where field work is happening. Nothing is recorded after you check out. '
          'Your phone will show a notification or indicator while this is on.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('I understand')),
      ],
    ),
  );
  if (ok == true) await Store.setMeta('loc_consent', '1');
  return ok == true;
}

Future<void> doCheckIn(BuildContext context) async {
  final uid = AppAuth.instance.uid!;
  if (!await _consent(context)) return;
  final pos = await LocationService.current();
  final now = DateTime.now();
  final id = attendanceId(uid, dateKey(now));
  final row = await Store.byId('attendance', id) ??
      {'id': id, 'user_id': uid, 'work_date': dateKey(now)};
  if (row['check_in_at'] != null) return;
  row['check_in_at'] = now.toUtc().toIso8601String();
  row['check_in_lat'] = pos?.latitude;
  row['check_in_lng'] = pos?.longitude;
  await Store.put('attendance', row);
  if (pos != null) await LocationService.savePing(pos);
  await LocationService.start();
  if (context.mounted) {
    toast(context, pos == null ? 'Checked in (location not available).' : 'Checked in.');
  }
}

Future<void> doCheckOut(BuildContext context) async {
  final uid = AppAuth.instance.uid!;
  final now = DateTime.now();
  final row = await Store.byId('attendance', attendanceId(uid, dateKey(now)));
  if (row == null || row['check_in_at'] == null || row['check_out_at'] != null) return;
  final pos = await LocationService.current();
  row['check_out_at'] = now.toUtc().toIso8601String();
  row['check_out_lat'] = pos?.latitude;
  row['check_out_lng'] = pos?.longitude;
  await Store.put('attendance', row);
  if (pos != null) await LocationService.savePing(pos);
  await LocationService.stop();
  if (context.mounted) toast(context, 'Checked out.');
}

/// Big check-in / check-out card (used on the dashboard and attendance screen).
class AttendanceControl extends StatelessWidget {
  const AttendanceControl({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppAuth.instance.uid!;
    return Live<Rec?>(
      load: () => Store.byId('attendance', attendanceId(uid, dateKey(DateTime.now()))),
      builder: (context, row) {
        final cin = row?['check_in_at'];
        final cout = row?['check_out_at'];
        final String status = cin == null
            ? 'Not checked in'
            : cout == null
                ? 'Checked in at ${fmtTime(cin)}'
                : 'Done: ${fmtTime(cin)} - ${fmtTime(cout)}  (${durationText(parseDt(cin)!, parseDt(cout)!)})';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text("Today \u00B7 ${fmtDate(DateTime.now())}", style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 6),
              Text(status, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (row != null && isLate(row))
                const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Late arrival', style: TextStyle(color: Colors.red))),
              const SizedBox(height: 12),
              if (cin == null)
                FilledButton.icon(
                    onPressed: () => doCheckIn(context),
                    icon: const Icon(Icons.login),
                    label: const Text('Check in'))
              else if (cout == null)
                FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                    onPressed: () => doCheckOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Check out')),
            ]),
          ),
        );
      },
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final admin = AppAuth.instance.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: admin ? _adminView() : _employeeView(),
    );
  }

  Widget _employeeView() => Live<List<Rec>>(
        load: Q.attendance,
        builder: (context, rows) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const AttendanceControl(),
            const SectionTitle('My history'),
            if (rows.isEmpty) const Text('No records yet.', style: TextStyle(color: Colors.grey)),
            for (final r in rows.take(45))
              Card(
                child: ListTile(
                  title: Text(fmtDate(r['work_date'])),
                  subtitle: Text('In ${fmtTime(r['check_in_at'])}   Out ${fmtTime(r['check_out_at'])}'
                      '${r['check_in_at'] != null && r['check_out_at'] != null ? '   (${durationText(parseDt(r['check_in_at'])!, parseDt(r['check_out_at'])!)})' : ''}'),
                  trailing: Wrap(spacing: 4, children: [
                    if (isLate(r)) const Pill('Late', color: Colors.red),
                    if (r['corrected'] == true) const Pill('Corrected', color: Colors.blue),
                  ]),
                ),
              ),
          ],
        ),
      );

  Widget _adminView() {
    final key = dateKey(_day);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1)))),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _day,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now());
                if (d != null) setState(() => _day = d);
              },
              child: Text(fmtDate(_day), style: const TextStyle(fontSize: 16)),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: sameDay(_day, DateTime.now())
                  ? null
                  : () => setState(() => _day = _day.add(const Duration(days: 1)))),
        ]),
      ),
      Expanded(
        child: Live<Map<String, dynamic>>(
          load: () async => {'att': await Q.attendance(), 'people': await Q.staff()},
          builder: (context, data) {
            final att = (data['att'] as List<Rec>).where((r) => r['work_date'] == key).toList();
            final people = (data['people'] as List<Rec>).where((p) => p['role'] == 'employee').toList();
            if (people.isEmpty) return const EmptyState('No employees yet.');
            return ListView(children: [
              for (final p in people)
                Builder(builder: (_) {
                  final r = att.where((a) => a['user_id'] == p['id']).firstOrNull;
                  final String status = r == null || r['check_in_at'] == null
                      ? 'Missing check-in'
                      : r['check_out_at'] == null
                          ? 'Not checked out'
                          : 'Present';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text(str(p['full_name']) ?? ''),
                      subtitle: Text(r == null
                          ? status
                          : '$status \u00B7 In ${fmtTime(r['check_in_at'])}  Out ${fmtTime(r['check_out_at'])}'
                              '${r['check_in_at'] != null && r['check_out_at'] != null ? '  (${durationText(parseDt(r['check_in_at'])!, parseDt(r['check_out_at'])!)})' : ''}'),
                      trailing: Wrap(spacing: 4, children: [
                        if (r != null && isLate(r)) const Pill('Late', color: Colors.red),
                        if (r != null && r['corrected'] == true)
                          const Pill('Corrected', color: Colors.blue),
                      ]),
                      onTap: () => _correct(context, p, r, key),
                    ),
                  );
                }),
            ]);
          },
        ),
      ),
    ]);
  }

  Future<void> _correct(BuildContext context, Rec person, Rec? r, String day) async {
    DateTime? cin = parseDt(r?['check_in_at']);
    DateTime? cout = parseDt(r?['check_out_at']);
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setS) => AlertDialog(
          title: Text('Correct ${person['full_name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(
                onPressed: () async {
                  final d = await pickDateTime(dc, initial: cin);
                  if (d != null) setS(() => cin = d);
                },
                child: Text('Check-in: ${cin == null ? 'not set' : fmtDateTime(cin)}')),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: () async {
                  final d = await pickDateTime(dc, initial: cout ?? cin);
                  if (d != null) setS(() => cout = d);
                },
                child: Text('Check-out: ${cout == null ? 'not set' : fmtDateTime(cout)}')),
            const SizedBox(height: 8),
            TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason (required)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (reason.text.trim().isEmpty) return;
                  Navigator.pop(dc, true);
                },
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = attendanceId(person['id'].toString(), day);
    final row = Map<String, dynamic>.from(
        r ?? {'id': id, 'user_id': person['id'], 'work_date': day});
    row['orig_check_in_at'] ??= row['check_in_at'];
    row['orig_check_out_at'] ??= row['check_out_at'];
    row['check_in_at'] = cin?.toUtc().toIso8601String();
    row['check_out_at'] = cout?.toUtc().toIso8601String();
    row['corrected'] = true;
    row['correction_reason'] = reason.text.trim();
    row['corrected_by'] = AppAuth.instance.uid;
    await Store.put('attendance', row);
  }
}
