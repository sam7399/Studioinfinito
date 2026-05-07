import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';

/// Top-level overlay that listens to CallService and shows incoming/active calls.
/// Mounted once at the top of the app via Stack so it's visible on every page.
class CallOverlay extends StatefulWidget {
  final Widget child;
  const CallOverlay({super.key, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  CallState _state = CallState.idle;
  CallSession? _session;
  StreamSubscription? _stateSub;
  StreamSubscription? _sessionSub;

  @override
  void initState() {
    super.initState();
    final svc = CallService.instance;
    _state = svc.state;
    _session = svc.session;
    _stateSub = svc.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _sessionSub = svc.sessionStream.listen((s) {
      if (mounted) setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_state == CallState.ringing && _session != null)
          _IncomingCallSheet(session: _session!),
        if ((_state == CallState.calling || _state == CallState.connected) &&
            _session != null)
          _ActiveCallSheet(session: _session!, state: _state),
      ],
    );
  }
}

class _IncomingCallSheet extends StatelessWidget {
  final CallSession session;
  const _IncomingCallSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1F2937),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE65C00),
                child: Text(
                  session.peerName.isNotEmpty
                      ? session.peerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Incoming ${session.media} call',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.peerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.call_end, color: Colors.white),
                onPressed: () => CallService.instance.reject(),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.call, color: Colors.white),
                onPressed: () => CallService.instance.accept(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCallSheet extends StatefulWidget {
  final CallSession session;
  final CallState state;
  const _ActiveCallSheet({required this.session, required this.state});

  @override
  State<_ActiveCallSheet> createState() => _ActiveCallSheetState();
}

class _ActiveCallSheetState extends State<_ActiveCallSheet> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  StreamSubscription? _localSub;
  StreamSubscription? _remoteSub;
  bool _muted = false;
  bool _camOff = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localRenderer.srcObject = CallService.instance.localStream;
    _remoteRenderer.srcObject = CallService.instance.remoteStream;
    _localSub = CallService.instance.localStreamUpdates
        .listen((s) => setState(() => _localRenderer.srcObject = s));
    _remoteSub = CallService.instance.remoteStreamUpdates
        .listen((s) => setState(() => _remoteRenderer.srcObject = s));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _localSub?.cancel();
    _remoteSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.session.media == 'video';
    final isCalling = widget.state == CallState.calling;

    return Positioned.fill(
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              // Remote video
              if (isVideo)
                Positioned.fill(
                  child: RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                _AudioCallBackdrop(session: widget.session, isCalling: isCalling),

              // Local video preview
              if (isVideo)
                Positioned(
                  top: 16,
                  right: 16,
                  width: 110,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),

              // Top bar (peer name + status)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.session.peerName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isCalling ? 'Calling…' : 'Connected',
                        style: TextStyle(
                            color: isCalling
                                ? Colors.white70
                                : Colors.green.shade400,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CtrlButton(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      bg: Colors.white24,
                      onTap: () {
                        final m = CallService.instance.toggleMute();
                        setState(() => _muted = m);
                      },
                    ),
                    const SizedBox(width: 14),
                    if (isVideo)
                      _CtrlButton(
                        icon: _camOff ? Icons.videocam_off : Icons.videocam,
                        bg: Colors.white24,
                        onTap: () {
                          final c = CallService.instance.toggleCamera();
                          setState(() => _camOff = c);
                        },
                      ),
                    if (isVideo) const SizedBox(width: 14),
                    _CtrlButton(
                      icon: Icons.call_end,
                      bg: Colors.red,
                      size: 60,
                      onTap: () => CallService.instance.end(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioCallBackdrop extends StatelessWidget {
  final CallSession session;
  final bool isCalling;
  const _AudioCallBackdrop({required this.session, required this.isCalling});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: const Color(0xFFE65C00),
            child: Text(
              session.peerName.isNotEmpty
                  ? session.peerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            session.peerName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            isCalling ? 'Ringing…' : 'On call',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;
  final double size;

  const _CtrlButton({
    required this.icon,
    required this.bg,
    required this.onTap,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}
