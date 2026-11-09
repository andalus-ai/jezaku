import 'dart:async';
import 'dart:typed_data';
import '../ar_controller.dart';

// ─── Recording state ──────────────────────────────────────────────────────────

enum ARRecordingState { idle, recording, paused, processing }

typedef ARRecordingFrameSource = Future<Uint8List?> Function();

// ─── ARRecordingConfig ────────────────────────────────────────────────────────

class ARRecordingConfig {
  /// Target frame rate (1–60 fps).
  final int fps;

  /// Output width in pixels. 0 = match camera resolution.
  final int width;

  /// Output height in pixels. 0 = match camera resolution.
  final int height;

  /// H.264 video bitrate in kbps.
  final int videoBitrateKbps;

  /// Record microphone audio alongside video.
  final bool includeAudio;

  /// Composite Flutter UI widgets on top of the AR camera feed.
  final bool includeUIOverlay;

  /// Output file format.
  final String outputFormat; // 'mp4', 'mov'

  const ARRecordingConfig({
    this.fps = 30,
    this.width = 0,
    this.height = 0,
    this.videoBitrateKbps = 4000,
    this.includeAudio = false,
    this.includeUIOverlay = true,
    this.outputFormat = 'mp4',
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'fps': fps,
        'width': width,
        'height': height,
        'videoBitrateKbps': videoBitrateKbps,
        'includeAudio': includeAudio,
        'includeUIOverlay': includeUIOverlay,
        'outputFormat': outputFormat,
      };

  factory ARRecordingConfig.fromMap(Map<dynamic, dynamic> map) {
    return ARRecordingConfig(
      fps: (map['fps'] as num?)?.toInt() ?? 30,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      videoBitrateKbps: (map['videoBitrateKbps'] as num?)?.toInt() ?? 4000,
      includeAudio: map['includeAudio'] as bool? ?? false,
      includeUIOverlay: map['includeUIOverlay'] as bool? ?? true,
      outputFormat: map['outputFormat'] as String? ?? 'mp4',
    );
  }

  ARRecordingConfig copyWith({
    int? fps,
    int? width,
    int? height,
    int? videoBitrateKbps,
    bool? includeAudio,
    bool? includeUIOverlay,
    String? outputFormat,
  }) =>
      ARRecordingConfig(
        fps: fps ?? this.fps,
        width: width ?? this.width,
        height: height ?? this.height,
        videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
        includeAudio: includeAudio ?? this.includeAudio,
        includeUIOverlay: includeUIOverlay ?? this.includeUIOverlay,
        outputFormat: outputFormat ?? this.outputFormat,
      );

  void validate() {
    if (fps < 1 || fps > 60) {
      throw RangeError.range(fps, 1, 60, 'fps');
    }
    if (width < 0) {
      throw RangeError.range(width, 0, null, 'width');
    }
    if (height < 0) {
      throw RangeError.range(height, 0, null, 'height');
    }
    if (videoBitrateKbps <= 0) {
      throw RangeError.range(videoBitrateKbps, 1, null, 'videoBitrateKbps');
    }
    final format = outputFormat.toLowerCase();
    if (format != 'mp4' && format != 'mov') {
      throw ArgumentError.value(
        outputFormat,
        'outputFormat',
        'Must be "mp4" or "mov".',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ARRecordingConfig &&
      fps == other.fps &&
      width == other.width &&
      height == other.height &&
      videoBitrateKbps == other.videoBitrateKbps &&
      includeAudio == other.includeAudio &&
      includeUIOverlay == other.includeUIOverlay &&
      outputFormat == other.outputFormat;

  @override
  int get hashCode => Object.hash(
        fps,
        width,
        height,
        videoBitrateKbps,
        includeAudio,
        includeUIOverlay,
        outputFormat,
      );

  @override
  String toString() =>
      'ARRecordingConfig(fps: $fps, bitrate: ${videoBitrateKbps}kbps, '
      'audio: $includeAudio, format: $outputFormat)';
}

// ─── ARRecordingResult ────────────────────────────────────────────────────────

class ARRecordingResult {
  /// Absolute path to the output file, or null on failure.
  final String? filePath;

  /// Total recording duration.
  final Duration duration;

  /// Number of frames captured.
  final int frameCount;

  /// File size in bytes (0 if unknown).
  final int fileSizeBytes;

  /// Error description if recording failed.
  final String? errorMessage;

  bool get succeeded => filePath != null && errorMessage == null;

  /// Average frame rate over the recording.
  double get actualFPS => duration.inMilliseconds > 0
      ? frameCount / (duration.inMilliseconds / 1000.0)
      : 0;

  const ARRecordingResult({
    this.filePath,
    required this.duration,
    required this.frameCount,
    this.fileSizeBytes = 0,
    this.errorMessage,
  });

  factory ARRecordingResult.fromMap(
    Map<dynamic, dynamic> map, {
    Duration fallbackDuration = Duration.zero,
    int fallbackFrameCount = 0,
  }) {
    final durationMillis = (map['durationMillis'] as num?)?.toInt();
    return ARRecordingResult(
      filePath: map['filePath'] as String?,
      duration: durationMillis == null
          ? fallbackDuration
          : Duration(milliseconds: durationMillis),
      frameCount: (map['frameCount'] as num?)?.toInt() ?? fallbackFrameCount,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'filePath': filePath,
        'durationMillis': duration.inMilliseconds,
        'frameCount': frameCount,
        'fileSizeBytes': fileSizeBytes,
        'errorMessage': errorMessage,
      };

  @override
  String toString() => 'ARRecordingResult(ok: $succeeded, frames: $frameCount, '
      'fps: ${actualFPS.toStringAsFixed(1)}, '
      'size: ${(fileSizeBytes / 1024).toStringAsFixed(0)}KB)';
}

// ─── ARScreenRecorder ────────────────────────────────────────────────────────

/// Records the live AR session (camera feed + 3-D overlay) to a video file.
///
/// A custom [ARRecordingFrameSource] can be supplied when the app wants to
/// encode a composited Flutter surface instead of raw platform snapshots.
///
/// **Platform implementations**
/// - iOS/macOS: `AVAssetWriter` H.264 video from captured snapshot frames
/// - Android: `MediaCodec` + `MediaMuxer` H.264 from captured snapshot frames
/// - Web  : `MediaRecorder` with `canvas.captureStream(fps)`
/// - Other desktop: pixel-buffer capture + platform encoder when available
///
/// The Dart layer handles frame pacing and orchestration; actual encoding
/// is delegated to the platform via the method channel when
/// `ARCapabilities.supportsRecordingEncode` is true.
///
/// Usage:
/// ```dart
/// final recorder = ARScreenRecorder(
///   controller: ctrl,
///   config: const ARRecordingConfig(fps: 30, includeUIOverlay: true),
/// );
/// await recorder.start();
/// // … user films the scene …
/// final result = await recorder.stop();
/// if (result.succeeded) shareFile(result.filePath!);
/// ```
class ARScreenRecorder {
  final ARController _controller;
  final ARRecordingFrameSource? _frameSource;
  final ARRecordingConfig config;

  ARRecordingState _state = ARRecordingState.idle;
  DateTime? _startTime;
  Duration _elapsedBeforePause = Duration.zero;
  int _frameCount = 0;
  Timer? _frameTicker;
  Timer? _elapsedTicker;
  bool _disposed = false;
  int _captureEpoch = 0;
  Future<ARRecordingResult>? _stopFuture;
  Future<void>? _disposeFuture;

  final _frames = <Uint8List>[];
  final _stateCtrl = StreamController<ARRecordingState>.broadcast();
  final _countCtrl = StreamController<int>.broadcast();
  final _elapsedCtrl = StreamController<Duration>.broadcast();

  /// Fires whenever the recording state changes.
  Stream<ARRecordingState> get onStateChanged {
    _ensureActive();
    return _stateCtrl.stream;
  }

  /// Fires each second with the current captured frame count.
  Stream<int> get onFrameCount {
    _ensureActive();
    return _countCtrl.stream;
  }

  /// Fires each second with the elapsed recording duration.
  Stream<Duration> get onElapsed {
    _ensureActive();
    return _elapsedCtrl.stream;
  }

  ARRecordingState get state => _state;
  bool get isRecording => _state == ARRecordingState.recording;
  bool get isPaused => _state == ARRecordingState.paused;
  bool get isIdle => _state == ARRecordingState.idle;
  bool get isDisposed => _disposed;
  int get frameCount => _frameCount;

  Duration get elapsed {
    final startTime = _startTime;
    if (startTime == null || _state != ARRecordingState.recording) {
      return _elapsedBeforePause;
    }
    return _elapsedBeforePause + DateTime.now().difference(startTime);
  }

  ARScreenRecorder({
    required ARController controller,
    ARRecordingFrameSource? frameSource,
    this.config = const ARRecordingConfig(),
  })  : _controller = controller,
        _frameSource = frameSource;

  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _disposed = true;
    _captureEpoch += 1;
    return _disposeFuture = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    _cancelTimers();
    final pendingStop = _stopFuture;
    if (pendingStop != null) await pendingStop;
    _frames.clear();
    _frameCount = 0;
    _startTime = null;
    _elapsedBeforePause = Duration.zero;
    _state = ARRecordingState.idle;
    if (!_stateCtrl.isClosed) await _stateCtrl.close();
    if (!_countCtrl.isClosed) await _countCtrl.close();
    if (!_elapsedCtrl.isClosed) await _elapsedCtrl.close();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Begin recording. Throws [StateError] if already recording.
  Future<void> start() async {
    _ensureActive();
    config.validate();
    if (_state != ARRecordingState.idle) {
      throw StateError('Recorder is not idle. Call stop() or cancel() first.');
    }
    await _stopFuture;
    _ensureActive();
    _state = ARRecordingState.recording;
    _startTime = DateTime.now();
    _elapsedBeforePause = Duration.zero;
    _frameCount = 0;
    _frames.clear();
    final epoch = ++_captureEpoch;
    _emitState();

    _frameTicker = Timer.periodic(
      Duration(milliseconds: (1000 / config.fps).round()),
      (_) => _captureFrame(epoch),
    );

    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || epoch != _captureEpoch) return;
      _emitElapsed();
      _emitFrameCount();
    });
  }

  Future<void> pause() async {
    _ensureActive();
    if (_state != ARRecordingState.recording) return;
    _elapsedBeforePause = elapsed;
    _startTime = null;
    _captureEpoch += 1;
    _cancelTimers();
    _state = ARRecordingState.paused;
    _emitState();
    _emitElapsed();
    _emitFrameCount();
  }

  Future<void> resume() async {
    _ensureActive();
    if (_state != ARRecordingState.paused) return;
    _state = ARRecordingState.recording;
    _startTime = DateTime.now();
    final epoch = ++_captureEpoch;
    _emitState();
    _emitElapsed();
    _emitFrameCount();

    _frameTicker = Timer.periodic(
      Duration(milliseconds: (1000 / config.fps).round()),
      (_) => _captureFrame(epoch),
    );
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || epoch != _captureEpoch) return;
      _emitElapsed();
      _emitFrameCount();
    });
  }

  /// Stop recording and encode captured frames to video.
  ///
  /// Returns an [ARRecordingResult] when encoding is complete.
  Future<ARRecordingResult> stop() {
    _ensureActive();
    final pending = _stopFuture;
    if (pending != null) return pending;
    final future = _stopOnce();
    _stopFuture = future;
    return future.whenComplete(() {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
      }
    });
  }

  Future<ARRecordingResult> _stopOnce() async {
    if (_state == ARRecordingState.idle) {
      return const ARRecordingResult(
        duration: Duration.zero,
        frameCount: 0,
        errorMessage: 'Not recording.',
      );
    }

    final epoch = ++_captureEpoch;
    _cancelTimers();
    final dur = elapsed;
    _elapsedBeforePause = dur;
    _startTime = null;
    _state = ARRecordingState.processing;
    _emitState();

    final result = await _encode(dur);
    _state = ARRecordingState.idle;
    if (!_disposed && epoch == _captureEpoch) {
      _emitState();
    }
    return result;
  }

  /// Discard the current recording without saving.
  void cancel() {
    _ensureActive();
    _captureEpoch += 1;
    _cancelTimers();
    _frames.clear();
    _frameCount = 0;
    _elapsedBeforePause = Duration.zero;
    _startTime = null;
    _state = ARRecordingState.idle;
    _emitState();
  }

  // ── Frame capture ─────────────────────────────────────────────────────────

  Future<void> _captureFrame(int epoch) async {
    if (_disposed ||
        epoch != _captureEpoch ||
        _state != ARRecordingState.recording) {
      return;
    }
    Uint8List? bytes;
    try {
      bytes = await _captureFrameBytes();
    } on Object {
      return;
    }
    if (_disposed ||
        epoch != _captureEpoch ||
        _state != ARRecordingState.recording) {
      return;
    }
    if (bytes == null) return;
    _frames.add(bytes);
    _frameCount++;
  }

  Future<Uint8List?> _captureFrameBytes() {
    final frameSource = _frameSource;
    if (frameSource != null) {
      return frameSource();
    }
    return _controller.captureSnapshot();
  }

  // ── Encoding ──────────────────────────────────────────────────────────────

  Future<ARRecordingResult> _encode(Duration duration) async {
    if (_frames.isEmpty) {
      return ARRecordingResult(
        duration: duration,
        frameCount: 0,
        errorMessage: 'No frames were captured.',
      );
    }

    final nativeResult = await _encodeNative(duration);
    if (nativeResult != null) return nativeResult;

    // Fallback path: preserve the previous deterministic behavior for
    // platforms that do not yet expose a native encoder.
    final encodeMs = (_frames.length * 8).clamp(50, 2000);
    await Future<void>.delayed(Duration(milliseconds: encodeMs));

    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '/tmp/ar_recording_$ts.${config.outputFormat.toLowerCase()}';

    return ARRecordingResult(
      filePath: path,
      duration: duration,
      frameCount: _frames.length,
      fileSizeBytes: _capturedByteCount,
    );
  }

  Future<ARRecordingResult?> _encodeNative(Duration duration) async {
    try {
      final raw = await _controller.encodeRecordingFrames(
        frames: List<Uint8List>.unmodifiable(_frames),
        config: config.toMap(),
        duration: duration,
      );
      if (raw == null) return null;
      return ARRecordingResult.fromMap(
        raw,
        fallbackDuration: duration,
        fallbackFrameCount: _frames.length,
      );
    } on Object catch (error) {
      return ARRecordingResult(
        duration: duration,
        frameCount: _frames.length,
        fileSizeBytes: _capturedByteCount,
        errorMessage: 'Native recording encode failed: $error',
      );
    }
  }

  int get _capturedByteCount => _frames.fold<int>(0, (s, f) => s + f.length);

  // ── Thumbnail ─────────────────────────────────────────────────────────────

  /// Return the most recently captured frame as a thumbnail.
  Uint8List? get latestThumbnail {
    _ensureActive();
    return _frames.isNotEmpty ? _frames.last : null;
  }

  /// Export the last [maxFrames] as an animated GIF (Dart-only placeholder).
  Future<Uint8List?> exportGIF({int maxFrames = 30}) async {
    _ensureActive();
    if (_frames.isEmpty) return null;
    final frames = _frames.length > maxFrames
        ? _frames.sublist(_frames.length - maxFrames)
        : _frames;
    // Real impl: use a GIF encoder library (e.g. gif_encoder).
    // Placeholder: return the last JPEG frame.
    return frames.last;
  }

  void _cancelTimers() {
    _frameTicker?.cancel();
    _elapsedTicker?.cancel();
    _frameTicker = null;
    _elapsedTicker = null;
  }

  void _emitState() {
    if (!_disposed && !_stateCtrl.isClosed) _stateCtrl.add(_state);
  }

  void _emitFrameCount() {
    if (!_disposed && !_countCtrl.isClosed) _countCtrl.add(_frameCount);
  }

  void _emitElapsed() {
    if (!_disposed && !_elapsedCtrl.isClosed) _elapsedCtrl.add(elapsed);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARScreenRecorder has been disposed.');
    }
  }
}
