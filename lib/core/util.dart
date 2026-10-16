import 'package:intl/intl.dart';

String label(String? v) {
  if (v == null || v.isEmpty) return '-';
  final s = v.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

String? str(dynamic v) => v?.toString();

DateTime? parseDt(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

String fmtDateTime(dynamic v) {
  final d = v is DateTime ? v : parseDt(v);
  return d == null ? '-' : DateFormat('d MMM, h:mm a').format(d);
}

String fmtDate(dynamic v) {
  final d = v is DateTime ? v : parseDt(v);
  return d == null ? '-' : DateFormat('d MMM yyyy').format(d);
}

String fmtTime(dynamic v) {
  final d = v is DateTime ? v : parseDt(v);
  return d == null ? '-' : DateFormat('h:mm a').format(d);
}

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Last 10 digits - used to spot duplicate phone numbers (+91 / 0 prefixes ignored).
String normPhone(String? p) {
  final d = (p ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

double toNum(dynamic v) => v == null ? 0 : (double.tryParse(v.toString()) ?? 0);

String money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0).format(v);

String nowIso() => DateTime.now().toUtc().toIso8601String();

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime endOfToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, 23, 59, 59);
}

String durationText(DateTime a, DateTime b) {
  final m = b.difference(a).inMinutes;
  if (m < 0) return '-';
  return '${m ~/ 60}h ${m % 60}m';
}

/// WhatsApp click-to-chat number (assumes India if only 10 digits).
String waNumber(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '91$d' : d;
}
