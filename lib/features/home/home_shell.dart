import 'package:flutter/material.dart';
import '../../data/csv_export.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/sync_service.dart';
import '../../core/widgets.dart';
import '../chat/chat_pages.dart';
import '../followups/followups_page.dart';
import '../leads/leads_page.dart';
import '../location/location_service.dart';
import '../more/more_page.dart';
import '../more/notifications_page.dart';
import 'dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _i = 0;
  static const _titles = ['Home', 'Leads', 'Follow-ups', 'Chat', 'More'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncService.instance.listen();
    LocationService.resumeIfCheckedIn();
    CsvExport.autoDaily();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) SyncService.instance.syncAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_i]),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: Store.pendingCount,
            builder: (_, n, _) => IconButton(
              tooltip: n > 0 ? '$n change(s) waiting to upload' : 'All changes uploaded',
              icon: Badge(
                label: Text('$n'),
                isLabelVisible: n > 0,
                child: Icon(n > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined),
              ),
              onPressed: () {
                SyncService.instance.syncAll();
                toast(context, n > 0 ? 'Uploading $n change(s)...' : 'Everything is up to date.');
              },
            ),
          ),
          Live<List<Rec>>(
            load: Q.notifications,
            builder: (context, list) {
              final unread = list.where((n) => n['read_at'] == null).length;
              return IconButton(
                icon: Badge(
                    label: Text('$unread'),
                    isLabelVisible: unread > 0,
                    child: const Icon(Icons.notifications_none)),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _i, children: [
        DashboardPage(onGo: (t) => setState(() => _i = t)),
        const LeadsPage(),
        const FollowupsPage(),
        const ChatListPage(),
        const MorePage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Leads'),
          NavigationDestination(icon: Icon(Icons.event_repeat), label: 'Follow-ups'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
