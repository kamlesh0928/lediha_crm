import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/store.dart';

/// Every permission the app can ask for. Add new ones here and in [permInfo].
enum AppPermission { location, notifications }

enum PermState { granted, denied, blocked }

/// granted = user allowed it; denied = user (or the phone) said no;
/// skipped = user chose "Not now" on OUR explanation, so no system prompt was shown.
enum AskResult { granted, denied, skipped }

class PermInfo {
  const PermInfo({
    required this.icon,
    required this.title,
    required this.why,
    required this.when,
    required this.ifDenied,
  });
  final IconData icon;
  final String title, why, when, ifDenied;
}

const permInfo = <AppPermission, PermInfo>{
  AppPermission.location: PermInfo(
    icon: Icons.location_on_outlined,
    title: 'Location',
    why: 'Records where field work happens, so the company can see visits and routes.',
    when: 'Only between Check in and Check out. Nothing is recorded outside work time. '
        'Your phone shows a notification or indicator while it is on.',
    ifDenied: 'You can still check in, but your position is not saved.',
  ),
  AppPermission.notifications: PermInfo(
    icon: Icons.notifications_outlined,
    title: 'Notifications',
    why: 'Alerts for new leads, tasks and messages, even when the app is closed. '
        'Also needed for the notice shown while location is being recorded.',
    when: 'Whenever something new is assigned to you or someone messages you.',
    ifDenied: 'You will only see new items when you open the app.',
  ),
};

/// One place for every permission request. The rule: the user ALWAYS sees our explanation
/// first, and the system prompt appears only after they tap Continue.
class Permissions {
  static Future<PermState> state(AppPermission p) async {
    switch (p) {
      case AppPermission.location:
        final loc = await Geolocator.checkPermission();
        if (loc == LocationPermission.always || loc == LocationPermission.whileInUse) {
          return PermState.granted;
        }
        return loc == LocationPermission.deniedForever ? PermState.blocked : PermState.denied;
      case AppPermission.notifications:
        final note = await Permission.notification.status;
        if (note.isGranted || note.isProvisional) return PermState.granted;
        return note.isPermanentlyDenied ? PermState.blocked : PermState.denied;
    }
  }

  /// Explain, then ask. Safe to call every time: if already granted it returns at once.
  static Future<AskResult> ask(BuildContext context, AppPermission p) async {
    var s = await state(p);
    if (s == PermState.granted) return AskResult.granted;
    if (!context.mounted) return AskResult.skipped;

    if (s == PermState.blocked) {
      if (await _explain(context, p, blocked: true)) await openAppSettings();
      return AskResult.denied;
    }
    if (!await _explain(context, p)) return AskResult.skipped;

    if (p == AppPermission.location) {
      await Geolocator.requestPermission();
    } else {
      await Permission.notification.request();
    }
    s = await state(p);
    if (s != PermState.granted) return AskResult.denied;

    if (p == AppPermission.location &&
        !await Geolocator.isLocationServiceEnabled() &&
        context.mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dc) => AlertDialog(
          title: const Text('Switch on GPS'),
          content: const Text('Location is allowed, but your phone\'s location switch is off. '
              'Turn it on so your position can be recorded.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Later')),
            FilledButton(
                onPressed: () => Navigator.pop(dc, true), child: const Text('Open settings')),
          ],
        ),
      );
      if (open == true) await Geolocator.openLocationSettings();
    }
    return AskResult.granted;
  }

  static Future<bool> _explain(BuildContext context, AppPermission p, {bool blocked = false}) async {
    final info = permInfo[p]!;
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        icon: Icon(info.icon, size: 36),
        title: Text(blocked ? '${info.title} is turned off' : 'Allow ${info.title.toLowerCase()}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line('Why we need it', info.why),
              _line('When it is used', info.when),
              _line('If you say no', info.ifDenied),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  blocked
                      ? 'It was blocked earlier. You can switch it on in your phone settings.'
                      : 'Your phone will ask you to confirm after you tap Continue.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(blocked ? 'Cancel' : 'Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(blocked ? 'Open settings' : 'Continue')),
        ],
      ),
    );
    return r ?? false;
  }

  static Widget _line(String head, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(head, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(text),
        ]),
      );

  /// First sign-in on this phone: list everything the app may ask for, before any prompt.
  static Future<void> showIntroOnce(BuildContext context) async {
    if (await Store.getMeta('perm_intro_done') == '1') return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Permissions this app uses'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LEDiHA CRM will ask for the permissions below. Before each one you '
                  'will see a short explanation, and you can say no.'),
              const SizedBox(height: 12),
              for (final p in AppPermission.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(permInfo[p]!.icon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(permInfo[p]!.title,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(permInfo[p]!.why, style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              const Text(
                'Not used: camera, microphone, contacts, photos, files or phone calls. '
                'The Call button only opens your dialer, and choosing a CSV file uses the '
                'phone\'s own file picker.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dc), child: const Text('Continue')),
        ],
      ),
    );
    await Store.setMeta('perm_intro_done', '1');
  }
}
