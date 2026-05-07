import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../notifications/services/socket_service.dart';

enum CallState { idle, ringing, calling, connected, ended }

class CallSession {
  final String callId;
  final int peerUserId;
  final String peerName;
  final String media; // 'audio' | 'video'
  final bool isCaller;

  CallSession({
    required this.callId,
    required this.peerUserId,
    required this.peerName,
    required this.media,
    required this.isCaller,
  });
}

/// Singleton manager for 1-1 audio/video calls over Socket.IO signaling.
class CallService {
  CallService._() {
    _wireSocket();
  }
  static final CallService instance = CallService._();

  final SocketService _socket = SocketService();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallSession? _session;
  CallState _state = CallState.idle;

  final _stateCtrl = StreamController<CallState>.broadcast();
  final _sessionCtrl = StreamController<CallSession?>.broadcast();
  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();

  Stream<CallState> get stateStream => _stateCtrl.stream;
  Stream<CallSession?> get sessionStream => _sessionCtrl.stream;
  Stream<MediaStream?> get localStreamUpdates => _localStreamCtrl.stream;
  Stream<MediaStream?> get remoteStreamUpdates => _remoteStreamCtrl.stream;

  CallState get state => _state;
  CallSession? get session => _session;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  void _setState(CallState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void _setSession(CallSession? s) {
    _session = s;
    _sessionCtrl.add(s);
  }

  void _wireSocket() {
    _socket.onCallSignal((data) async {
      final kind = data['_kind'] as String?;
      switch (kind) {
        case 'invite':
          _onIncomingInvite(data);
          break;
        case 'accept':
          await _onAccepted(data);
          break;
        case 'reject':
          _onRejected(data);
          break;
        case 'end':
          _onPeerEnded(data);
          break;
        case 'offer':
          await _onOffer(data);
          break;
        case 'answer':
          await _onAnswer(data);
          break;
        case 'ice':
          await _onIce(data);
          break;
      }
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> startCall({
    required int peerUserId,
    required String peerName,
    int? roomId,
    String media = 'audio',
  }) async {
    if (_state != CallState.idle) return;
    final callId = DateTime.now().millisecondsSinceEpoch.toString();
    _setSession(CallSession(
      callId: callId,
      peerUserId: peerUserId,
      peerName: peerName,
      media: media,
      isCaller: true,
    ));
    _setState(CallState.calling);

    await _ensurePeer();
    await _ensureLocalMedia(video: media == 'video');

    _socket.emit('call:invite', {
      'to_user_id': peerUserId,
      'call_id': callId,
      'room_id': roomId,
      'media': media,
    });
  }

  Future<void> accept() async {
    final s = _session;
    if (s == null) return;
    await _ensurePeer();
    await _ensureLocalMedia(video: s.media == 'video');
    _socket.emit('call:accept', {
      'to_user_id': s.peerUserId,
      'call_id': s.callId,
    });
    // Receiver sends offer once stream is ready. Caller will produce offer
    // upon receiving accept (in _onAccepted).
    _setState(CallState.connected);
  }

  Future<void> reject({String reason = 'declined'}) async {
    final s = _session;
    if (s == null) return;
    _socket.emit('call:reject', {
      'to_user_id': s.peerUserId,
      'call_id': s.callId,
      'reason': reason,
    });
    _cleanup();
  }

  Future<void> end() async {
    final s = _session;
    if (s != null) {
      _socket.emit('call:end', {
        'to_user_id': s.peerUserId,
        'call_id': s.callId,
      });
    }
    _cleanup();
  }

  bool toggleMute() {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return false;
    final newEnabled = !tracks.first.enabled;
    for (final t in tracks) {
      t.enabled = newEnabled;
    }
    return !newEnabled; // returns isMuted
  }

  bool toggleCamera() {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return false;
    final newEnabled = !tracks.first.enabled;
    for (final t in tracks) {
      t.enabled = newEnabled;
    }
    return !newEnabled;
  }

  // ── Internal handlers ─────────────────────────────────────────────────────

  void _onIncomingInvite(Map<String, dynamic> data) {
    if (_state != CallState.idle) {
      // Auto-decline if already in a call
      _socket.emit('call:reject', {
        'to_user_id': data['from_user_id'],
        'call_id': data['call_id'],
        'reason': 'busy',
      });
      return;
    }
    _setSession(CallSession(
      callId: data['call_id']?.toString() ?? '',
      peerUserId: (data['from_user_id'] as num?)?.toInt() ?? 0,
      peerName: data['from_name']?.toString() ?? 'Unknown',
      media: data['media']?.toString() ?? 'audio',
      isCaller: false,
    ));
    _setState(CallState.ringing);
  }

  Future<void> _onAccepted(Map<String, dynamic> data) async {
    final s = _session;
    if (s == null || !s.isCaller) return;
    if (data['call_id']?.toString() != s.callId) return;
    _setState(CallState.connected);
    // Caller now creates offer
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': s.media == 'video',
    });
    await _pc!.setLocalDescription(offer);
    _socket.emit('call:offer', {
      'to_user_id': s.peerUserId,
      'call_id': s.callId,
      'sdp': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  void _onRejected(Map<String, dynamic> data) {
    _cleanup();
  }

  void _onPeerEnded(Map<String, dynamic> data) {
    _cleanup();
  }

  Future<void> _onOffer(Map<String, dynamic> data) async {
    final s = _session;
    if (s == null || s.isCaller) return;
    final sdpMap = Map<String, dynamic>.from(data['sdp'] as Map);
    await _pc!.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp'] as String?, sdpMap['type'] as String?),
    );
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _socket.emit('call:answer', {
      'to_user_id': s.peerUserId,
      'call_id': s.callId,
      'sdp': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<void> _onAnswer(Map<String, dynamic> data) async {
    final s = _session;
    if (s == null || !s.isCaller) return;
    final sdpMap = Map<String, dynamic>.from(data['sdp'] as Map);
    await _pc!.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp'] as String?, sdpMap['type'] as String?),
    );
  }

  Future<void> _onIce(Map<String, dynamic> data) async {
    if (_pc == null) return;
    final c = data['candidate'] as Map?;
    if (c == null) return;
    await _pc!.addCandidate(RTCIceCandidate(
      c['candidate'] as String?,
      c['sdpMid'] as String?,
      (c['sdpMLineIndex'] as num?)?.toInt(),
    ));
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  Future<void> _ensurePeer() async {
    if (_pc != null) return;
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      final s = _session;
      if (s == null) return;
      _socket.emit('call:ice', {
        'to_user_id': s.peerUserId,
        'call_id': s.callId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams.first;
      _remoteStreamCtrl.add(_remoteStream);
    };

    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _cleanup();
      }
    };
  }

  Future<void> _ensureLocalMedia({bool video = false}) async {
    if (_localStream != null) return;
    final constraints = <String, dynamic>{
      'audio': true,
      'video': video
          ? {'width': 640, 'height': 480, 'facingMode': 'user'}
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    for (final t in _localStream!.getTracks()) {
      await _pc!.addTrack(t, _localStream!);
    }
    _localStreamCtrl.add(_localStream);
  }

  void _cleanup() {
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    try {
      _localStream?.dispose();
    } catch (_) {}
    try {
      _pc?.close();
    } catch (_) {}
    _localStream = null;
    _remoteStream = null;
    _pc = null;
    _setSession(null);
    _setState(CallState.idle);
    _localStreamCtrl.add(null);
    _remoteStreamCtrl.add(null);
  }
}
