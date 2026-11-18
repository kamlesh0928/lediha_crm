import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/util.dart';
import '../../data/app_auth.dart';
import '../../data/store.dart';

/// Records the employee's position between check-in and check-out (or when manual tracking is on).
/// While tracking, Android shows a notification and iOS shows the blue indicator.
class LocationService {
  static StreamSubscription<Position>? _sub;
  static DateTime? _lastSaved;

  /// Global reactive tracker state for UI components
  static final ValueNotifier<bool> isTracking = ValueNotifier<bool>(false);

  /// Most recent captured GPS position
  static final ValueNotifier<Position?> latestPosition = ValueNotifier<Position?>(null);

  /// Only CHECKS. It never shows a system prompt: prompts go through Permissions.ask(), so the
  /// user always reads an explanation first.
  static Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  static Future<Position?> current() async {
    try {
      if (!await ensurePermission()) return null;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 12));
      latestPosition.value = pos;
      return pos;
    } catch (_) {
      return null;
    }
  }

  /// Start background GPS tracking
  static Future<bool> start() async {
    if (_sub != null) {
      isTracking.value = true;
      return true;
    }
    if (!await ensurePermission()) {
      isTracking.value = false;
      return false;
    }

    try {
      final settings = _settings();
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
      isTracking.value = true;

      // Save initial ping right away on start so position is updated immediately
      current().then((pos) {
        if (pos != null) savePing(pos);
      });
      return true;
    } catch (e) {
      debugPrint('Location tracking start error: $e');
      isTracking.value = false;
      return false;
    }
  }

  /// Android: foreground service with a visible notification.
  /// iPhone: background location updates with the blue status-bar indicator.
  static LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        activityType: ActivityType.other,
        distanceFilter: 30,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 30,
      intervalDuration: const Duration(minutes: locationIntervalMinutes),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'LEDiHA TV Repair Service',
        notificationText: 'Live technician GPS tracking active for customer visits',
        enableWakeLock: true,
      ),
    );
  }

  /// Stop GPS tracking
  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    isTracking.value = false;
  }

  /// Toggle tracking on or off
  static Future<bool> toggleTracking() async {
    if (isTracking.value) {
      await stop();
      return false;
    } else {
      return await start();
    }
  }

  static void _onPosition(Position p) {
    latestPosition.value = p;
    final now = DateTime.now();
    if (_lastSaved != null &&
        now.difference(_lastSaved!) < const Duration(minutes: locationIntervalMinutes - 1)) {
      return;
    }
    _lastSaved = now;
    savePing(p);
  }

  static Future<void> savePing(Position p) async {
    final uid = AppAuth.instance.uid;
    if (uid == null) return;
    latestPosition.value = p;
    try {
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
    } catch (e) {
      debugPrint('Could not save location ping: $e');
    }
  }

  /// After an app restart, keep tracking if the employee is still checked in.
  static Future<void> resumeIfCheckedIn() async {
    if (AppAuth.instance.uid == null || AppAuth.instance.isAdmin) return;
    final row = await currentAttendance();
    if (row != null && row['check_in_at'] != null && row['check_out_at'] == null) {
      await start();
    }
  }
}

/// Today's attendance record - or last night's, if the employee checked in less than 16 hours ago
/// and has not checked out yet (night shifts that end after midnight).
Future<Map<String, dynamic>?> currentAttendance() async {
  final uid = AppAuth.instance.uid;
  if (uid == null) return null;
  final now = DateTime.now();
  final today = await Store.byId('attendance', attendanceId(uid, dateKey(now)));
  if (today != null) return today;
  final yesterday = await Store.byId(
      'attendance', attendanceId(uid, dateKey(now.subtract(const Duration(days: 1)))));
  final cin = parseDt(yesterday?['check_in_at']);
  if (yesterday != null &&
      cin != null &&
      yesterday['check_out_at'] == null &&
      now.difference(cin) < const Duration(hours: 16)) {
    return yesterday;
  }
  return null;
}

/// One attendance row per person per day; the same id on every device avoids duplicates.
String attendanceId(String uid, String day) =>
    const Uuid().v5(Namespace.url.value, 'lediha-attendance|$uid|$day');
