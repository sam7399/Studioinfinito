import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../org/providers/org_provider.dart';
import '../providers/chat_provider.dart';

class ChatRoomInfoPage extends ConsumerWidget {
  final int roomId;
  const ChatRoomInfoPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatMembersProvider(roomId));
    final room = ref
        .watch(chatRoomsProvider)
        .rooms
        .where((r) => r.id == roomId)
        .cast<dynamic>()
        .firstWhere((_) => true, orElse: () => null);
    final currentUserId = ref.watch(authProvider).user?.id ?? 0;
    final canManage =
        room != null && room.type != 'direct' && room.createdByUserId == currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chat/$roomId'),
        ),
        title: Text(room?.displayName(currentUserId) ?? 'Chat info'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberDialog(context, ref, currentUserId),
              backgroundColor: const Color(0xFFE65C00),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add member'),
            )
          : null,
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Text(state.error!, style: const TextStyle(color: Colors.red)))
              : ListView.separated(
                  itemCount: state.members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = state.members[i];
                    final isMe = m.userId == currentUserId;
                    final isCreator =
                        room != null && room.createdByUserId == m.userId;
                    final online = ref.watch(chatPresenceProvider).contains(m.userId);
                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFE65C00).withOpacity(0.15),
                            child: Text(
                              (m.user?.name ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFFE65C00),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (online)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(m.user?.name ?? 'User #${m.userId}'),
                      subtitle: Text([
                        if (isMe) 'You',
                        if (isCreator) 'Admin',
                        m.user?.role ?? '',
                      ].where((s) => s.isNotEmpty).join(' · ')),
                      trailing: canManage && !isMe && !isCreator
                          ? IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: Colors.red.shade400),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Remove ${m.user?.name}?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          child: const Text('Remove')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref
                                      .read(chatMembersProvider(roomId).notifier)
                                      .removeMember(m.userId);
                                }
                              },
                            )
                          : null,
                    );
                  },
                ),
    );
  }

  Future<void> _showAddMemberDialog(
      BuildContext context, WidgetRef ref, int currentUserId) async {
    final users = ref.read(allUsersProvider).maybeWhen(
          data: (d) => d,
          orElse: () => <OrgItem>[],
        );
    final existing =
        ref.read(chatMembersProvider(roomId)).members.map((m) => m.userId).toSet();
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final filtered = users
            .where((u) =>
                u.id != currentUserId &&
                !existing.contains(u.id) &&
                u.name.toLowerCase().contains(search.toLowerCase()))
            .toList();
        return AlertDialog(
          title: const Text('Add member'),
          content: SizedBox(
            width: 380,
            height: 400,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => setDlg(() => search = v),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFFE65C00).withOpacity(0.15),
                          child: Text(
                            u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Color(0xFFE65C00),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(u.name, style: const TextStyle(fontSize: 14)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref
                              .read(chatMembersProvider(roomId).notifier)
                              .addMember(u.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        );
      }),
    );
  }
}
