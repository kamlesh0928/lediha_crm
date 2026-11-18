import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import 'location_service.dart';

/// Employee screen: View live location, route of the day, and toggle tracking.
class MyLocationPage extends StatefulWidget {
  const MyLocationPage({super.key});

  @override
  State<MyLocationPage> createState() => _MyLocationPageState();
}

class _MyLocationPageState extends State<MyLocationPage> {
  final MapController _mapController = MapController();
  Position? _currentPos;
  List<LatLng> _routePoints = [];
  bool _loading = true;
  bool _refreshingLocation = false;
  String? _statusNote;

  @override
  void initState() {
    super.initState();
    _loadLocationAndRoute();
  }

  Future<void> _loadLocationAndRoute() async {
    setState(() => _loading = true);
    try {
      final pos = await LocationService.current();
      _currentPos = pos;

      final uid = AppAuth.instance.uid;
      if (uid != null) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

        try {
          final rows = await Supabase.instance.client
              .from('location_pings')
              .select('lat,lng,recorded_at')
              .eq('user_id', uid)
              .gte('recorded_at', start)
              .order('recorded_at', ascending: true)
              .limit(500);

          _routePoints = [
            for (final r in rows) LatLng(toNum(r['lat']), toNum(r['lng']))
          ];
        } catch (_) {
          // Offline
          _statusNote = 'Viewing offline cached location';
        }
      }
    } catch (e) {
      _statusNote = 'Could not get current location: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pingNow() async {
    setState(() => _refreshingLocation = true);
    final pos = await LocationService.current();
    if (pos != null) {
      await LocationService.savePing(pos);
      _currentPos = pos;
      _routePoints.add(LatLng(pos.latitude, pos.longitude));
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      if (mounted) toast(context, 'Location updated & sent to admin.');
    } else {
      if (mounted) toast(context, 'Please turn on GPS in your phone settings.');
    }
    if (mounted) setState(() => _refreshingLocation = false);
  }

  Future<void> _toggleTrackingSwitch(bool enable) async {
    if (enable) {
      final res = await Permissions.ask(context, AppPermission.location);
      if (res != AskResult.granted) return;
      await LocationService.start();
      _pingNow();
    } else {
      await LocationService.stop();
      if (mounted) toast(context, 'Location tracking paused.');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentPos != null
        ? LatLng(_currentPos!.latitude, _currentPos!.longitude)
        : (_routePoints.isNotEmpty ? _routePoints.last : const LatLng(18.5204, 73.8567));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Location & Route'),
        actions: [
          IconButton(
            icon: _refreshingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Update position now',
            onPressed: _refreshingLocation ? null : _pingNow,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : Column(
              children: [
                // Top Tracking Status Card
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: LocationService.isTracking,
                    builder: (context, tracking, _) {
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tracking
                                  ? AppColors.brandTeal.withAlpha(20)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              tracking ? Icons.gps_fixed : Icons.gps_off,
                              color: tracking ? AppColors.brandTeal : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      tracking ? 'GPS Tracking Active' : 'GPS Tracking Paused',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: tracking ? AppColors.brandTealDark : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (tracking)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tracking
                                      ? 'Records field visits & route during shift'
                                      : 'Tap switch to turn on tracking',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: tracking,
                            activeThumbColor: AppColors.brandTeal,
                            onChanged: _toggleTrackingSwitch,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_statusNote != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.brandYellowLight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(_statusNote!, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  ),
                const Divider(height: 1),

                // Map View
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.lediha.crm',
                          ),
                          if (_routePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  strokeWidth: 4.5,
                                  color: AppColors.brandTeal,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_currentPos != null)
                                Marker(
                                  point: LatLng(_currentPos!.latitude, _currentPos!.longitude),
                                  width: 60,
                                  height: 60,
                                  child: const Column(
                                    children: [
                                      Icon(Icons.location_on, color: AppColors.brandRed, size: 38),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          RichAttributionWidget(
                            attributions: [TextSourceAttribution('\u00A9 OpenStreetMap contributors')],
                          ),
                        ],
                      ),

                      // Re-center FAB
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandRed,
                          onPressed: () {
                            if (_currentPos != null) {
                              _mapController.move(
                                  LatLng(_currentPos!.latitude, _currentPos!.longitude), 16);
                            }
                          },
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Coordinates & Info Panel
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CURRENT POSITION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _currentPos != null
                                        ? '${_currentPos!.latitude.toStringAsFixed(5)}, ${_currentPos!.longitude.toStringAsFixed(5)}'
                                        : 'Waiting for GPS fix...',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Pill(
                              '${_routePoints.length} points today',
                              color: AppColors.brandTeal,
                              icon: Icons.timeline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Refresh GPS'),
                                onPressed: _pingNow,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('Send Ping'),
                                onPressed: _pingNow,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
