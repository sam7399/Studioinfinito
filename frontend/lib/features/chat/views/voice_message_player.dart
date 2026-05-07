import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Plays an audio attachment in-place by fetching the bytes (with auth) into
/// a blob URL and feeding it to an HTMLAudioElement.
class VoiceMessagePlayer extends StatefulWidget {
  final Future<Uint8List> Function() fetchBytes;
  final bool isMine;
  final String? title;

  const VoiceMessagePlayer({
    super.key,
    required this.fetchBytes,
    required this.isMine,
    this.title,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  web.HTMLAudioElement? _audio;
  String? _objectUrl;
  bool _loading = false;
  bool _playing = false;
  double _duration = 0;
  double _position = 0;
  StreamSubscription? _tick;

  @override
  void dispose() {
    _audio?.pause();
    if (_objectUrl != null) {
      try {
        web.URL.revokeObjectURL(_objectUrl!);
      } catch (_) {}
    }
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_audio != null) return;
    setState(() => _loading = true);
    try {
      final bytes = await widget.fetchBytes();
      final blob = web.Blob(
        [Uint8List.fromList(bytes).toJS].toJS,
        web.BlobPropertyBag(type: 'audio/webm'),
      );
      _objectUrl = web.URL.createObjectURL(blob);
      final el = web.HTMLAudioElement();
      el.src = _objectUrl!;
      el.preload = 'auto';
      el.addEventListener(
        'loadedmetadata',
        ((web.Event _) {
          if (mounted) setState(() => _duration = el.duration);
        }).toJS,
      );
      el.addEventListener(
        'timeupdate',
        ((web.Event _) {
          if (mounted) setState(() => _position = el.currentTime);
        }).toJS,
      );
      el.addEventListener(
        'ended',
        ((web.Event _) {
          if (mounted) {
            setState(() {
              _playing = false;
              _position = 0;
            });
            el.currentTime = 0;
          }
        }).toJS,
      );
      _audio = el;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlay() async {
    if (_audio == null) await _ensureLoaded();
    if (_audio == null) return;
    if (_playing) {
      _audio!.pause();
      setState(() => _playing = false);
    } else {
      await _audio!.play().toDart;
      if (mounted) setState(() => _playing = true);
    }
  }

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite || s < 0) return '0:00';
    final mm = (s ~/ 60).toString();
    final ss = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? Colors.white : const Color(0xFFE65C00);
    final bg = (widget.isMine ? Colors.white : const Color(0xFFE65C00))
        .withOpacity(0.12);

    final progress = (_duration > 0 ? (_position / _duration).clamp(0.0, 1.0) : 0.0);

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _loading ? null : _togglePlay,
            customBorder: const CircleBorder(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      size: 18,
                      color: widget.isMine ? const Color(0xFFE65C00) : Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: fg.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.mic, size: 11, color: fg),
                      const SizedBox(width: 4),
                      Text(
                        widget.title ?? 'Voice message',
                        style: TextStyle(fontSize: 10, color: fg),
                      ),
                    ]),
                    Text(
                      _playing
                          ? '${_fmt(_position)} / ${_fmt(_duration)}'
                          : _fmt(_duration > 0 ? _duration : _position),
                      style: TextStyle(fontSize: 10, color: fg),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
