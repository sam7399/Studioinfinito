import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../org/providers/org_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatRoomsProvider);
    final currentUserId = ref.watch(authProvider).user?.id ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Direct chats and task discussions',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(chatRoomsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
                FilledButton.icon(
                  onPressed: () => _showNewChatDialog(context, ref),
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('New chat'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65C00)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: state.loading && state.rooms.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.rooms.isEmpty
                    ? _emptyState(context, ref)
                    : RefreshIndicator(
                        onRefresh: () => ref.read(chatRoomsProvider.notifier).refresh(),
                        child: ListView.separated(
                          itemCount: state.rooms.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _RoomTile(
                            room: state.rooms[i],
                            currentUserId: currentUserId,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No conversations yet',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a chat with a teammate or open a task discussion.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showNewChatDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Start a chat'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65C00)),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewChatDialog(BuildContext context, WidgetRef ref) async {
    final users = ref.read(allUsersProvider).maybeWhen(
          data: (d) => d,
          orElse: () => <OrgItem>[],
        );
    final currentUserId = ref.read(authProvider).user?.id ?? 0;
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final filtered = users
            .where((u) =>
                u.id != currentUserId &&
                u.name.toLowerCase().contains(search.toLowerCase()))
            .toList();
        return AlertDialog(
          title: const Text('Start new chat'),
          content: SizedBox(
            width: 380,
            height: 420,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => setDlg(() => search = v),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
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
                          backgroundColor: const Color(0xFFE65C00).withOpacity(0.15),
                          child: Text(
                            u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Color(0xFFE65C00), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(u.name, style: const TextStyle(fontSize: 14)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            final room = await ref
                                .read(chatRoomsProvider.notifier)
                                .openDirect(u.id);
                            if (context.mounted) context.go('/chat/${room.id}');
                          } catch (_) {}
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

class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final int currentUserId;
  const _RoomTile({required this.room, required this.currentUserId});

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return DateFormat('HH:mm').format(t);
    }
    if (t.isAfter(now.subtract(const Duration(days: 7)))) {
      return DateFormat('EEE').format(t);
    }
    return DateFormat('dd MMM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final name = room.displayName(currentUserId);
    final preview = room.lastMessage?.body ?? 'No messages yet';
    final isUnread = room.unreadCount > 0;
    final color = room.type == 'task'
        ? const Color(0xFF7C3AED)
        : const Color(0xFFE65C00);

    return InkWell(
      onTap: () => context.go('/chat/${room.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(
                room.type == 'task' ? Icons.task_alt_outlined : Icons.person_outline,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(room.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnread ? color : Colors.grey.shade500,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnread ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${room.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
