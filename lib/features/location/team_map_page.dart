import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

/// Admin: where is everyone? Needs internet; shows the last known result when offline.
class TeamMapPage extends StatefulWidget {
  const TeamMapPage({super.key});

  @override
  State<TeamMapPage> createState() => _TeamMapPageState();
}

class _TeamMapPageState extends State<TeamMapPage> {
  final _map = MapController();
  List<Rec> _people = [];
  List<LatLng> _route = [];
  String? _selected;
  bool _loading = true;
  String? _note;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
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
      _note = 'Offline - showing the last known positions.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showRoute(Rec p) async {
    setState(() {
      _selected = p['user_id']?.toString();
      _route = [];
    });
    _map.move(LatLng(toNum(p['lat']), toNum(p['lng'])), 15);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final rows = await Supabase.instance.client
          .from('location_pings')
          .select('lat,lng,recorded_at')
          .eq('user_id', p['user_id'])
          .gte('recorded_at', start)
          .order('recorded_at', ascending: true)
          .limit(1000);
      setState(() => _route = [for (final r in rows) LatLng(toNum(r['lat']), toNum(r['lng']))]);
    } catch (_) {
      if (mounted) toast(context, 'Could not load today\'s route (offline?).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _people.isNotEmpty
        ? LatLng(toNum(_people.first['lat']), toNum(_people.first['lng']))
        : const LatLng(18.6298, 73.7997); // Pimpri-Chinchwad
    return Scaffold(
      appBar: AppBar(title: const Text('Team location'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
      ]),
      body: Column(children: [
        if (_note != null)
          Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8),
              child: Text(_note!, style: const TextStyle(fontSize: 12))),
        Expanded(
          flex: 3,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lediha.crm',
              ),
              if (_route.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: _route, strokeWidth: 4, color: Colors.teal),
                ]),
              MarkerLayer(markers: [
                for (final p in _people)
                  Marker(
                    point: LatLng(toNum(p['lat']), toNum(p['lng'])),
                    width: 90,
                    height: 54,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        color: Colors.white70,
                        child: Text(str(p['full_name']) ?? '',
                            style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.location_on,
                          color: p['user_id']?.toString() == _selected ? Colors.red : Colors.teal),
                    ]),
                  ),
              ]),
              RichAttributionWidget(
                  attributions: [TextSourceAttribution('\u00A9 OpenStreetMap contributors')]),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _people.isEmpty
                  ? const EmptyState('No location recorded yet.\nLocations appear after employees check in.')
                  : ListView(children: [
                      for (final p in _people)
                        ListTile(
                          leading: const Icon(Icons.person_pin_circle),
                          title: Text(str(p['full_name']) ?? ''),
                          subtitle: Text('Last seen ${fmtDateTime(p['recorded_at'])}'),
                          selected: p['user_id']?.toString() == _selected,
                          onTap: () => _showRoute(p),
                        ),
                    ]),
        ),
      ]),
    );
  }
}
