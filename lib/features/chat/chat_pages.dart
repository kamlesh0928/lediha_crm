import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../../data/app_auth.dart';
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
    final me = AppAuth.instance.uid;
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

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            // Team Broadcast Chat
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.brandRed.withAlpha(25),
                  child: const Icon(Icons.groups, color: AppColors.brandRed),
                ),
                title: const Text('LEDiHA Team Chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                subtitle: Text(
                  team == null ? 'Broadcast message to entire service team' : str(team['body']) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatPage(peerId: null, title: 'LEDiHA Team Chat')),
                ),
              ),
            ),

            const SectionTitle('Direct Technician Messages'),

            for (final r in rows)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.brandTeal.withAlpha(20),
                    child: Text(
                      _initial(str((r['p'] as Rec)['full_name'])),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.brandTealDark),
                    ),
                  ),
                  title: Text(
                    str((r['p'] as Rec)['full_name']) ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    (r['last'] as Rec?) == null ? 'Start a conversation' : str((r['last'] as Rec)['body']) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: (r['unread'] as int) > 0
                      ? CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.brandRed,
                          child: Text(
                            '${r['unread']}',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        )
                      : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        peerId: (r['p'] as Rec)['id'].toString(),
                        title: str((r['p'] as Rec)['full_name']) ?? 'Chat',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
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
    final me = AppAuth.instance.uid;
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
      'sender_id': AppAuth.instance.uid,
      'recipient_id': widget.peerId,
      'body': text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = AppAuth.instance.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Live<Map<String, dynamic>>(
              load: _load,
              builder: (context, data) {
                final msgs = data['msgs'] as List<Rec>;
                final names = data['names'] as Map<String, String>;
                if (msgs.isEmpty) {
                  return const EmptyState('No messages yet. Say hello to your service team!', icon: Icons.chat);
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m['sender_id'] == me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.brandRed : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(mine ? 16 : 2),
                            bottomRight: Radius.circular(mine ? 2 : 16),
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!mine && widget.peerId == null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  names[m['sender_id']] ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandTeal,
                                  ),
                                ),
                              ),
                            Text(
                              str(m['body']) ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: mine ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fmtTime(m['created_at']),
                              style: TextStyle(
                                fontSize: 10,
                                color: mine ? Colors.white70 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.brandRed),
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
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
