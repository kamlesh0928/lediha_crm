import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

const _maxRows = 1000;

/// Column names we recognise (lower-case). The first matching column wins.
const _aliases = <String, List<String>>{
  'customer_name': ['customer_name', 'customer name', 'name', 'full name', 'full_name', 'client'],
  'phone': ['phone', 'mobile', 'mobile number', 'phone number', 'contact', 'contact number', 'whatsapp'],
  'email': ['email', 'e-mail', 'email id'],
  'area': ['area', 'city', 'location', 'address', 'pincode'],
  'tv_brand': ['tv_brand', 'tv brand', 'brand', 'make'],
  'tv_model': ['tv_model', 'tv model', 'model'],
  'issue': ['issue', 'problem', 'complaint', 'tv_issue'],
  'notes': ['notes', 'note', 'remarks', 'comment', 'comments'],
  'source': ['source', 'lead source'],
  'priority': ['priority'],
};

const _sampleCsv = 'name,phone,email,area,tv_brand,tv_model,issue,notes,priority\n'
    'Ramesh Patil,9876543210,ramesh@example.com,Pune,Samsung,UA43T5350,No display,Prefers evening calls,hot\n'
    'Sunita Shah,9123456780,,Pimpri,LG,43UM7290,Sound problem,,medium\n';

class _ImportRow {
  _ImportRow(this.line, this.values);
  final int line;
  final Map<String, String> values;
  String? error;
  bool duplicate = false;
  bool get ok => error == null;
}

/// Admin: bring in existing customers from an Excel/CSV file.
class LeadImportPage extends StatefulWidget {
  const LeadImportPage({super.key});

  @override
  State<LeadImportPage> createState() => _LeadImportPageState();
}

class _LeadImportPageState extends State<LeadImportPage> {
  List<_ImportRow> _rows = [];
  String? _fileName;
  String? _problem;
  bool _importDuplicates = false;
  bool _busy = false;
  String? _assignTo;
  List<Rec> _staff = [];

  @override
  void initState() {
    super.initState();
    Q.staff().then((s) {
      if (mounted) setState(() => _staff = s);
    });
  }

  Future<void> _shareSample() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}lediha_leads_sample.csv');
    await f.writeAsString(_sampleCsv);
    await Share.shareXFiles([XFile(f.path)], subject: 'LEDiHA sample leads file');
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      // The phone's own file picker: the app never gets access to other files.
      final res = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: const ['csv', 'txt'], withData: true);
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        final bytes = f.bytes ?? await File(f.path!).readAsBytes();
        await _parse(f.name, bytes);
      }
    } catch (e) {
      _problem = 'Could not read the file: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _parse(String name, List<int> bytes) async {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Excel may save with ; or tab instead of comma: pick the one used most in the first line.
    final first = text.split('\n').first;
    var delim = ',';
    var best = ','.allMatches(first).length;
    for (final d in [';', '\t']) {
      final n = d.allMatches(first).length;
      if (n > best) {
        best = n;
        delim = d;
      }
    }
    final table = CsvToListConverter(fieldDelimiter: delim, eol: '\n', shouldParseNumbers: false)
        .convert(text);
    _rows = [];
    _fileName = name;
    if (table.length < 2) {
      _problem = 'The file has no data rows. The first row must contain the column names.';
      return;
    }
    final header = table.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final index = <String, int>{};
    _aliases.forEach((field, names) {
      for (var i = 0; i < header.length; i++) {
        if (names.contains(header[i]) && !index.containsKey(field)) index[field] = i;
      }
    });
    if (!index.containsKey('customer_name') || !index.containsKey('phone')) {
      _problem = 'Column names not recognised. The first row needs at least "name" and "phone". '
          'Use "Get sample file" to see the format.';
      return;
    }

    final existing = {for (final l in await Q.leads()) normPhone(str(l['phone']))};
    final seen = <String>{};
    final rows = <_ImportRow>[];
    for (var i = 1; i < table.length && rows.length < _maxRows; i++) {
      final r = table[i];
      if (r.every((c) => c.toString().trim().isEmpty)) continue;
      String cell(String f) {
        final k = index[f];
        return (k == null || k >= r.length) ? '' : r[k].toString().trim();
      }

      final row = _ImportRow(i + 1, {for (final f in _aliases.keys) f: cell(f)});
      final phone = row.values['phone']!;
      if (row.values['customer_name']!.isEmpty) {
        row.error = 'Name is empty';
      } else if (phone.contains(RegExp(r'[eE]\+'))) {
        row.error = 'Phone is in scientific format (format that column as Text in Excel)';
      } else if (normPhone(phone).length < 10) {
        row.error = 'Phone needs 10 digits';
      } else {
        final n = normPhone(phone);
        if (existing.contains(n) || !seen.add(n)) row.duplicate = true;
      }
      rows.add(row);
    }
    _rows = rows;
    if (table.length - 1 > _maxRows) {
      _problem = 'Only the first $_maxRows rows are read. Split bigger files into parts.';
    }
  }

  List<_ImportRow> get _toImport =>
      _rows.where((r) => r.ok && (!r.duplicate || _importDuplicates)).toList();

  Future<void> _import() async {
    final list = _toImport;
    if (list.isEmpty) return;
    setState(() => _busy = true);
    String? nz(String? v) => (v == null || v.isEmpty) ? null : v;
    final data = <Map<String, dynamic>>[];
    for (final r in list) {
      final v = r.values;
      final src = (v['source'] ?? '').toLowerCase().replaceAll(' ', '_');
      final pr = (v['priority'] ?? '').toLowerCase();
      data.add({
        'id': const Uuid().v4(),
        'customer_name': v['customer_name'],
        'phone': v['phone'],
        'email': nz(v['email']),
        'area': nz(v['area']),
        'tv_brand': nz(v['tv_brand']),
        'tv_model': nz(v['tv_model']),
        'issue': nz(v['issue']),
        'notes': nz(v['notes']),
        'source': leadSources.contains(src) ? src : 'csv',
        'campaign': 'CSV import', // the server sends no alert for each imported lead
        'status': 'new',
        'priority': leadPriorities.contains(pr) ? pr : 'medium',
        'assigned_to': _assignTo,
        'received_at': nowIso(),
        'is_deleted': false,
        'created_by': AppAuth.instance.uid,
      });
    }
    await Store.putMany('leads', data);
    if (!mounted) return;
    toast(context, 'Imported ${data.length} leads. They upload in the background.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _rows.where((r) => r.ok && !r.duplicate).length;
    final dup = _rows.where((r) => r.ok && r.duplicate).length;
    final bad = _rows.where((r) => !r.ok).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Import leads (CSV)')),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _busy || _toImport.isEmpty ? null : _import,
                  child: Text('Import ${_toImport.length} leads'),
                ),
              ),
            ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Text('Choose a CSV file saved from Excel or Google Sheets. The first row must be the '
            'column names; "name" and "phone" are required. Other columns: email, area, tv_brand, '
            'tv_model, issue, notes, source, priority.'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose CSV file')),
          OutlinedButton.icon(
              onPressed: _shareSample,
              icon: const Icon(Icons.download),
              label: const Text('Get sample file')),
        ]),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (_problem != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_problem!, style: const TextStyle(color: Colors.red))),
        if (_rows.isNotEmpty) ...[
          SectionTitle('${_fileName ?? ''}: $ok new, $dup duplicate, $bad with problems'),
          dropdown<String?>(
            label: 'Assign all imported leads to',
            value: _assignTo,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Nobody (assign later)')),
              for (final p in _staff)
                DropdownMenuItem<String?>(
                    value: p['id'].toString(), child: Text(str(p['full_name']) ?? '')),
            ],
            onChanged: (v) => setState(() => _assignTo = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Also import duplicates'),
            subtitle: const Text('Duplicate = phone number already in the app or repeated in the file'),
            value: _importDuplicates,
            onChanged: (v) => setState(() => _importDuplicates = v),
          ),
          for (final r in _rows.take(100))
            ListTile(
              dense: true,
              leading: Icon(
                r.ok ? (r.duplicate ? Icons.content_copy : Icons.check_circle) : Icons.error,
                color: r.ok ? (r.duplicate ? Colors.orange : Colors.green) : Colors.red,
              ),
              title: Text('${r.values['customer_name']}  ${r.values['phone']}'),
              subtitle: Text('Row ${r.line}${r.error != null ? ': ${r.error}' : (r.duplicate ? ': duplicate' : '')}'),
            ),
          if (_rows.length > 100)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text('...and ${_rows.length - 100} more rows', style: const TextStyle(color: Colors.grey))),
        ],
      ]),
    );
  }
}
