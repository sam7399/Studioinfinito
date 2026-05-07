import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';

class ChatSearchPage extends ConsumerStatefulWidget {
  const ChatSearchPage({super.key});

  @override
  ConsumerState<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends ConsumerState<ChatSearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chat'),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search messages...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.trim().length < 2
          ? Center(
              child: Text(
                'Type at least 2 characters to search',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : ref.watch(chatSearchProvider(_query)).when(
                data: (results) {
                  if (results.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No matches',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = results[i];
                      final body = (r['body'] as String?) ?? '';
                      final senderName =
                          (r['sender'] as Map?)?['name'] as String? ?? 'User';
                      final room = r['room'] as Map?;
                      final roomId = r['room_id'] as int? ?? 0;
                      final messageId = r['id'] as int? ?? 0;
                      final created =
                          DateTime.tryParse(r['created_at']?.toString() ?? '');
                      final roomLabel = _roomLabel(room);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE65C00).withOpacity(0.15),
                          child: Icon(
                            (room?['type'] as String?) == 'task'
                                ? Icons.task_alt_outlined
                                : (room?['type'] as String?) == 'group'
                                    ? Icons.group_outlined
                                    : Icons.person_outline,
                            color: const Color(0xFFE65C00),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          roomLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$senderName: $body',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (created != null)
                              Text(
                                DateFormat('dd MMM · HH:mm').format(created),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                        onTap: () {
                          if (roomId > 0) {
                            context.go('/chat/$roomId?msg=$messageId');
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Search error: $e',
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
    );
  }

  String _roomLabel(Map? room) {
    if (room == null) return 'Chat';
    final type = room['type'] as String?;
    if (type == 'group') return room['name']?.toString() ?? 'Group';
    if (type == 'task') return room['name']?.toString() ?? 'Task discussion';
    // direct: pick the first member that isn't me
    return room['name']?.toString() ?? 'Direct chat';
  }
}
