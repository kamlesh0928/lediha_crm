import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

/// Simple daily cash book: TV repair payments received, spare parts expenses, etc.
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
      appBar: AppBar(title: const Text('TV Repair Cash Book')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        onPressed: () => _addEntry(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Date Selector
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

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Kpi('Cash In', money(inc), color: Colors.green.shade700, icon: Icons.arrow_downward)),
                        const SizedBox(width: 8),
                        Expanded(child: Kpi('Expense', money(exp), color: Colors.red.shade700, icon: Icons.arrow_upward)),
                        const SizedBox(width: 8),
                        Expanded(child: Kpi('Net Day', money(inc - exp), color: AppColors.brandTealDark, icon: Icons.account_balance_wallet)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        'This Month: Received ${money(sum(month, 'income'))} \u00B7 Spent ${money(sum(month, 'expense'))} \u00B7 Net Profit ${money(sum(month, 'income') - sum(month, 'expense'))}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (day.isEmpty) const EmptyState('No income or expense entries recorded for this day.', icon: Icons.payments),
                    for (final r in day)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: r['kind'] == 'income' ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(
                              r['kind'] == 'income' ? Icons.south_west : Icons.north_east,
                              color: r['kind'] == 'income' ? Colors.green : Colors.red,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${r['kind'] == 'income' ? '+' : '-'} ${money(toNum(r['amount']))}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: r['kind'] == 'income' ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  str(r['category']) ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Paid by ${label(str(r['pay_mode']))}${admin ? ' \u00B7 ${names[r['created_by']] ?? ''}' : ''}'
                            '${(str(r['note']) ?? '').isNotEmpty ? '\n${r['note']}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: (str(r['note']) ?? '').isNotEmpty,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            onPressed: () async {
                              if (await confirmDialog(
                                context,
                                'Delete cash entry?',
                                'It will be removed from daily and monthly totals.',
                              )) {
                                await Store.put('finance_entries', {...r, 'is_deleted': true});
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'income', label: Text('Income (Received)')),
                    ButtonSegment(value: 'expense', label: Text('Expense (Spent)')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setS(() {
                    kind = s.first;
                    category = kind == 'income' ? incomeCategories.first : expenseCategories.first;
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount (\u20B9) *',
                    prefixIcon: Icon(Icons.currency_rupee, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                dropdown<String>(
                  label: 'Category',
                  value: category,
                  items: stringItems(kind == 'income' ? incomeCategories : expenseCategories, pretty: false),
                  onChanged: (v) => setS(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                dropdown<String>(
                  label: 'Payment Mode',
                  value: mode,
                  items: stringItems(payModes),
                  onChanged: (v) => setS(() => mode = v ?? mode),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Notes (customer name, TV brand, receipt / bill no)',
                    prefixIcon: Icon(Icons.notes, size: 20),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
                    onPressed: () async {
                      final a = double.tryParse(amount.text.trim());
                      if (a == null || a <= 0) {
                        toast(sc, 'Please enter a valid amount.');
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
                    child: const Text('Save Cash Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
