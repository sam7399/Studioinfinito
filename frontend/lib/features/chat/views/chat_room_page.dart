import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../services/call_service.dart';
import '../services/voice_recorder.dart';
import 'voice_message_player.dart';

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

  final VoiceRecorder _recorder = VoiceRecorder();
  bool _recording = false;
  Timer? _recordTicker;
  Duration _recordElapsed = Duration.zero;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTicker?.cancel();
    _recorder.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.start();
      _recordElapsed = Duration.zero;
      setState(() => _recording = true);
      _recordTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!_recording) return;
        setState(() => _recordElapsed = _recorder.elapsed);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone access denied: $e')),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTicker?.cancel();
    setState(() => _recording = false);
    final bytes = await _recorder.stop();
    if (bytes == null || bytes.isEmpty) return;
    await ref
        .read(chatRoomProvider(widget.roomId).notifier)
        .sendWithAttachment(
          bytes: bytes,
          filename: 'voice.webm',
        );
    _scrollToBottom();
  }

  void _cancelRecording() {
    _recordTicker?.cancel();
    setState(() => _recording = false);
    _recorder.cancel();
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

  Future<void> _showForwardDialog(int messageId) async {
    final rooms = ref.read(chatRoomsProvider).rooms;
    final currentUserId = ref.read(authProvider).user?.id ?? 0;
    String search = '';
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final filtered = rooms
            .where((r) =>
                r.id != widget.roomId &&
                r.displayName(currentUserId)
                    .toLowerCase()
                    .contains(search.toLowerCase()))
            .toList();
        return AlertDialog(
          title: const Text('Forward to...'),
          content: SizedBox(
            width: 380,
            height: 420,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => setDlg(() => search = v),
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
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
                      final r = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFFE65C00).withOpacity(0.15),
                          child: Icon(
                            r.type == 'task'
                                ? Icons.task_alt_outlined
                                : r.type == 'group'
                                    ? Icons.group_outlined
                                    : Icons.person_outline,
                            color: const Color(0xFFE65C00),
                          ),
                        ),
                        title: Text(r.displayName(currentUserId)),
                        onTap: () => Navigator.pop(ctx, r.id),
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
    if (target != null) {
      await ref
          .read(chatRoomProvider(widget.roomId).notifier)
          .forward(messageId, target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forwarded ✓')),
        );
      }
    }
  }

  Widget _buildComposer(ChatRoomState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file, size: 20),
          color: Colors.grey.shade600,
          onPressed: state.sending ? null : _attachFile,
          tooltip: 'Attach file',
        ),
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
        if (_ctrl.text.trim().isEmpty)
          IconButton(
            icon: const Icon(Icons.mic, size: 20),
            color: const Color(0xFFE65C00),
            tooltip: 'Voice message',
            onPressed: state.sending ? null : _startRecording,
          )
        else
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
    );
  }

  Widget _buildRecordingBar() {
    final m = _recordElapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _recordElapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Cancel',
          onPressed: _cancelRecording,
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: 10),
                Text('Recording  $m:$s',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          icon: const Icon(Icons.send_rounded, size: 18),
          onPressed: _stopRecordingAndSend,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFE65C00),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _attachFile() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    if (file.bytes == null) return;
    final caption = _ctrl.text.trim();
    _ctrl.clear();
    await ref.read(chatRoomProvider(widget.roomId).notifier).sendWithAttachment(
          bytes: file.bytes!,
          filename: file.name,
          caption: caption,
        );
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

    bool peerOnline = false;
    if (room?.type == 'direct') {
      final other = room!.members
          .where((m) => m.userId != currentUserId)
          .map((m) => m.userId)
          .firstOrNull;
      if (other != null) {
        peerOnline = ref.watch(chatPresenceProvider).contains(other);
      }
    }

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
            Stack(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (room?.type == 'task'
                          ? const Color(0xFF7C3AED)
                          : (room?.type == 'group'
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFE65C00)))
                      .withOpacity(0.15),
                  child: Icon(
                    room?.type == 'task'
                        ? Icons.task_alt_outlined
                        : (room?.type == 'group'
                            ? Icons.group_outlined
                            : Icons.person_outline),
                    size: 18,
                    color: room?.type == 'task'
                        ? const Color(0xFF7C3AED)
                        : (room?.type == 'group'
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFFE65C00)),
                  ),
                ),
                if (peerOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
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
                  else if (room?.type == 'direct')
                    Text(peerOnline ? 'online' : 'offline',
                        style: TextStyle(
                            fontSize: 11,
                            color: peerOnline
                                ? Colors.green.shade600
                                : Colors.grey.shade600))
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
          if (room?.type == 'direct') ...[
            IconButton(
              icon: const Icon(Icons.call, size: 18),
              tooltip: 'Voice call',
              onPressed: () {
                final other = room!.members
                    .where((m) => m.userId != currentUserId)
                    .toList()
                    .firstOrNull;
                if (other == null) return;
                CallService.instance.startCall(
                  peerUserId: other.userId,
                  peerName: other.user?.name ?? 'User',
                  roomId: room.id,
                  media: 'audio',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.videocam, size: 18),
              tooltip: 'Video call',
              onPressed: () {
                final other = room!.members
                    .where((m) => m.userId != currentUserId)
                    .toList()
                    .firstOrNull;
                if (other == null) return;
                CallService.instance.startCall(
                  peerUserId: other.userId,
                  peerName: other.user?.name ?? 'User',
                  roomId: room.id,
                  media: 'video',
                );
              },
            ),
          ],
          if (room?.type == 'task' && room?.taskId != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open task',
              onPressed: () => context.go('/tasks/${room!.taskId}'),
            ),
          if (room?.type != 'direct')
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              tooltip: 'Members & info',
              onPressed: () => context.go('/chat/${widget.roomId}/info'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Pinned banner
          _PinnedBanner(roomId: widget.roomId, scrollTo: (id) {
            final idx = state.messages.indexWhere((m) => m.id == id);
            if (idx >= 0 && _scroll.hasClients) {
              _scroll.animateTo(
                (idx * 70.0).clamp(0.0, _scroll.position.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          }),
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
                            allMessages: state.messages,
                            roomId: widget.roomId,
                            onDelete: isMine
                                ? () => ref
                                    .read(chatRoomProvider(widget.roomId)
                                        .notifier)
                                    .deleteMessage(msg.id)
                                : null,
                            onReply: () => ref
                                .read(chatRoomProvider(widget.roomId).notifier)
                                .setReplyTarget(msg),
                            onForward: () => _showForwardDialog(msg.id),
                            onTogglePin: () => ref
                                .read(chatRoomProvider(widget.roomId).notifier)
                                .togglePin(msg.id, !msg.isPinned),
                            onReact: (emoji) => ref
                                .read(chatRoomProvider(widget.roomId).notifier)
                                .toggleReaction(msg.id, emoji),
                            onJumpTo: (targetId) {
                              final idx = state.messages
                                  .indexWhere((m) => m.id == targetId);
                              if (idx >= 0 && _scroll.hasClients) {
                                _scroll.animateTo(
                                  (idx * 70.0).clamp(
                                      0.0, _scroll.position.maxScrollExtent),
                                  duration:
                                      const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
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

          // Reply banner
          if (state.replyTarget != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFE65C00), width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 14, color: Color(0xFFE65C00)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Replying to ${state.replyTarget!.sender?.name ?? "message"}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE65C00)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.replyTarget!.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => ref
                          .read(chatRoomProvider(widget.roomId).notifier)
                          .setReplyTarget(null),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),
            ),

          // Composer
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            color: Colors.white,
            child: _recording ? _buildRecordingBar() : _buildComposer(state),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderName;
  final List<ChatMessage> allMessages;
  final int roomId;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onTogglePin;
  final void Function(String emoji)? onReact;
  final void Function(int targetId)? onJumpTo;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSenderName,
    required this.allMessages,
    required this.roomId,
    this.onDelete,
    this.onReply,
    this.onForward,
    this.onTogglePin,
    this.onReact,
    this.onJumpTo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isMine ? const Color(0xFFE65C00) : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final senderName = message.sender?.name ?? '';
    final timeText = DateFormat('HH:mm').format(message.createdAt);

    // Compute read state for own messages: read by anyone other than me?
    bool readByOthers = false;
    if (isMine) {
      final reads =
          ref.watch(chatRoomReadsProvider(message.roomId));
      final me = ref.watch(authProvider).user?.id ?? -1;
      for (final entry in reads.entries) {
        if (entry.key == me) continue;
        if (entry.value != null && !entry.value!.isBefore(message.createdAt)) {
          readByOthers = true;
          break;
        }
      }
    }

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
                onLongPress: () async {
                  final action = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Quick emoji row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: ['👍', '❤️', '😂', '😮', '😢', '🎉']
                                  .map((e) => InkWell(
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          onReact?.call(e);
                                        },
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.all(8),
                                          child: Text(e,
                                              style:
                                                  const TextStyle(fontSize: 22)),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          const Divider(height: 1),
                          if (onReply != null)
                            ListTile(
                              leading: const Icon(Icons.reply),
                              title: const Text('Reply'),
                              onTap: () => Navigator.pop(ctx, 'reply'),
                            ),
                          if (onForward != null)
                            ListTile(
                              leading: const Icon(Icons.forward_outlined),
                              title: const Text('Forward'),
                              onTap: () => Navigator.pop(ctx, 'forward'),
                            ),
                          if (onTogglePin != null)
                            ListTile(
                              leading: Icon(message.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined),
                              title: Text(message.isPinned ? 'Unpin' : 'Pin'),
                              onTap: () => Navigator.pop(ctx, 'pin'),
                            ),
                          if (onDelete != null)
                            ListTile(
                              leading: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              title: const Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                              onTap: () => Navigator.pop(ctx, 'delete'),
                            ),
                          ListTile(
                            leading: const Icon(Icons.close),
                            title: const Text('Cancel'),
                            onTap: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (action == 'reply') onReply?.call();
                  if (action == 'forward') onForward?.call();
                  if (action == 'pin') onTogglePin?.call();
                  if (action == 'delete') {
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
                    if (confirm == true) onDelete?.call();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Forwarded label
                      if (message.isForwarded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forward,
                                  size: 11,
                                  color: isMine
                                      ? Colors.white70
                                      : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('Forwarded',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: isMine
                                          ? Colors.white70
                                          : Colors.grey.shade500)),
                            ],
                          ),
                        ),

                      // Quoted reply preview
                      if (message.replyTo != null)
                        InkWell(
                          onTap: () => onJumpTo?.call(message.replyTo!.id),
                          child: Container(
                            margin: const EdgeInsets.only(
                                top: 2, bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isMine
                                      ? Colors.white
                                      : const Color(0xFFE65C00))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border(
                                left: BorderSide(
                                  color: isMine
                                      ? Colors.white
                                      : const Color(0xFFE65C00),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              message.replyTo!.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMine
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),

                      // Attachments
                      ...message.attachments.map((a) => Padding(
                            padding: const EdgeInsets.only(
                                top: 2, bottom: 4),
                            child: _AttachmentTile(
                                attachment: a, isMine: isMine),
                          )),

                      if (message.body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 2),
                          child: Text(
                            message.body,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                height: 1.3),
                          ),
                        ),

                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isPinned) ...[
                            Icon(Icons.push_pin,
                                size: 10,
                                color: isMine
                                    ? Colors.white70
                                    : Colors.grey.shade500),
                            const SizedBox(width: 4),
                          ],
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
                          if (isMine) ...[
                            const SizedBox(width: 4),
                            Icon(
                              readByOthers
                                  ? Icons.done_all
                                  : Icons.done,
                              size: 12,
                              color: readByOthers
                                  ? const Color(0xFF60A5FA)
                                  : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Reaction pills (under bubble)
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                      top: 2,
                      left: isMine ? 0 : 8,
                      right: isMine ? 8 : 0),
                  child: _ReactionPills(
                    reactions: message.reactionsByEmoji(),
                    currentUserId: ref.watch(authProvider).user?.id ?? 0,
                    onTap: (emoji) => onReact?.call(emoji),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionPills extends StatelessWidget {
  final Map<String, List<int>> reactions;
  final int currentUserId;
  final void Function(String emoji)? onTap;

  const _ReactionPills({
    required this.reactions,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: reactions.entries.map((e) {
        final mine = e.value.contains(currentUserId);
        return InkWell(
          onTap: () => onTap?.call(e.key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: mine
                  ? const Color(0xFFE65C00).withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mine
                    ? const Color(0xFFE65C00).withOpacity(0.4)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text(
                  '${e.value.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: mine
                        ? const Color(0xFFE65C00)
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}

class _PinnedBanner extends ConsumerWidget {
  final int roomId;
  final void Function(int messageId) scrollTo;
  const _PinnedBanner({required this.roomId, required this.scrollTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(chatPinnedProvider(roomId));
    if (pinned.isEmpty) return const SizedBox.shrink();
    final first = pinned.first;
    final hasMore = pinned.length > 1;
    return Material(
      color: const Color(0xFFFFF7ED),
      child: InkWell(
        onTap: () => scrollTo(first.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 14, color: Color(0xFFE65C00)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasMore
                          ? 'Pinned · ${pinned.length} messages'
                          : 'Pinned message',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65C00)),
                    ),
                    Text(
                      first.body.isNotEmpty ? first.body : '[attachment]',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends ConsumerWidget {
  final ChatAttachment attachment;
  final bool isMine;
  const _AttachmentTile({required this.attachment, required this.isMine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(chatServiceProvider);

    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          svc.attachmentUrl(attachment.id),
          width: 220,
          fit: BoxFit.cover,
          headers: svc.authHeaders(),
          errorBuilder: (_, __, ___) => Container(
            width: 220,
            height: 120,
            color: Colors.black12,
            child: const Icon(Icons.broken_image_outlined),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 220,
              height: 120,
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }

    if (attachment.isAudio) {
      return VoiceMessagePlayer(
        isMine: isMine,
        title: attachment.originalName == 'voice.webm' ? 'Voice message' : attachment.originalName,
        fetchBytes: () => svc.fetchAttachmentBytes(attachment.id),
      );
    }

    final size = attachment.fileSize == null
        ? ''
        : ' · ${(attachment.fileSize! / 1024).toStringAsFixed(1)} KB';

    return InkWell(
      onTap: () => svc.openAttachment(attachment.id, attachment.originalName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: (isMine ? Colors.white : const Color(0xFFE65C00))
              .withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 18,
                color: isMine ? Colors.white : const Color(0xFFE65C00)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Tap to open$size',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isMine ? Colors.white70 : Colors.grey.shade600,
                    ),
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
