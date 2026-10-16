import 'package:flutter/material.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/auth_state.dart';
import '../../data/queries.dart';
import '../../data/store.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  static String _initial(String? n) => (n == null || n.isEmpty) ? '?' : n[0].toUpperCase();

  Future<Map<String, dynamic>> _load() async => {
        'people': await Q.staff(),
        'msgs': await Store.all('messages'),
      };

  @override
  Widget build(BuildContext context) {
    final me = AuthState.instance.uid;
    return Live<Map<String, dynamic>>(
      load: _load,
      builder: (context, data) {
        final msgs = data['msgs'] as List<Rec>;
        final people = (data['people'] as List<Rec>).where((p) => p['id'] != me).toList();
        Rec? lastOf(bool Function(Rec) test) {
          Rec? best;
          for (final m in msgs.where(test)) {
            if (best == null ||
                (m['created_at'] ?? '').toString().compareTo((best['created_at'] ?? '').toString()) > 0) {
              best = m;
            }
          }
          return best;
        }

        final team = lastOf((m) => m['recipient_id'] == null);
        final rows = <Map<String, dynamic>>[
          for (final p in people)
            {
              'p': p,
              'last': lastOf((m) =>
                  (m['sender_id'] == me && m['recipient_id'] == p['id']) ||
                  (m['sender_id'] == p['id'] && m['recipient_id'] == me)),
              'unread': msgs
                  .where((m) =>
                      m['sender_id'] == p['id'] && m['recipient_id'] == me && m['read_at'] == null)
                  .length,
            }
        ]..sort((a, b) {
            final x = ((a['last'] as Rec?)?['created_at'] ?? '').toString();
            final y = ((b['last'] as Rec?)?['created_at'] ?? '').toString();
            return y.compareTo(x);
          });
        return ListView(children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups)),
            title: const Text('Team chat', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(team == null ? 'Message everyone' : str(team['body']) ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatPage(peerId: null, title: 'Team chat'))),
          ),
          const Divider(height: 1),
          for (final r in rows)
            ListTile(
              leading: CircleAvatar(
                  child: Text(_initial(str((r['p'] as Rec)['full_name'])))),
              title: Text(str((r['p'] as Rec)['full_name']) ?? ''),
              subtitle: Text(
                  (r['last'] as Rec?) == null ? 'Start a conversation' : str((r['last'] as Rec)['body']) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: (r['unread'] as int) > 0
                  ? CircleAvatar(radius: 11, child: Text('${r['unread']}', style: const TextStyle(fontSize: 11)))
                  : null,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChatPage(
                          peerId: (r['p'] as Rec)['id'].toString(),
                          title: str((r['p'] as Rec)['full_name']) ?? 'Chat'))),
            ),
        ]);
      },
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.peerId, required this.title});
  final String? peerId; // null = team chat
  final String title;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctl = TextEditingController();

  Future<Map<String, dynamic>> _load() async {
    final me = AuthState.instance.uid;
    final all = await Store.all('messages');
    final list = all.where((m) {
      if (widget.peerId == null) return m['recipient_id'] == null;
      return (m['sender_id'] == me && m['recipient_id'] == widget.peerId) ||
          (m['sender_id'] == widget.peerId && m['recipient_id'] == me);
    }).toList();
    Q.sorted(list, 'created_at');
    // Mark incoming direct messages as read.
    for (final m in list.where((m) => m['recipient_id'] == me && m['read_at'] == null)) {
      Future.microtask(() => Store.put('messages', {...m, 'read_at': nowIso()}));
    }
    return {'msgs': list, 'names': await Q.names()};
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    _ctl.clear();
    await Store.put('messages', {
      'sender_id': AuthState.instance.uid,
      'recipient_id': widget.peerId,
      'body': text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthState.instance.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Expanded(
          child: Live<Map<String, dynamic>>(
            load: _load,
            builder: (context, data) {
              final msgs = data['msgs'] as List<Rec>;
              final names = data['names'] as Map<String, String>;
              if (msgs.isEmpty) return const EmptyState('No messages yet. Say hello!');
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(10),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m['sender_id'] == me;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints:
                          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .75),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!mine && widget.peerId == null)
                          Text(names[m['sender_id']] ?? '',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        Text(str(m['body']) ?? ''),
                        Text(fmtTime(m['created_at']),
                            style: const TextStyle(fontSize: 10, color: Colors.black45)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _ctl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Message'))),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
