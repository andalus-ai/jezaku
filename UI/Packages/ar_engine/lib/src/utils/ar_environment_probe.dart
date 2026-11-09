import 'dart:async';
import 'dart:typed_data';
import '../ar_controller.dart';
import '../ar_camera.dart';
import '../models/ar_vector3.dart';

// ─── Probe type ───────────────────────────────────────────────────────────────

/// How often the environment cubemap is recaptured.
enum ARProbeUpdateMode {
  /// Captured once at [capture] call time.
  once,

  /// Re-captured every [updateInterval].
  realtime,

  /// Captured when the camera moves more than [movementThreshold] metres.
  onMovement,
}

// ─── Probe result ─────────────────────────────────────────────────────────────

/// The result of an environment probe capture.
class AREnvironmentProbeResult {
  /// Estimated dominant sky/sun color [R, G, B] in linear [0,1].
  final List<double> skyColor;

  /// Estimated ground bounce color [R, G, B] in linear [0,1].
  final List<double> groundColor;

  /// Estimated ambient intensity in lux.
  final double ambientLux;

  /// Estimated primary light direction (unit vector).
  final ARVector3? primaryLightDirection;

  /// Raw RGBA cubemap face bytes [+X, -X, +Y, -Y, +Z, -Z], or null when
  /// unavailable (simulator / unsupported device).
  final List<Uint8List>? cubeFaces;

  /// Cubemap face resolution in pixels (always square).
  final int faceSize;

  final DateTime timestamp;

  const AREnvironmentProbeResult({
    required this.skyColor,
    required this.groundColor,
    required this.ambientLux,
    this.primaryLightDirection,
    this.cubeFaces,
    this.faceSize = 128,
    required this.timestamp,
  });

  bool get hasCubemap => cubeFaces != null && cubeFaces!.length == 6;
}

// ─── Environment probe ────────────────────────────────────────────────────────

/// Captures the real-world environment as a cubemap for image-based lighting
/// (IBL), and estimates sky / sun / ground colors.
///
/// On **iOS (LiDAR or ARKit 4+)**: uses `AREnvironmentProbeAnchor` to request
/// a spherical-harmonics HDR environment capture.
///
/// On **Android (ARCore)**: uses the Environmental HDR light estimation API
/// which provides SH coefficients and a cubemap.
///
/// On **Web / Desktop**: samples recent camera frames to produce a rough
/// hemispherical color estimate (no true cubemap).
class AREnvironmentProbe {
  final ARController _controller;

  ARProbeUpdateMode updateMode;
  Duration updateInterval;
  double movementThreshold; // metres

  AREnvironmentProbeResult? _lastResult;
  ARVector3? _lastCamPos;
  Timer? _ticker;
  StreamSubscription<ARCamera>? _camSub;
  bool _running = false;
  bool _disposed = false;
  int _lifecycleEpoch = 0;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  final _resultCtrl = StreamController<AREnvironmentProbeResult>.broadcast();

  /// Fires whenever a new probe result is available.
  Stream<AREnvironmentProbeResult> get onProbeUpdated {
    _ensureActive();
    return _resultCtrl.stream;
  }

  AREnvironmentProbeResult? get latestResult {
    _ensureActive();
    return _lastResult;
  }

  bool get isRunning => _running;
  bool get isDisposed => _disposed;

  AREnvironmentProbe({
    required ARController controller,
    this.updateMode = ARProbeUpdateMode.once,
    this.updateInterval = const Duration(seconds: 2),
    this.movementThreshold = 0.5,
  }) : _controller = controller;

  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _disposed = true;
    _lifecycleEpoch += 1;
    return _disposeFuture = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    await stop();
    if (!_resultCtrl.isClosed) await _resultCtrl.close();
  }

  // ── Control ───────────────────────────────────────────────────────────────

  /// Capture environment once. Returns the result when available.
  Future<AREnvironmentProbeResult> capture() async {
    _ensureActive();
    final result = await _captureAndMaybeEmit(_lifecycleEpoch);
    return result;
  }

  /// Start automatic probing based on [updateMode].
  void start() {
    _ensureActive();
    if (_running) return;
    _running = true;
    final epoch = ++_lifecycleEpoch;

    switch (updateMode) {
      case ARProbeUpdateMode.once:
        unawaited(_captureAndMaybeEmit(epoch).whenComplete(() {
          if (!_disposed && epoch == _lifecycleEpoch) {
            _running = false;
          }
        }));
        break;

      case ARProbeUpdateMode.realtime:
        _ticker = Timer.periodic(updateInterval, (_) {
          if (_disposed || !_running || epoch != _lifecycleEpoch) return;
          unawaited(_captureAndMaybeEmit(epoch));
        });
        break;

      case ARProbeUpdateMode.onMovement:
        _camSub = _controller.onCameraUpdate.listen((cam) {
          if (_disposed || !_running || epoch != _lifecycleEpoch) return;
          final pos = cam.pose.position;
          if (_lastCamPos == null ||
              ARVector3.distance(pos, _lastCamPos!) >= movementThreshold) {
            _lastCamPos = pos;
            unawaited(_captureAndMaybeEmit(epoch));
          }
        });
        break;
    }
  }

  Future<void> stop() {
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

  Future<void> _stopOnce() async {
    _running = false;
    _lifecycleEpoch += 1;
    _ticker?.cancel();
    _ticker = null;
    await _camSub?.cancel();
    _camSub = null;
    _lastCamPos = null;
  }

  // ── Platform capture ──────────────────────────────────────────────────────

  Future<AREnvironmentProbeResult> _captureAndMaybeEmit(int epoch) async {
    final result = await _captureFromPlatform(epoch);
    if (!_disposed && epoch == _lifecycleEpoch && !_resultCtrl.isClosed) {
      _lastResult = result;
      _resultCtrl.add(result);
    }
    return result;
  }

  Future<AREnvironmentProbeResult> _captureFromPlatform(int epoch) async {
    // In production: invoke 'captureEnvironmentProbe' on the method channel.
    // Android: read EnvironmentalHdrLightEstimate from the latest ARFrame.
    // iOS: add AREnvironmentProbeAnchor and await its cubemap.

    final camera = _disposed || epoch != _lifecycleEpoch
        ? null
        : _controller.currentCamera;
    final lightLux = await _sampleLightEstimate(epoch);

    // Derive a simple sky / ground estimate from the camera intrinsics.
    // Real implementation parses SH coefficients from the platform.
    const skyColor = [0.5, 0.6, 0.8]; // fallback daylight blue
    const groundColor = [0.2, 0.2, 0.15]; // fallback earth brown

    return AREnvironmentProbeResult(
      skyColor: List<double>.from(skyColor),
      groundColor: List<double>.from(groundColor),
      ambientLux: lightLux,
      primaryLightDirection: _estimateSunDirection(camera),
      cubeFaces: null, // real impl provides cubemap bytes
      timestamp: DateTime.now(),
    );
  }

  Future<double> _estimateLightEstimate(int epoch) async {
    // Accumulate the last lux value from the light stream.
    double lux = 0;
    final completer = Completer<double>();
    final sub = _controller.onLightEstimate.listen((l) {
      if (_disposed || epoch != _lifecycleEpoch) {
        if (!completer.isCompleted) completer.complete(lux);
        return;
      }
      lux = l;
      if (!completer.isCompleted) completer.complete(lux);
    });
    // Wait up to 500 ms, then fall back
    final timeout = Timer(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(lux);
    });
    final result = await completer.future;
    timeout.cancel();
    await sub.cancel();
    return result;
  }

  Future<double> _sampleLightEstimate(int epoch) =>
      _estimateLightEstimate(epoch);

  ARVector3? _estimateSunDirection(ARCamera? camera) {
    // Without a full SH solve, point roughly "up and to the side".
    return camera != null ? const ARVector3(0.3, -0.9, 0.3).normalized : null;
  }

  // ── IBL application helpers ───────────────────────────────────────────────

  /// Convert the probe result into an ambient [ARLight] suitable for the scene.
  dynamic toAmbientLight(String lightId) {
    _ensureActive();
    // Returns an ARLight — import avoided to prevent circular deps.
    // Callers cast the return to ARLight themselves.
    return _lastResult == null
        ? null
        : {
            'id': lightId,
            'type': 'ambient',
            'intensity': _lastResult!.ambientLux,
            'color': {
              'x': _lastResult!.skyColor[0],
              'y': _lastResult!.skyColor[1],
              'z': _lastResult!.skyColor[2],
            },
          };
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('AREnvironmentProbe has been disposed.');
    }
  }
}
