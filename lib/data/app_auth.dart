import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store.dart';
import 'sync_service.dart';

/// Who is logged in and what role they have. The role is cached on the phone,
/// so the app opens correctly even without internet.
class AppAuth extends ChangeNotifier {
  AppAuth._();
  static final AppAuth instance = AppAuth._();

  SupabaseClient get _sb => Supabase.instance.client;
  String? uid;
  String? role;
  String? name;

  bool get loggedIn => uid != null;
  bool get isAdmin => role == 'admin';

  Future<void> init() async {
    final session = _sb.auth.currentSession;
    final loggedOutFlag = await Store.getMeta('logged_out') == '1';
    if (session != null && !loggedOutFlag) {
      uid = session.user.id;
      role = await Store.getMeta('role');
      name = await Store.getMeta('name');
      if (role == null) {
        try {
          await _loadProfile();
        } catch (_) {
          uid = null;
        }
      }
    } else if (session != null && loggedOutFlag) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
    }
    _sb.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && uid != null) {
        uid = null;
        role = null;
        notifyListeners();
      }
    });
  }

  Future<void> login(String email, String password) async {
    final res = await _sb.auth.signInWithPassword(email: email.trim(), password: password);
    final user = res.user;
    if (user == null) throw 'Login failed. Please try again.';
    final owner = await Store.getMeta('owner');
    if (owner != null && owner != user.id) await Store.wipe();
    await Store.setMeta('owner', user.id);
    await Store.setMeta('logged_out', '0');
    try {
      await _loadProfile();
    } catch (e) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
      uid = null;
      rethrow;
    }
    notifyListeners();
    SyncService.instance.syncAll();
  }

  Future<void> _loadProfile() async {
    final id = _sb.auth.currentUser!.id;
    final p = await _sb.from('profiles').select().eq('id', id).single();
    if (p['is_active'] != true) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
      throw 'Your account is inactive. Please contact the admin.';
    }
    uid = p['id'] as String;
    role = p['role'] as String;
    name = (p['full_name'] ?? '') as String;
    await Store.setMeta('role', role!);
    await Store.setMeta('name', name!);
    await Store.merge('profiles', [Map<String, dynamic>.from(p)]);
  }

  /// Called after each sync: if the admin deactivated this account, sign out.
  Future<void> checkStillActive() async {
    if (uid == null) return;
    final me = await Store.byId('profiles', uid!);
    if (me != null && me['is_active'] == false) await logout();
  }

  Future<void> logout() async {
    await Store.setMeta('logged_out', '1');
    try {
      await _sb.auth.signOut();
    } catch (_) {}
    uid = null;
    role = null;
    notifyListeners();
  }
}
