import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import '../../data/push_service.dart';

/// Shows every permission, what it is for, whether it is on, and lets the user change it.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  Map<AppPermission, PermState> _state = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the phone's settings screen: re-check.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final m = {for (final p in AppPermission.values) p: await Permissions.state(p)};
    if (mounted) setState(() => _state = m);
  }

  Future<void> _allow(AppPermission p) async {
    final r = await Permissions.ask(context, p);
    if (r == AskResult.granted && p == AppPermission.notifications) {
      await PushService.instance.register();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App permissions')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('The app only asks for what it needs, and always explains first. '
              'You can change your choice here or in the phone settings at any time.'),
        ),
        for (final p in AppPermission.values) _card(p),
        const Card(
          child: ListTile(
            leading: Icon(Icons.block),
            title: Text('Never requested'),
            subtitle: Text('Camera, microphone, contacts, photos, files, phone calls.'),
          ),
        ),
      ]),
    );
  }

  Widget _card(AppPermission p) {
    final info = permInfo[p]!;
    final s = _state[p];
    final granted = s == PermState.granted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(info.icon),
            const SizedBox(width: 10),
            Expanded(
                child: Text(info.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            if (s != null)
              Pill(granted ? 'On' : (s == PermState.blocked ? 'Blocked' : 'Off'),
                  color: granted ? Colors.green : Colors.orange),
          ]),
          const SizedBox(height: 8),
          Text('Why: ${info.why}'),
          const SizedBox(height: 4),
          Text('When: ${info.when}'),
          const SizedBox(height: 4),
          Text('If off: ${info.ifDenied}'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            if (!granted)
              FilledButton(
                  onPressed: () => _allow(p),
                  child: Text(s == PermState.blocked ? 'Fix in settings' : 'Allow')),
            OutlinedButton(onPressed: openAppSettings, child: const Text('Phone settings')),
          ]),
        ]),
      ),
    );
  }
}
