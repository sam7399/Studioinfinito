import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  final int roomId;
  const ChatRoomPage({super.key, required this.roomId});

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  Timer? _typingTimer;
  bool _emittedTyping = false;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    if (!_emittedTyping) {
      ref.read(chatRoomProvider(widget.roomId).notifier).emitTyping(true);
      _emittedTyping = true;
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      ref.read(chatRoomProvider(widget.roomId).notifier).emitTyping(false);
      _emittedTyping = false;
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    if (_emittedTyping) {
      ref.read(chatRoomProvider(widget.roomId).notifier).emitTyping(false);
      _emittedTyping = false;
    }
    await ref.read(chatRoomProvider(widget.roomId).notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatRoomProvider(widget.roomId));
    final currentUserId = ref.watch(authProvider).user?.id ?? 0;

    // Find the room metadata from the rooms list
    final room = ref
        .watch(chatRoomsProvider)
        .rooms
        .where((r) => r.id == widget.roomId)
        .cast<ChatRoom?>()
        .firstWhere((_) => true, orElse: () => null);

    // Auto-scroll on new messages
    ref.listen(chatRoomProvider(widget.roomId), (prev, next) {
      if (prev?.messages.length != next.messages.length) _scrollToBottom();
    });

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
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: (room?.type == 'task'
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFE65C00))
                  .withOpacity(0.15),
              child: Icon(
                room?.type == 'task' ? Icons.task_alt_outlined : Icons.person_outline,
                size: 18,
                color: room?.type == 'task'
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFE65C00),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room?.displayName(currentUserId) ?? 'Chat',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (state.typingUserIds.isNotEmpty)
                    Text('typing…',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600))
                  else if (room?.type == 'task' && room?.taskId != null)
                    Text('Task #${room!.taskId}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (room?.type == 'task' && room?.taskId != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open task',
              onPressed: () => context.go('/tasks/${room!.taskId}'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.loading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 44, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('Say hi 👋',
                                style:
                                    TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) {
                          final msg = state.messages[i];
                          final isMine = msg.senderUserId == currentUserId;
                          final prev =
                              i > 0 ? state.messages[i - 1] : null;
                          final showSender = !isMine &&
                              (prev == null ||
                                  prev.senderUserId != msg.senderUserId);
                          return _MessageBubble(
                            message: msg,
                            isMine: isMine,
                            showSenderName: showSender,
                            onDelete: isMine
                                ? () => ref
                                    .read(chatRoomProvider(widget.roomId)
                                        .notifier)
                                    .deleteMessage(msg.id)
                                : null,
                          );
                        },
                      ),
          ),
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.error!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.red.shade700)),
                  ),
                ],
              ),
            ),

          // Composer
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: state.sending ? null : _send,
                  icon: state.sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE65C00),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderName;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSenderName,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMine ? const Color(0xFFE65C00) : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final senderName = message.sender?.name ?? '';

    final timeText = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSenderName)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(
                    senderName,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                ),
              GestureDetector(
                onLongPress: onDelete == null
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete message?'),
                            content: const Text(
                                'This will remove the message for everyone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) onDelete!();
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMine ? 14 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 14),
                    ),
                    boxShadow: isMine
                        ? null
                        : [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4)
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.body,
                        style: TextStyle(
                            color: textColor, fontSize: 14, height: 1.3),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.editedAt != null) ...[
                            Text(
                              'edited',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: isMine
                                      ? Colors.white70
                                      : Colors.grey.shade500),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            timeText,
                            style: TextStyle(
                                fontSize: 10,
                                color: isMine
                                    ? Colors.white70
                                    : Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
