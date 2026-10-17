import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

/// Simple daily cash book: money in, money out.
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  DateTime _day = DateTime.now();

  Future<Map<String, dynamic>> _load() async => {'rows': await Q.finance(), 'names': await Q.names()};

  @override
  Widget build(BuildContext context) {
    final key = dateKey(_day);
    final admin = AppAuth.instance.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Income & expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context),
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
      body: Column(children: [
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
                child: Text(sameDay(_day, DateTime.now()) ? 'Today' : fmtDate(_day),
                    style: const TextStyle(fontSize: 16)),
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
            load: _load,
            builder: (context, data) {
              final all = data['rows'] as List<Rec>;
              final names = data['names'] as Map<String, String>;
              final day = all.where((r) => r['entry_date'] == key).toList();
              double sum(List<Rec> l, String kind) =>
                  l.where((r) => r['kind'] == kind).fold(0.0, (a, r) => a + toNum(r['amount']));
              final inc = sum(day, 'income'), exp = sum(day, 'expense');
              final monthPrefix = key.substring(0, 7);
              final month = all.where((r) => (r['entry_date'] ?? '').toString().startsWith(monthPrefix)).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
                Row(children: [
                  Expanded(child: Kpi('Income', money(inc), color: Colors.green.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: Kpi('Expense', money(exp), color: Colors.red.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: Kpi('Net', money(inc - exp))),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      'This month: in ${money(sum(month, 'income'))} \u00B7 out ${money(sum(month, 'expense'))} \u00B7 net ${money(sum(month, 'income') - sum(month, 'expense'))}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
                if (day.isEmpty) const EmptyState('No entries for this day.'),
                for (final r in day)
                  Card(
                    child: ListTile(
                      leading: Icon(r['kind'] == 'income' ? Icons.south_west : Icons.north_east,
                          color: r['kind'] == 'income' ? Colors.green : Colors.red),
                      title: Text(
                          '${r['kind'] == 'income' ? '+' : '-'} ${money(toNum(r['amount']))}  \u00B7  ${str(r['category']) ?? ''}'),
                      subtitle: Text(
                          '${label(str(r['pay_mode']))}${admin ? ' \u00B7 ${names[r['created_by']] ?? ''}' : ''}${(str(r['note']) ?? '').isNotEmpty ? '\n${r['note']}' : ''}'),
                      isThreeLine: (str(r['note']) ?? '').isNotEmpty,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDialog(context, 'Delete entry?',
                              'It will be removed from totals (a record is kept for audit).')) {
                            await Store.put('finance_entries', {...r, 'is_deleted': true});
                          }
                        },
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    String kind = 'income', category = incomeCategories.first, mode = 'cash';
    final amount = TextEditingController();
    final note = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sc) => StatefulBuilder(
        builder: (sc, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sc).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setS(() {
                  kind = s.first;
                  category = kind == 'income' ? incomeCategories.first : expenseCategories.first;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Amount (\u20B9)')),
              const SizedBox(height: 10),
              dropdown<String>(
                  label: 'Category',
                  value: category,
                  items: stringItems(kind == 'income' ? incomeCategories : expenseCategories, pretty: false),
                  onChanged: (v) => setS(() => category = v ?? category)),
              const SizedBox(height: 10),
              dropdown<String>(
                  label: 'Paid by',
                  value: mode,
                  items: stringItems(payModes),
                  onChanged: (v) => setS(() => mode = v ?? mode)),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (customer, bill no...)')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final a = double.tryParse(amount.text.trim());
                    if (a == null || a <= 0) {
                      toast(sc, 'Enter a valid amount.');
                      return;
                    }
                    await Store.put('finance_entries', {
                      'entry_date': dateKey(_day),
                      'kind': kind,
                      'amount': a,
                      'category': category,
                      'pay_mode': mode,
                      'note': note.text.trim().isEmpty ? null : note.text.trim(),
                      'created_by': AppAuth.instance.uid,
                      'is_deleted': false,
                    });
                    if (sc.mounted) Navigator.pop(sc);
                  },
                  child: const Text('Save entry'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
