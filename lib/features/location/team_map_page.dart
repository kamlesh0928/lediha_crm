import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../followups/followups_page.dart';

/// Admin: Live team location tracking, individual route playback, and staff whereabouts.
class TeamMapPage extends StatefulWidget {
  const TeamMapPage({super.key, this.selectedUserId, this.initialDate});
  final String? selectedUserId;
  final DateTime? initialDate;

  @override
  State<TeamMapPage> createState() => _TeamMapPageState();
}

class _TeamMapPageState extends State<TeamMapPage> {
  final MapController _map = MapController();
  List<Rec> _people = [];
  List<Rec> _allStaff = [];
  List<LatLng> _route = [];
  String? _selected;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _note;
  double _totalDistanceKm = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.selectedUserId != null) _selected = widget.selectedUserId;
    if (widget.initialDate != null) _selectedDate = widget.initialDate!;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _allStaff = await Q.staff();
    try {
      final res = await Supabase.instance.client.rpc('latest_locations');
      _people = List<Rec>.from((res as List).map((e) => Map<String, dynamic>.from(e as Map)));
      await Store.setMeta('last_locations', jsonEncode(_people));
      _note = null;
    } catch (_) {
      final cached = await Store.getMeta('last_locations');
      if (cached != null) {
        _people = List<Rec>.from((jsonDecode(cached) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }

      // If still empty, construct from attendance check-in/check-out pings
      if (_people.isEmpty) {
        final attList = await Q.attendance();
        final todayKey = dateKey(_selectedDate);
        final todayAtt = attList.where((a) => a['work_date'] == todayKey).toList();
        final names = await Q.names();
        _people = [
          for (final a in todayAtt)
            if (a['check_in_lat'] != null && a['check_in_lng'] != null)
              {
                'user_id': a['user_id'],
                'full_name': names[a['user_id']] ?? 'Technician',
                'lat': a['check_out_lat'] ?? a['check_in_lat'],
                'lng': a['check_out_lng'] ?? a['check_in_lng'],
                'recorded_at': a['check_out_at'] ?? a['check_in_at'],
              }
        ];
      }
      _note = 'Offline - showing last saved positions.';
    }

    if (_selected != null) {
      final p = _people.where((x) => x['user_id']?.toString() == _selected).firstOrNull;
      if (p != null) {
        _showRoute(p);
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showRoute(Rec p) async {
    setState(() {
      _selected = p['user_id']?.toString();
      _route = [];
      _totalDistanceKm = 0.0;
    });

    final lat = toNum(p['lat']);
    final lng = toNum(p['lng']);
    if (lat != 0 && lng != 0) {
      _map.move(LatLng(lat, lng), 14.5);
    }

    try {
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
          .toUtc()
          .toIso8601String();
      final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();

      final rows = await Supabase.instance.client
          .from('location_pings')
          .select('lat,lng,recorded_at')
          .eq('user_id', p['user_id'])
          .gte('recorded_at', start)
          .lte('recorded_at', end)
          .order('recorded_at', ascending: true)
          .limit(1000);

      final pts = [for (final r in rows) LatLng(toNum(r['lat']), toNum(r['lng']))];

      // Calculate approximate distance
      double dist = 0.0;
      for (int i = 0; i < pts.length - 1; i++) {
        dist += Geolocator.distanceBetween(
          pts[i].latitude,
          pts[i].longitude,
          pts[i + 1].latitude,
          pts[i + 1].longitude,
        );
      }

      setState(() {
        _route = pts;
        _totalDistanceKm = dist / 1000.0;
      });
    } catch (_) {
      if (mounted) toast(context, 'Could not load route for ${fmtDate(_selectedDate)} (offline?).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _people.isNotEmpty
        ? LatLng(toNum(_people.first['lat']), toNum(_people.first['lng']))
        : const LatLng(18.6298, 73.7997); // Pimpri-Chinchwad / Pune default

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh positions',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Control Bar: Date picker & Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Date picker
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.brandRed,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (d != null) {
                        setState(() => _selectedDate = d);
                        _refresh();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 15, color: AppColors.brandRed),
                          const SizedBox(width: 8),
                          Text(
                            sameDay(_selectedDate, DateTime.now())
                                ? 'Today (${fmtDate(_selectedDate)})'
                                : fmtDate(_selectedDate),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Staff Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selected,
                      hint: const Text('All Staff', style: TextStyle(fontSize: 12)),
                      isDense: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Staff', style: TextStyle(fontSize: 12))),
                        for (final p in _allStaff)
                          DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(
                              (p['full_name'] ?? 'Staff').toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _selected = v);
                        if (v != null) {
                          final match = _people.where((x) => x['user_id']?.toString() == v).firstOrNull;
                          if (match != null) {
                            _showRoute(match);
                          } else {
                            // Fetch route directly for that staff
                            _showRoute({'user_id': v, 'lat': 0, 'lng': 0});
                          }
                        } else {
                          setState(() => _route = []);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_note != null)
            Container(
              width: double.infinity,
              color: AppColors.brandYellowLight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.brandYellowDark),
                  const SizedBox(width: 6),
                  Text(_note!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),

          // Map
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.lediha.crm',
                    ),
                    if (_route.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route,
                            strokeWidth: 4.5,
                            color: AppColors.brandRed,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final p in _people)
                          if (_selected == null || p['user_id']?.toString() == _selected)
                            Marker(
                              point: LatLng(toNum(p['lat']), toNum(p['lng'])),
                              width: 100,
                              height: 60,
                              child: GestureDetector(
                                onTap: () => _showRoute(p),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                        border: Border.all(
                                          color: p['user_id']?.toString() == _selected
                                              ? AppColors.brandRed
                                              : AppColors.brandTeal,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        str(p['full_name']) ?? 'Staff',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.location_on,
                                      size: 32,
                                      color: p['user_id']?.toString() == _selected
                                          ? AppColors.brandRed
                                          : AppColors.brandTeal,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [TextSourceAttribution('\u00A9 OpenStreetMap contributors')],
                    ),
                  ],
                ),

                // Distance badge if route loaded
                if (_route.isNotEmpty)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.route, size: 16, color: AppColors.brandRed),
                          const SizedBox(width: 6),
                          Text(
                            '${_totalDistanceKm.toStringAsFixed(1)} km traveled \u00B7 ${_route.length} GPS points',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Re-center FAB
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandRed,
                    onPressed: () {
                      if (_people.isNotEmpty) {
                        _map.move(
                          LatLng(toNum(_people.first['lat']), toNum(_people.first['lng'])),
                          13,
                        );
                      }
                    },
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ),
              ],
            ),
          ),

          // Bottom List of Technicians
          Expanded(
            flex: 2,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
                : _people.isEmpty
                    ? const EmptyState(
                        'No location recorded yet.\nPositions update automatically when technicians check in.',
                        icon: Icons.location_off,
                      )
                    : ListView.builder(
                        itemCount: _people.length,
                        itemBuilder: (_, i) {
                          final p = _people[i];
                          final isSel = p['user_id']?.toString() == _selected;
                          final phone = str(p['phone']);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSel ? AppColors.brandRed : AppColors.divider,
                                width: isSel ? 1.8 : 0.8,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSel
                                    ? AppColors.brandRed.withAlpha(25)
                                    : AppColors.brandTeal.withAlpha(25),
                                child: Icon(
                                  Icons.handyman,
                                  color: isSel ? AppColors.brandRed : AppColors.brandTeal,
                                  size: 18,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      str(p['full_name']) ?? 'Technician',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                  if (isSel)
                                    const Pill('Viewing Route', color: AppColors.brandRed, icon: Icons.map),
                                ],
                              ),
                              subtitle: Text(
                                'Last seen: ${fmtDateTime(p['recorded_at'])}\n'
                                'Coords: ${toNum(p['lat']).toStringAsFixed(4)}, ${toNum(p['lng']).toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (phone != null && phone.isNotEmpty) ...[
                                    IconButton(
                                      icon: const Icon(Icons.call, color: AppColors.brandTeal, size: 20),
                                      tooltip: 'Call Technician',
                                      onPressed: () => callNumber(phone),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                                      tooltip: 'WhatsApp',
                                      onPressed: () => whatsappNumber(phone),
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.timeline, color: AppColors.brandRed, size: 22),
                                    tooltip: 'Show Route Path',
                                    onPressed: () => _showRoute(p),
                                  ),
                                ],
                              ),
                              onTap: () => _showRoute(p),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
