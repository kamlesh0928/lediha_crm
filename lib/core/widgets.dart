import 'package:flutter/material.dart';
import '../data/store.dart';
import 'util.dart';

/// Rebuilds whenever local data changes. Wrap any screen that shows stored data.
class Live<T> extends StatefulWidget {
  const Live({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<Live<T>> createState() => _LiveState<T>();
}

class _LiveState<T> extends State<Live<T>> {
  T? _data;
  bool _has = false;

  @override
  void initState() {
    super.initState();
    Store.version.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    Store.version.removeListener(_reload);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Live<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reload();
  }

  Future<void> _reload() async {
    final d = await widget.load();
    if (!mounted) return;
    setState(() {
      _data = d;
      _has = true;
    });
  }

  @override
  Widget build(BuildContext context) => _has
      ? widget.builder(context, _data as T)
      : const Center(child: CircularProgressIndicator());
}

Color statusColor(String? s) => switch (s) {
      'new' => Colors.blue,
      'contacted' => Colors.orange,
      'follow_up' => Colors.purple,
      'converted' || 'completed' || 'done' => Colors.green,
      'lost' => Colors.red,
      'in_progress' => Colors.orange,
      'reopened' => Colors.deepOrange,
      _ => Colors.grey,
    };

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Colors.grey});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(31),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(115)),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ),
      );
}

class Kpi extends StatelessWidget {
  const Kpi(this.title, this.value, {super.key, this.color, this.onTap});
  final String title;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: color ?? Theme.of(context).colorScheme.primary)),
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

/// Drop-down that always shows the value you pass in (so it stays correct after a sync).
Widget dropdown<T>({
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  final ok = items.any((i) => i.value == value);
  return InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: ok ? value : null,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        isDense: true,
      ),
    ),
  );
}

List<DropdownMenuItem<String>> stringItems(List<String> values, {bool pretty = true}) =>
    values.map((v) => DropdownMenuItem(value: v, child: Text(pretty ? label(v) : v))).toList();

Future<DateTime?> pickDateTime(BuildContext c, {DateTime? initial}) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: c,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 2),
  );
  if (d == null || !c.mounted) return null;
  final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(initial ?? now));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<bool> confirmDialog(BuildContext c, String title, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (dc) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Confirm')),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<String?> askText(BuildContext c, String title,
    {String hint = '', bool required = true, String? initial}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (dc) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (required && ctl.text.trim().isEmpty) return;
            Navigator.pop(dc, ctl.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
