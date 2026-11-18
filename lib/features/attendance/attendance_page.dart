import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../location/location_service.dart';
import '../location/my_location_page.dart';
import '../location/team_map_page.dart';

bool isLate(Rec r) {
  final cin = parseDt(r['check_in_at']);
  if (cin == null) return false;
  final limit = DateTime(cin.year, cin.month, cin.day, shiftStartHour, shiftStartMinute)
      .add(const Duration(minutes: lateGraceMinutes));
  return cin.isAfter(limit);
}

Future<void> doCheckIn(BuildContext context) async {
  final uid = AppAuth.instance.uid!;
  // Explain first, then ask. "Not now" cancels the check-in; if the phone then refuses, the
  // check-in still works, just without a position.
  if (await Permissions.ask(context, AppPermission.location) == AskResult.skipped) return;
  if (!context.mounted) return;
  final existing = await currentAttendance();
  if (existing != null && existing['check_in_at'] != null) return; // already checked in today
  final pos = await LocationService.current();
  final now = DateTime.now();
  final id = attendanceId(uid, dateKey(now));
  final row = existing != null
      ? Map<String, dynamic>.from(existing)
      : <String, dynamic>{'id': id, 'user_id': uid, 'work_date': dateKey(now)};
  row['check_in_at'] = now.toUtc().toIso8601String();
  row['check_in_lat'] = pos?.latitude;
  row['check_in_lng'] = pos?.longitude;
  await Store.put('attendance', row);
  if (pos != null) await LocationService.savePing(pos);
  await LocationService.start();
  if (context.mounted) {
    toast(context, pos == null ? 'Checked in (GPS position not available).' : 'Checked in \u2014 GPS tracking active.');
  }
}

Future<void> doCheckOut(BuildContext context) async {
  final row = await currentAttendance();
  if (row == null || row['check_in_at'] == null || row['check_out_at'] != null) return;
  final pos = await LocationService.current();
  final out = Map<String, dynamic>.from(row);
  out['check_out_at'] = DateTime.now().toUtc().toIso8601String();
  out['check_out_lat'] = pos?.latitude;
  out['check_out_lng'] = pos?.longitude;
  await Store.put('attendance', out);
  if (pos != null) await LocationService.savePing(pos);
  await LocationService.stop();
  if (context.mounted) toast(context, 'Checked out \u2014 GPS tracking paused.');
}

/// Big check-in / check-out card (used on the dashboard and attendance screen).
class AttendanceControl extends StatelessWidget {
  const AttendanceControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Live<Rec?>(
      load: currentAttendance,
      builder: (context, row) {
        final cin = row?['check_in_at'];
        final cout = row?['check_out_at'];
        final startedToday = cin != null && sameDay(parseDt(cin)!, DateTime.now());
        final String status = cin == null
            ? 'Not Checked In'
            : cout == null
                ? 'On Duty \u00B7 In at ${startedToday ? fmtTime(cin) : fmtDateTime(cin)}'
                : 'Shift Completed (${durationText(parseDt(cin)!, parseDt(cout)!)})';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cin == null
                                ? Colors.grey.shade100
                                : (cout == null ? AppColors.brandTealLight : Colors.green.shade50),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            cin == null
                                ? Icons.access_time
                                : (cout == null ? Icons.work : Icons.check_circle),
                            size: 18,
                            color: cin == null
                                ? Colors.grey
                                : (cout == null ? AppColors.brandTeal : Colors.green),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Shift \u00B7 ${fmtDate(DateTime.now())}",
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: cin == null
                                    ? AppColors.textPrimary
                                    : (cout == null ? AppColors.brandTealDark : Colors.green.shade800),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (row != null && isLate(row))
                      const Pill('Late', color: Colors.red, icon: Icons.warning_amber),
                  ],
                ),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    if (cin == null)
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandRed,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => doCheckIn(context),
                          icon: const Icon(Icons.login),
                          label: const Text('Check In (Start Service)'),
                        ),
                      )
                    else if (cout == null) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.deepOrange.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => doCheckOut(context),
                          icon: const Icon(Icons.logout),
                          label: const Text('Check Out'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandTeal,
                          side: const BorderSide(color: AppColors.brandTeal),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyLocationPage()),
                        ),
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('My GPS'),
                      ),
                    ] else
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandTeal,
                            side: const BorderSide(color: AppColors.brandTeal),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyLocationPage()),
                          ),
                          icon: const Icon(Icons.route, size: 16),
                          label: const Text('View Today\'s Route History'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
      appBar: AppBar(
        title: const Text('Technician Attendance'),
        actions: [
          if (admin)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'View on Live Map',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeamMapPage(initialDate: _day)),
              ),
            ),
        ],
      ),
      body: admin ? _adminView() : _employeeView(),
    );
  }

  Widget _employeeView() => Live<List<Rec>>(
        load: Q.attendance,
        builder: (context, rows) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            const AttendanceControl(),
            const SectionTitle('My Attendance & Visit History'),
            if (rows.isEmpty) const EmptyState('No attendance records yet.'),
            for (final r in rows.take(45))
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: r['check_out_at'] != null
                        ? Colors.green.shade50
                        : (r['check_in_at'] != null ? AppColors.brandTealLight : Colors.grey.shade100),
                    child: Icon(
                      r['check_out_at'] != null ? Icons.check : Icons.access_time,
                      color: r['check_out_at'] != null ? Colors.green : AppColors.brandTeal,
                      size: 18,
                    ),
                  ),
                  title: Text(fmtDate(r['work_date']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In ${fmtTime(r['check_in_at'])}   Out ${fmtTime(r['check_out_at'])}'
                        '${r['check_in_at'] != null && r['check_out_at'] != null ? '   (${durationText(parseDt(r['check_in_at'])!, parseDt(r['check_out_at'])!)})' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (r['check_in_lat'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: AppColors.brandTeal),
                              const SizedBox(width: 4),
                              Text(
                                'GPS recorded: ${toNum(r['check_in_lat']).toStringAsFixed(4)}, ${toNum(r['check_in_lng']).toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (isLate(r)) const Pill('Late', color: Colors.red),
                      if (r['corrected'] == true) const Pill('Corrected', color: Colors.blue),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _adminView() {
    final key = dateKey(_day);
    return Column(
      children: [
        // Date Selector Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.brandRed),
                onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.brandRed),
                  label: Text(
                    sameDay(_day, DateTime.now()) ? 'Today (${fmtDate(_day)})' : fmtDate(_day),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(primary: AppColors.brandRed, onPrimary: Colors.white),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setState(() => _day = d);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.brandRed),
                onPressed: sameDay(_day, DateTime.now())
                    ? null
                    : () => setState(() => _day = _day.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Live<Map<String, dynamic>>(
            load: () async => {'att': await Q.attendance(), 'people': await Q.staff()},
            builder: (context, data) {
              final att = (data['att'] as List<Rec>).where((r) => r['work_date'] == key).toList();
              final people = (data['people'] as List<Rec>).where((p) => p['role'] == 'employee').toList();
              if (people.isEmpty) return const EmptyState('No employees found.');

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: people.length,
                itemBuilder: (_, i) {
                  final p = people[i];
                  final r = att.where((a) => a['user_id'] == p['id']).firstOrNull;
                  final String status = r == null || r['check_in_at'] == null
                      ? 'Absent / Not Checked In'
                      : r['check_out_at'] == null
                          ? 'On Duty (Checked In)'
                          : 'Present (Shift Done)';

                  final hasGps = r != null && (r['check_in_lat'] != null || r['check_out_lat'] != null);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: r == null || r['check_in_at'] == null
                            ? Colors.red.shade50
                            : (r['check_out_at'] == null ? AppColors.brandTealLight : Colors.green.shade50),
                        child: Icon(
                          r == null || r['check_in_at'] == null
                              ? Icons.person_off
                              : (r['check_out_at'] == null ? Icons.handyman : Icons.check),
                          color: r == null || r['check_in_at'] == null
                              ? Colors.red
                              : (r['check_out_at'] == null ? AppColors.brandTeal : Colors.green),
                          size: 18,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              str(p['full_name']) ?? 'Staff',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          if (hasGps)
                            IconButton(
                              icon: const Icon(Icons.map, color: AppColors.brandTeal, size: 20),
                              tooltip: 'View Route on Map',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeamMapPage(
                                    selectedUserId: p['id'].toString(),
                                    initialDate: _day,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r == null
                                ? status
                                : '$status \u00B7 In ${fmtTime(r['check_in_at'])}${r['check_out_at'] != null ? ' - Out ${fmtTime(r['check_out_at'])}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: r == null ? Colors.red.shade700 : AppColors.textPrimary,
                            ),
                          ),
                          if (r != null && r['check_in_lat'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'GPS: ${toNum(r['check_in_lat']).toStringAsFixed(4)}, ${toNum(r['check_in_lng']).toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (r != null && isLate(r)) const Pill('Late', color: Colors.red),
                          if (r != null && r['corrected'] == true) const Pill('Corrected', color: Colors.blue),
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: AppColors.brandRed),
                            tooltip: 'Correct attendance',
                            onPressed: () => _correct(context, p, r, key),
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
    );
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final d = await pickDateTime(dc, initial: cin);
                  if (d != null) setS(() => cin = d);
                },
                child: Text('Check-in: ${cin == null ? 'not set' : fmtDateTime(cin)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final d = await pickDateTime(dc, initial: cout ?? cin);
                  if (d != null) setS(() => cout = d);
                },
                child: Text('Check-out: ${cout == null ? 'not set' : fmtDateTime(cout)}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason (required)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().isEmpty) return;
                Navigator.pop(dc, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = attendanceId(person['id'].toString(), day);
    final row = Map<String, dynamic>.from(r ?? {'id': id, 'user_id': person['id'], 'work_date': day});
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
