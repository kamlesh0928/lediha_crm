import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../data/auth_state.dart';
import '../../data/store.dart';

/// Records the employee's position ONLY between check-in and check-out.
/// While tracking, Android shows a permanent notification (required by the OS).
class LocationService {
  static StreamSubscription<Position>? _sub;
  static DateTime? _lastSaved;

  static Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  static Future<Position?> current() async {
    try {
      if (!await ensurePermission()) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  static Future<void> start() async {
    if (_sub != null) return;
    if (!await ensurePermission()) return;
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 30,
      intervalDuration: const Duration(minutes: locationIntervalMinutes),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'LEDiHA CRM',
        notificationText: 'Location is recorded while you are checked in',
        enableWakeLock: true,
      ),
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static void _onPosition(Position p) {
    final now = DateTime.now();
    if (_lastSaved != null &&
        now.difference(_lastSaved!) < const Duration(minutes: locationIntervalMinutes - 1)) {
      return;
    }
    _lastSaved = now;
    savePing(p);
  }

  static Future<void> savePing(Position p) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    await Store.put(
      'location_pings',
      {
        'id': const Uuid().v4(),
        'user_id': uid,
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
        'recorded_at': nowIso(),
      },
      cache: false,
    );
  }

  /// After an app restart, keep tracking if the employee is still checked in.
  static Future<void> resumeIfCheckedIn() async {
    final uid = AuthState.instance.uid;
    if (uid == null || AuthState.instance.isAdmin) return;
    final row = await Store.byId('attendance', attendanceId(uid, dateKey(DateTime.now())));
    if (row != null && row['check_in_at'] != null && row['check_out_at'] == null) {
      await start();
    }
  }
}

/// One attendance row per person per day; the same id on every device avoids duplicates.
String attendanceId(String uid, String day) =>
    const Uuid().v5(Namespace.url.value, 'lediha-attendance|$uid|$day');
