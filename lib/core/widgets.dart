import 'package:flutter/material.dart';
import '../data/store.dart';
import 'theme.dart';
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
      : const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(color: AppColors.brandRed),
          ),
        );
}

Color statusColor(String? s) => switch (s?.toLowerCase()) {
      'new' => AppColors.statusNew,
      'contacted' => AppColors.statusContacted,
      'follow_up' => AppColors.statusFollowup,
      'converted' || 'completed' || 'done' => AppColors.statusConverted,
      'lost' => AppColors.statusLost,
      'in_progress' => AppColors.statusInProgress,
      'reopened' => AppColors.statusHot,
      'hot' => AppColors.brandRed,
      _ => Colors.grey.shade600,
    };

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Colors.grey, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(90), width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
}

/// TV Brand and Model badge
class TvBadge extends StatelessWidget {
  const TvBadge({super.key, this.brand, this.model, this.size});
  final String? brand;
  final String? model;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final hasBrand = brand != null && brand!.isNotEmpty;
    final hasModel = model != null && model!.isNotEmpty;
    if (!hasBrand && !hasModel) return const SizedBox.shrink();

    final text = [if (hasBrand) brand!, if (hasModel) model!].join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.brandTeal.withAlpha(80), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tv, size: 13, color: AppColors.brandTeal),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: size ?? 11,
                fontWeight: FontWeight.w600,
                color: AppColors.brandTealDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// LEDiHA Logo Widget
class LedihaLogo extends StatelessWidget {
  const LedihaLogo({super.key, this.height = 42, this.showTagline = true});
  final double height;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LED',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandYellow,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'iHA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 2),
          const Text(
            'Your tv Repair Partner',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? Icons.tv_off_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}

class Kpi extends StatelessWidget {
  const Kpi(this.title, this.value, {super.key, this.color, this.onTap, this.icon});
  final String title;
  final String value;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brandRed;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: c, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: c,
                    ),
                  ),
                  if (icon != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 16, color: c),
                    ),
                ],
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 3.5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            ?trailing,
          ],
        ),
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
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
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
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.brandRed,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      );
    },
  );
  if (d == null || !c.mounted) return null;
  final t = await showTimePicker(
    context: c,
    initialTime: TimeOfDay.fromDateTime(initial ?? now),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.brandRed,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      );
    },
  );
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<bool> confirmDialog(BuildContext c, String title, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: Text(msg),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dc, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
          onPressed: () => Navigator.pop(dc, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.darkSlate,
      ),
    );

Future<String?> askText(BuildContext c, String title,
    {String hint = '', bool required = true, String? initial}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dc),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
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
