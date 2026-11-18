import 'package:flutter/material.dart';
import '../../core/permissions.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
import '../../data/csv_export.dart';
import '../../data/push_service.dart';
import '../../data/queries.dart';
import '../../data/store.dart';
import '../../data/sync_service.dart';
import '../chat/chat_pages.dart';
import '../followups/followups_page.dart';
import '../leads/leads_page.dart';
import '../location/location_service.dart';
import '../location/my_location_page.dart';
import '../location/team_map_page.dart';
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
  static const _titles = ['LEDiHA TV Repair', 'Service Leads', 'Follow-ups', 'Team Chat', 'More Options'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncService.instance.listen();
    LocationService.resumeIfCheckedIn();
    CsvExport.autoDaily();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupPrompts());
  }

  /// First sign-in: show what the app needs, then (once) offer notifications.
  Future<void> _startupPrompts() async {
    if (!mounted) return;
    await Permissions.showIntroOnce(context);
    if (!mounted) return;
    await PushService.instance.start(context);
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
    final isAdmin = AppAuth.instance.isAdmin;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: _i == 0
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 24,
                      errorBuilder: (_, _, _) => const Icon(Icons.tv, color: AppColors.brandRed, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LEDiHA CRM',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        'Your tv Repair Partner',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.brandYellowLight),
                      ),
                    ],
                  ),
                ],
              )
            : Text(_titles[_i]),
        actions: [
          // Live GPS Indicator (for Employees: opens My Location; for Admin: opens Team Map)
          ValueListenableBuilder<bool>(
            valueListenable: LocationService.isTracking,
            builder: (context, tracking, _) {
              if (isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: 'Team Live GPS Map',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamMapPage()),
                  ),
                );
              }

              return Tooltip(
                message: tracking ? 'Live Location Tracking Active' : 'Location Tracking Paused',
                child: IconButton(
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        tracking ? Icons.gps_fixed : Icons.gps_off,
                        color: tracking ? AppColors.brandYellow : Colors.white70,
                      ),
                      if (tracking)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.lightGreenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyLocationPage()),
                  ),
                ),
              );
            },
          ),

          // Cloud Sync button
          ValueListenableBuilder<int>(
            valueListenable: Store.pendingCount,
            builder: (_, n, _) => IconButton(
              tooltip: n > 0 ? '$n change(s) waiting to upload' : 'All changes uploaded',
              icon: Badge(
                label: Text('$n'),
                isLabelVisible: n > 0,
                backgroundColor: AppColors.brandYellow,
                textColor: Colors.black,
                child: Icon(n > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined),
              ),
              onPressed: () {
                SyncService.instance.syncAll();
                toast(context, n > 0 ? 'Uploading $n change(s)...' : 'Everything is up to date.');
              },
            ),
          ),

          // Notifications bell
          Live<List<Rec>>(
            load: Q.notifications,
            builder: (context, list) {
              final unread = list.where((n) => n['read_at'] == null).length;
              return IconButton(
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  backgroundColor: AppColors.brandYellow,
                  textColor: Colors.black,
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _i,
        children: [
          DashboardPage(onGo: (t) => setState(() => _i = t)),
          const LeadsPage(),
          const FollowupsPage(),
          const ChatListPage(),
          const MorePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.tv_outlined),
            selectedIcon: Icon(Icons.tv),
            label: 'TV Leads',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_repeat_outlined),
            selectedIcon: Icon(Icons.event_repeat),
            label: 'Follow-ups',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
