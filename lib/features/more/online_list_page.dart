import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/queries.dart';

/// Admin-only logs that live on the server (audit trail, Meta events). Needs internet.
class OnlineListPage extends StatefulWidget {
  const OnlineListPage({super.key, required this.title, required this.table, required this.orderBy, required this.tile});
  final String title, table, orderBy;
  final Widget Function(Rec row) tile;

  @override
  State<OnlineListPage> createState() => _OnlineListPageState();
}

class _OnlineListPageState extends State<OnlineListPage> {
  late Future<List<Rec>> _future = _fetch();

  Future<List<Rec>> _fetch() async {
    final rows = await Supabase.instance.client
        .from(widget.table)
        .select()
        .order(widget.orderBy, ascending: false)
        .limit(100);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _future = _fetch()),
        child: FutureBuilder<List<Rec>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: const [
                EmptyState('Could not load. This list needs an internet connection.\nPull down to retry.')
              ]);
            }
            final rows = snap.data!;
            if (rows.isEmpty) return ListView(children: const [EmptyState('Nothing here yet.')]);
            return ListView(children: [for (final r in rows) widget.tile(r)]);
          },
        ),
      ),
    );
  }
}

Widget auditTile(Rec r) => ListTile(
      dense: true,
      title: Text('${label(str(r['action']))} \u00B7 ${str(r['table_name']) ?? ''}'),
      subtitle: Text('${fmtDateTime(r['created_at'])} \u00B7 record ${str(r['record_id']) ?? ''}'),
    );

Widget metaEventTile(Rec r) => ListTile(
      dense: true,
      leading: Icon(
          r['status'] == 'failed' ? Icons.error_outline : Icons.check_circle_outline,
          color: r['status'] == 'failed' ? Colors.red : Colors.green),
      title: Text('${label(str(r['source']))} \u00B7 ${label(str(r['status']))}'),
      subtitle: Text('${fmtDateTime(r['received_at'])}${r['error'] != null ? '\n${r['error']}' : ''}'),
      isThreeLine: r['error'] != null,
    );
