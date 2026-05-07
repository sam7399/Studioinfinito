import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Records audio via the browser's MediaRecorder API.
/// Returns the recorded bytes (audio/webm) when stopped.
class VoiceRecorder {
  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  final List<JSAny> _chunks = [];
  Completer<Uint8List?>? _stopCompleter;
  DateTime? _startedAt;

  bool get isRecording => _recorder != null;
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// Start a recording. Throws if microphone access is denied.
  Future<void> start() async {
    if (_recorder != null) return;

    final constraints = {'audio': true, 'video': false}.jsify() as JSObject;
    final streamPromise =
        web.window.navigator.mediaDevices.getUserMedia(constraints as web.MediaStreamConstraints);
    _stream = await streamPromise.toDart;

    final options = web.MediaRecorderOptions(mimeType: 'audio/webm');
    _recorder = web.MediaRecorder(_stream!, options);
    _chunks.clear();
    _startedAt = DateTime.now();

    _recorder!.addEventListener(
      'dataavailable',
      ((web.Event ev) {
        final blob = (ev as web.BlobEvent).data;
        _chunks.add(blob as JSAny);
      }).toJS,
    );

    _recorder!.addEventListener(
      'stop',
      ((web.Event _) {
        // Schedule the async finalization without making the listener async.
        Future(() async {
          try {
            if (_chunks.isEmpty) {
              _stopCompleter?.complete(null);
            } else {
              final blob = web.Blob(
                _chunks.toJS,
                web.BlobPropertyBag(type: 'audio/webm'),
              );
              final ab = await blob.arrayBuffer().toDart;
              final bytes = (ab as JSArrayBuffer).toDart.asUint8List();
              _stopCompleter?.complete(bytes);
            }
          } catch (e) {
            _stopCompleter?.complete(null);
          } finally {
            _stream?.getTracks().toDart.forEach((t) {
              (t as web.MediaStreamTrack).stop();
            });
            _stream = null;
            _recorder = null;
          }
        });
      }).toJS,
    );

    _recorder!.start();
  }

  /// Stop recording and return the recorded bytes (or null on cancel/empty).
  Future<Uint8List?> stop() async {
    if (_recorder == null) return null;
    _stopCompleter = Completer<Uint8List?>();
    _recorder!.stop();
    return _stopCompleter!.future;
  }

  /// Cancel without uploading.
  void cancel() {
    if (_recorder == null) return;
    try {
      _recorder!.stop();
    } catch (_) {}
    _stream?.getTracks().toDart.forEach((t) {
      (t as web.MediaStreamTrack).stop();
    });
    _stream = null;
    _recorder = null;
    _chunks.clear();
    _stopCompleter?.complete(null);
    _stopCompleter = null;
  }
}
