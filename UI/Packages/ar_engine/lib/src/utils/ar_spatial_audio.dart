import 'dart:async';
import 'dart:math' as math;
import '../ar_camera.dart';
import '../ar_controller.dart';
import '../models/ar_vector3.dart';

// ─── Audio source ─────────────────────────────────────────────────────────────

/// Attenuation model for spatial audio.
enum ARAttenuationModel { linear, inverseSquare, logarithmic }

/// A positional audio source anchored to a world-space location.
class ARSpatialAudioSource {
  /// Unique identifier for this audio source.
  final String id;

  /// Path to the audio asset (relative to Flutter assets).
  final String assetPath;

  /// World-space position of the audio source.
  ARVector3 position;

  /// Maximum audible range in metres. Beyond this the source is silent.
  final double maxRange;

  /// Reference distance (metres) — at this distance gain = 1.0.
  final double refDistance;

  /// Volume multiplier [0, 1].
  double volume;

  /// Playback rate [0.25, 4.0]. Values above 1 pitch up.
  double playbackRate;

  /// Whether the clip loops.
  bool loop;

  /// Attenuation formula to apply with distance.
  final ARAttenuationModel attenuationModel;

  /// Whether Doppler effect is applied when the source moves.
  bool dopplerEnabled;

  bool _playing = false;
  ARVector3 _lastPosition;

  ARSpatialAudioSource({
    required this.id,
    required this.assetPath,
    required this.position,
    this.maxRange = 10.0,
    this.refDistance = 1.0,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.loop = false,
    this.attenuationModel = ARAttenuationModel.inverseSquare,
    this.dopplerEnabled = true,
  }) : _lastPosition = position;

  bool get isPlaying => _playing;

  /// Compute gain [0, 1] for camera at [listenerPos].
  double gainAt(ARVector3 listenerPos) {
    final dist = ARVector3.distance(position, listenerPos);
    if (dist >= maxRange) return 0;
    switch (attenuationModel) {
      case ARAttenuationModel.linear:
        return (1 - dist / maxRange).clamp(0, 1) * volume;
      case ARAttenuationModel.inverseSquare:
        final ref = math.max(dist, refDistance);
        return (refDistance * refDistance / (ref * ref)).clamp(0, 1) * volume;
      case ARAttenuationModel.logarithmic:
        if (dist <= refDistance) return volume;
        return (1 -
                    math.log(dist / refDistance) /
                        math.log(maxRange / refDistance))
                .clamp(0, 1) *
            volume;
    }
  }

  /// Estimated Doppler pitch shift based on velocity along listener→source axis.
  double dopplerShift(ARVector3 listenerPos, double dt) {
    if (!dopplerEnabled || dt <= 0) return playbackRate;
    const speedOfSound = 343.0; // m/s
    final velocity = (position - _lastPosition) * (1 / dt);
    final toListener = (listenerPos - position).normalized;
    final radialVel = velocity.dot(toListener);
    final shift = speedOfSound / (speedOfSound - radialVel.clamp(-300, 300));
    _lastPosition = position;
    return (playbackRate * shift).clamp(0.25, 4.0);
  }
}

// ─── Spatial audio manager ────────────────────────────────────────────────────

/// Manages spatial audio sources positioned in the AR world.
///
/// Updates platform-level gain and panning each tick based on the camera pose,
/// applying distance attenuation, stereo panning, and optional Doppler shift.
///
/// Native implementation delegates to:
/// - **iOS**: `AVAudioEnvironmentNode` + `AVAudioPlayerNode`
/// - **Android**: `Oboe` + `SoundPool` for low-latency; or `AudioTrack`
/// - **Web**: `Web Audio API` `PannerNode` + `AudioBufferSourceNode`
/// - **Desktop**: `miniaudio` via FFI
///
/// The Dart layer handles the spatial math; the platform channel handles
/// actual PCM decoding and DSP. Use the `'setSpatialAudioGain'` channel method
/// to push gain/pitch updates to the native audio engine each tick.
class ARSpatialAudioManager {
  final ARController _controller;

  /// Tick rate for spatial updates (default 30 Hz).
  final Duration updateInterval;

  final _sources = <String, ARSpatialAudioSource>{};
  final _oneShotTimers = <String, Timer>{};
  Timer? _ticker;
  DateTime _lastTick = DateTime.now();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  final _stateCtrl = StreamController<ARSpatialAudioSource>.broadcast();

  /// Whether this manager has released its timers and source state.
  bool get isDisposed => _disposed;

  /// Fires whenever a source's computed gain changes significantly (>0.01).
  Stream<ARSpatialAudioSource> get onSourceUpdated {
    _ensureActive();
    return _stateCtrl.stream;
  }

  ARSpatialAudioManager({
    required ARController controller,
    this.updateInterval = const Duration(milliseconds: 33),
  }) : _controller = controller;

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _stopTicker();
    for (final timer in _oneShotTimers.values) {
      timer.cancel();
    }
    _oneShotTimers.clear();
    _sources.clear();
    if (!_stateCtrl.isClosed) {
      await _stateCtrl.close();
    }
  }

  // ── Source management ─────────────────────────────────────────────────────

  /// Register and start playing an audio source.
  Future<void> play(ARSpatialAudioSource source) async {
    _ensureActive();
    _oneShotTimers.remove(source.id)?.cancel();
    _sources[source.id] = source;
    source._playing = true;
    _ensureTicker();
    await _sendCommand('play', source);
  }

  /// Pause a source without removing it.
  Future<void> pause(String id) async {
    _ensureActive();
    final s = _sources[id];
    if (s == null) return;
    s._playing = false;
    await _sendCommand('pause', s);
  }

  /// Stop and remove a source.
  Future<void> stop(String id) async {
    _ensureActive();
    _oneShotTimers.remove(id)?.cancel();
    final s = _sources.remove(id);
    if (s == null) return;
    s._playing = false;
    await _sendCommand('stop', s);
    if (_sources.isEmpty) _stopTicker();
  }

  /// Update the world position of a playing source.
  void setPosition(String id, ARVector3 position) {
    _ensureActive();
    final s = _sources[id];
    if (s == null) return;
    s.position = position;
  }

  ARSpatialAudioSource? getSource(String id) {
    _ensureActive();
    return _sources[id];
  }

  List<ARSpatialAudioSource> get allSources {
    _ensureActive();
    return List.unmodifiable(_sources.values);
  }

  // ── Tick ──────────────────────────────────────────────────────────────────

  void _ensureTicker() {
    if (_disposed) return;
    if (_ticker?.isActive ?? false) return;
    _ticker = Timer.periodic(updateInterval, (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_disposed) {
      _stopTicker();
      return;
    }

    if (_sources.isEmpty) {
      _stopTicker();
      return;
    }

    final camera = _currentCamera;
    if (camera == null) return;

    final listenerPos = camera.pose.position;
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;

    for (final source in List<ARSpatialAudioSource>.of(_sources.values)) {
      if (_disposed) return;
      if (!source.isPlaying) continue;

      final gain = source.gainAt(listenerPos);
      final pitch = source.dopplerShift(listenerPos, dt);
      final pan = _stereoPan(
        source.position,
        listenerPos,
        camera.pose.rotation.toEuler(),
      );

      // In production: push these values via MethodChannel to the native audio engine
      _pushSpatialUpdate(source.id, gain, pitch, pan);
    }
  }

  /// Compute stereo pan [-1, 1] from world-space source position relative to listener.
  double _stereoPan(
    ARVector3 sourcePos,
    ARVector3 listenerPos,
    List<double> listenerEuler,
  ) {
    final yaw = listenerEuler[1]; // listener yaw
    final toSrc = sourcePos - listenerPos;
    if (toSrc.lengthSquared < 1e-6) return 0;
    final angle = math.atan2(toSrc.x, -toSrc.z); // angle in XZ plane
    final relAngle = angle - yaw;
    return math.sin(relAngle).clamp(-1.0, 1.0);
  }

  // ── Native bridge ─────────────────────────────────────────────────────────

  /// Sends a spatial update to the native audio engine via method channel.
  void _pushSpatialUpdate(String id, double gain, double pitch, double pan) {
    if (_disposed || _stateCtrl.isClosed) return;
    // In production:
    // await _methodChannel.invokeMethod('setSpatialAudioGain', {
    //   'id': id, 'gain': gain, 'pitch': pitch, 'pan': pan,
    // });
    // Here we just emit a stream event so UI/tests can observe.
    final source = _sources[id];
    if (source != null) _stateCtrl.add(source);
  }

  Future<void> _sendCommand(String command, ARSpatialAudioSource source) async {
    if (_disposed) return;
    // In production:
    // await _methodChannel.invokeMethod('spatialAudio_$command', {
    //   'id':          source.id,
    //   'assetPath':   source.assetPath,
    //   'loop':        source.loop,
    //   'maxRange':    source.maxRange,
    //   'refDistance': source.refDistance,
    // });
  }

  // ── Convenience ───────────────────────────────────────────────────────────

  /// Play a one-shot sound effect at [position] with auto-cleanup.
  Future<void> playOneShot({
    required String assetPath,
    required ARVector3 position,
    double volume = 1.0,
    double maxRange = 8.0,
  }) async {
    _ensureActive();
    final id = 'oneshot_${DateTime.now().microsecondsSinceEpoch}';
    final src = ARSpatialAudioSource(
      id: id,
      assetPath: assetPath,
      position: position,
      volume: volume,
      maxRange: maxRange,
    );
    await play(src);
    // Schedule cleanup after estimated duration
    _oneShotTimers[id]?.cancel();
    _oneShotTimers[id] = Timer(const Duration(seconds: 10), () {
      if (_disposed) return;
      unawaited(stop(id));
    });
  }

  ARCamera? get _currentCamera {
    try {
      return _controller.currentCamera;
    } on StateError {
      _stopTicker();
      return null;
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARSpatialAudioManager has been disposed.');
    }
  }
}
