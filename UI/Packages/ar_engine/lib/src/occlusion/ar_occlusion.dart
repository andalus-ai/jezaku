import 'dart:async';

import '../ar_camera.dart';
import '../ar_controller.dart';
import '../ar_session_config.dart';

// ─── Occlusion mode ───────────────────────────────────────────────────────────

/// Controls how AR objects interact with the real-world depth map.
enum AROcclusionMode {
  /// No occlusion — AR objects always render on top.
  disabled,

  /// Full environment occlusion using depth estimation.
  /// Requires ARCore Depth API or ARKit LiDAR.
  environmentDepth,

  /// Human-body occlusion (people occlude AR objects).
  /// ARKit: ARBodyTrackingConfiguration; ARCore: depth segmentation.
  humanOcclusion,

  /// Both environment and human occlusion combined.
  combined,
}

/// Confidence level of the depth estimate at a pixel.
enum ARDepthConfidence { low, medium, high }

// ─── Occlusion manager ────────────────────────────────────────────────────────

/// Manages real-world occlusion of AR content.
///
/// On **iOS** (LiDAR iPad/iPhone): uses `ARWorldTrackingConfiguration.frameSemantics`
/// with `.sceneDepth` + `.smoothedSceneDepth` for environment and
/// `.personSegmentationWithDepth` for human occlusion.
///
/// On **Android**: uses ARCore Depth API (`Config.DepthMode.AUTOMATIC`) for
/// environment and the People Segmentation API for human occlusion.
///
/// On **Web / Desktop**: provides a graceful fallback — occlusion is
/// approximated via the depth buffer written during plane/mesh rendering.
class AROcclusionManager {
  AROcclusionManager(this._controller);

  final ARController _controller;

  AROcclusionMode _mode = AROcclusionMode.disabled;
  bool _enabled = false;
  bool _disposed = false;
  int _lifecycleEpoch = 0;
  Future<void>? _disposeFuture;

  final _subs = <StreamSubscription<dynamic>>[];
  final _modeCtrl = StreamController<AROcclusionMode>.broadcast();
  final _depthCtrl = StreamController<ARDepthFrame>.broadcast();

  /// Fires when the occlusion mode changes.
  Stream<AROcclusionMode> get onModeChanged {
    _ensureActive();
    return _modeCtrl.stream;
  }

  /// Fires each frame with depth map metadata (when depth is available).
  Stream<ARDepthFrame> get onDepthFrame {
    _ensureActive();
    return _depthCtrl.stream;
  }

  AROcclusionMode get currentMode {
    _ensureActive();
    return _mode;
  }

  bool get isEnabled {
    _ensureActive();
    return _enabled;
  }

  bool get isDisposed => _disposed;

  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _disposed = true;
    _lifecycleEpoch += 1;
    return _disposeFuture = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    await _cancelDepthSubscriptions();
    _enabled = false;
    _mode = AROcclusionMode.disabled;
    if (!_modeCtrl.isClosed) await _modeCtrl.close();
    if (!_depthCtrl.isClosed) await _depthCtrl.close();
  }

  // ── Mode control ──────────────────────────────────────────────────────────

  /// Enable occlusion with the specified [mode].
  ///
  /// Reconfigures the underlying AR session to activate the required
  /// depth / segmentation capabilities.
  ///
  /// Pass [baseConfig] when occlusion should preserve an app's current
  /// plane detection, lighting, image target, body tracking, or frame-rate
  /// settings.
  Future<void> enable(
    AROcclusionMode mode, {
    ARSessionConfig? baseConfig,
  }) async {
    _ensureActive();
    final willEnable = mode != AROcclusionMode.disabled;
    if (_mode == mode && _enabled == willEnable && baseConfig == null) return;

    final epoch = ++_lifecycleEpoch;
    final previousMode = _mode;
    final wasEnabled = _enabled;

    try {
      await _controller.reconfigure(
        _buildConfig(mode, baseConfig: baseConfig),
      );
    } catch (_) {
      if (epoch == _lifecycleEpoch) {
        _mode = previousMode;
        _enabled = wasEnabled;
      }
      rethrow;
    }

    if (_disposed || epoch != _lifecycleEpoch) return;
    _mode = mode;
    _enabled = willEnable;
    _emitMode(mode);
    await _subscribeDepth(epoch);
  }

  Future<void> disable({ARSessionConfig? baseConfig}) => enable(
        AROcclusionMode.disabled,
        baseConfig: baseConfig,
      );

  Future<void> toggle({ARSessionConfig? baseConfig}) {
    _ensureActive();
    return _enabled
        ? disable(baseConfig: baseConfig)
        : enable(
            AROcclusionMode.environmentDepth,
            baseConfig: baseConfig,
          );
  }

  ARSessionConfig _buildConfig(
    AROcclusionMode mode, {
    ARSessionConfig? baseConfig,
  }) =>
      (baseConfig ?? const ARSessionConfig()).copyWith(
        occlusionEnabled: mode != AROcclusionMode.disabled,
        depthEnabled: _modeRequiresSceneDepth(mode),
      );

  bool _modeRequiresSceneDepth(AROcclusionMode mode) =>
      mode == AROcclusionMode.environmentDepth ||
      mode == AROcclusionMode.combined;

  // ── Depth frame subscription ──────────────────────────────────────────────

  Future<void> _subscribeDepth(int epoch) async {
    await _cancelDepthSubscriptions();

    if (_disposed || !_enabled || epoch != _lifecycleEpoch) return;

    _subs.add(
      _controller.onCameraUpdate.listen((frame) {
        if (_disposed ||
            !_enabled ||
            epoch != _lifecycleEpoch ||
            _depthCtrl.isClosed) {
          return;
        }
        // Depth data is embedded in the camera frame's metadata on native.
        // Here we emit a lightweight frame descriptor; pixel data is accessed
        // natively by the renderer to avoid copying millions of bytes to Dart.
        _depthCtrl.add(
          ARDepthFrame(
            width: frame.imageResolution[0],
            height: frame.imageResolution[1],
            confidence: ARDepthConfidence.medium,
            timestamp: DateTime.now(),
            cameraFrame: frame,
          ),
        );
      }),
    );
  }

  Future<void> _cancelDepthSubscriptions() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  // ── Depth queries ─────────────────────────────────────────────────────────

  /// Check whether the current device supports LiDAR-based depth.
  Future<bool> supportsSceneDepth() async {
    _ensureActive();
    final capabilities = await _controller.capabilities;
    return capabilities.supportsSceneDepth;
  }

  /// Sample depth at normalised screen coordinates [x, y] ∈ [0, 1].
  /// Returns `null` if depth is unavailable.
  Future<double?> sampleDepth(double x, double y) async {
    _ensureActive();
    return _controller.sampleDepth(x, y);
  }

  void _emitMode(AROcclusionMode mode) {
    if (!_disposed && !_modeCtrl.isClosed) _modeCtrl.add(mode);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('AROcclusionManager has been disposed.');
    }
  }
}

// ─── Depth frame descriptor ───────────────────────────────────────────────────

class ARDepthFrame {
  const ARDepthFrame({
    required this.width,
    required this.height,
    required this.confidence,
    required this.timestamp,
    required this.cameraFrame,
  });

  final int width;
  final int height;
  final ARDepthConfidence confidence;
  final DateTime timestamp;
  final ARCamera cameraFrame;

  /// Total pixels in the depth map.
  int get pixelCount => width * height;
}
