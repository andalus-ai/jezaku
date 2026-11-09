import 'dart:async';

import '../ar_anchor.dart';
import '../ar_controller.dart';
import '../ar_hit_test.dart';
import '../ar_plane.dart';
import '../models/ar_pose.dart';

// ─── Cloud anchor states ──────────────────────────────────────────────────────

enum ARCloudAnchorState {
  none,

  /// Actively uploading mapping data to Google Cloud Anchors / ARKit backend.
  hosting,

  /// Anchor has been hosted; [cloudId] is available.
  hosted,

  /// Resolving a cloud anchor from a shared [cloudId].
  resolving,

  /// Resolution succeeded; the anchor is tracking.
  resolved,

  /// An error occurred during hosting or resolving.
  error,
}

// ─── Cloud anchor ─────────────────────────────────────────────────────────────

class ARCloudAnchor {
  ARCloudAnchor({
    required this.localId,
    this.cloudId,
    this.state = ARCloudAnchorState.none,
  });

  /// The local ARCore/ARKit anchor ID.
  final String localId;

  /// The cloud-hosted anchor ID (assigned after hosting succeeds).
  String? cloudId;

  ARCloudAnchorState state;
  String? errorMessage;

  /// UTC expiry time (set when [ttlDays] > 0 during hosting).
  DateTime? expiresAt;

  ARAnchor? resolvedAnchor;
}

// ─── Cloud anchor manager ─────────────────────────────────────────────────────

/// Hosts and resolves Google Cloud Anchors (ARCore) and ARKit collaborative
/// sessions, enabling persistent AR content shared across devices.
///
/// **Requirements:**
/// - Android: `cloudAnchorsEnabled: true` in [ARSessionConfig]; Google Maps
///   API key in `AndroidManifest.xml` meta-data.
/// - iOS: ARKit collaborative sessions or Cloud Anchors via plugin bridge.
/// - Network connectivity during hosting / resolving.
///
/// **Typical flow:**
/// 1. User taps a surface → hit-test → call [hostAnchor].
/// 2. Store [ARCloudAnchor.cloudId] in your backend.
/// 3. Second device calls [resolveAnchor] with the cloud ID.
/// 4. Attach nodes to [ARCloudAnchor.resolvedAnchor].
class ARCloudAnchorManager {
  ARCloudAnchorManager(
    this._controller, {
    this.hostingDelay = const Duration(seconds: 3),
    this.resolutionDelay = const Duration(seconds: 4),
  });

  final ARController _controller;

  /// Simulated hosting delay for the Dart fallback path.
  final Duration hostingDelay;

  /// Simulated resolving delay for the Dart fallback path.
  final Duration resolutionDelay;

  final _cloudAnchors = <String, ARCloudAnchor>{};
  final _operationTokens = <String, int>{};
  final _hostedCtrl = StreamController<ARCloudAnchor>.broadcast();
  final _resolvedCtrl = StreamController<ARCloudAnchor>.broadcast();
  final _errorCtrl = StreamController<ARCloudAnchor>.broadcast();
  Future<void>? _disposeFuture;
  int _nextToken = 0;
  int _nextResolveId = 0;
  bool _disposed = false;

  /// Whether this manager has released its streams and pending operations.
  bool get isDisposed => _disposed;

  /// Fires when an anchor finishes hosting and [ARCloudAnchor.cloudId] is set.
  Stream<ARCloudAnchor> get onHosted {
    _ensureActive();
    return _hostedCtrl.stream;
  }

  /// Fires when a cloud anchor is successfully resolved.
  Stream<ARCloudAnchor> get onResolved {
    _ensureActive();
    return _resolvedCtrl.stream;
  }

  /// Fires when hosting or resolving fails.
  Stream<ARCloudAnchor> get onError {
    _ensureActive();
    return _errorCtrl.stream;
  }

  List<ARCloudAnchor> get allCloudAnchors {
    _ensureActive();
    return List.unmodifiable(_cloudAnchors.values);
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _operationTokens.clear();
    _cloudAnchors.clear();
    if (!_hostedCtrl.isClosed) await _hostedCtrl.close();
    if (!_resolvedCtrl.isClosed) await _resolvedCtrl.close();
    if (!_errorCtrl.isClosed) await _errorCtrl.close();
  }

  // ── Hosting ───────────────────────────────────────────────────────────────

  /// Begin hosting a local anchor at [hitResult].
  ///
  /// The anchor will be uploaded to Google Cloud Anchors. Mapping data
  /// quality improves as the user moves the device around the anchor.
  ///
  /// [ttlDays]: days the cloud anchor remains valid (max 365; 0 = no expiry).
  Future<ARCloudAnchor> hostAnchor({
    required ARHitTestResult hitResult,
    int ttlDays = 30,
  }) async {
    _ensureActive();
    if (ttlDays < 0 || ttlDays > 365) {
      throw RangeError.range(ttlDays, 0, 365, 'ttlDays');
    }

    final localAnchor = await _controller.addAnchor(hitResult);
    try {
      _ensureActive();
    } on StateError {
      await _removeAnchor(localAnchor.id);
      rethrow;
    }
    final cloudAnchor = ARCloudAnchor(
      localId: localAnchor.id,
      state: ARCloudAnchorState.hosting,
    );
    _cloudAnchors[localAnchor.id] = cloudAnchor;
    final token = _startOperation(localAnchor.id);

    unawaited(_hostNativeOrFallback(
      cloudAnchor,
      ttlDays: ttlDays,
      token: token,
    ));
    return cloudAnchor;
  }

  Future<void> _hostNativeOrFallback(
    ARCloudAnchor ca, {
    required int ttlDays,
    required int token,
  }) async {
    try {
      final cloudId = await _controller.hostCloudAnchor(
        ca.localId,
        ttlDays: ttlDays,
      );
      if (!_isActiveOperation(ca.localId, token) ||
          ca.state != ARCloudAnchorState.hosting) {
        return;
      }
      if (cloudId != null && cloudId.isNotEmpty) {
        _completeHosting(ca, cloudId: cloudId, ttlDays: ttlDays);
        return;
      }
      await _pollHostingFallback(ca, ttlDays: ttlDays, token: token);
    } on Object catch (error) {
      _completeError(ca, token: token, error: error);
    }
  }

  Future<void> _pollHostingFallback(
    ARCloudAnchor ca, {
    required int ttlDays,
    required int token,
  }) async {
    await Future<void>.delayed(hostingDelay);
    if (!_isActiveOperation(ca.localId, token) ||
        ca.state != ARCloudAnchorState.hosting) {
      return;
    }
    _completeHosting(
      ca,
      cloudId: 'cloud_${ca.localId}_${DateTime.now().millisecondsSinceEpoch}',
      ttlDays: ttlDays,
    );
  }

  void _completeHosting(
    ARCloudAnchor ca, {
    required String cloudId,
    required int ttlDays,
  }) {
    ca.cloudId = cloudId;
    ca.state = ARCloudAnchorState.hosted;
    ca.expiresAt =
        ttlDays > 0 ? DateTime.now().add(Duration(days: ttlDays)) : null;

    _operationTokens.remove(ca.localId);
    if (!_disposed && !_hostedCtrl.isClosed) _hostedCtrl.add(ca);
  }

  // ── Resolving ─────────────────────────────────────────────────────────────

  /// Resolve a previously hosted anchor by its [cloudId].
  Future<ARCloudAnchor> resolveAnchor(String cloudId) async {
    _ensureActive();
    if (cloudId.trim().isEmpty) {
      throw ArgumentError.value(cloudId, 'cloudId', 'Must not be empty.');
    }

    final ca = ARCloudAnchor(
      localId: 'local_resolve_${_nextResolveId++}',
      cloudId: cloudId,
      state: ARCloudAnchorState.resolving,
    );
    _cloudAnchors[ca.localId] = ca;
    final token = _startOperation(ca.localId);

    unawaited(_resolveNativeOrFallback(ca, token: token));
    return ca;
  }

  Future<void> _resolveNativeOrFallback(
    ARCloudAnchor ca, {
    required int token,
  }) async {
    try {
      final nativeAnchor = await _controller.resolveCloudAnchor(ca.cloudId!);
      if (!_isActiveOperation(ca.localId, token) ||
          ca.state != ARCloudAnchorState.resolving) {
        return;
      }
      if (nativeAnchor != null) {
        _completeResolution(ca, nativeAnchor);
        return;
      }
      await _pollResolutionFallback(ca, token: token);
    } on Object catch (error) {
      _completeError(ca, token: token, error: error);
    }
  }

  Future<void> _pollResolutionFallback(
    ARCloudAnchor ca, {
    required int token,
  }) async {
    await Future<void>.delayed(resolutionDelay);
    if (!_isActiveOperation(ca.localId, token) ||
        ca.state != ARCloudAnchorState.resolving) {
      return;
    }
    _completeResolution(
      ca,
      ARAnchor(
        id: ca.localId,
        pose: const ARPose.identity(),
        trackingState: ARTrackingState.tracking,
      ),
    );
  }

  void _completeResolution(ARCloudAnchor ca, ARAnchor resolved) {
    ca.resolvedAnchor = resolved;
    ca.state = ARCloudAnchorState.resolved;
    _operationTokens.remove(ca.localId);
    if (!_disposed && !_resolvedCtrl.isClosed) _resolvedCtrl.add(ca);
  }

  void _completeError(
    ARCloudAnchor ca, {
    required int token,
    required Object error,
  }) {
    if (!_isActiveOperation(ca.localId, token)) return;
    ca.state = ARCloudAnchorState.error;
    ca.errorMessage = error.toString();
    _operationTokens.remove(ca.localId);
    if (!_disposed && !_errorCtrl.isClosed) _errorCtrl.add(ca);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> cancelHosting(String localId) async {
    _ensureActive();
    final ca = _cloudAnchors[localId];
    if (ca == null) return;
    if (ca.state == ARCloudAnchorState.hosting) {
      _operationTokens.remove(localId);
      ca.state = ARCloudAnchorState.none;
      await _removeAnchor(localId);
    }
  }

  Future<void> removeCloudAnchor(String localId) async {
    _ensureActive();
    final ca = _cloudAnchors.remove(localId);
    if (ca == null) return;
    _operationTokens.remove(localId);
    await _removeAnchor(localId);
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  /// Serialise all successfully hosted cloud IDs for storage in your backend.
  List<Map<String, dynamic>> exportHostedIds() {
    _ensureActive();
    return _cloudAnchors.values
        .where(
          (ca) => ca.state == ARCloudAnchorState.hosted && ca.cloudId != null,
        )
        .map(
          (ca) => {
            'cloudId': ca.cloudId,
            'localId': ca.localId,
            'expiresAt': ca.expiresAt?.toIso8601String(),
          },
        )
        .toList();
  }

  int _startOperation(String localId) {
    final token = _nextToken++;
    _operationTokens[localId] = token;
    return token;
  }

  bool _isActiveOperation(String localId, int token) =>
      !_disposed && _operationTokens[localId] == token;

  Future<void> _removeAnchor(String localId) async {
    try {
      await _controller.removeAnchor(localId);
    } on StateError {
      // The controller may already be disposed during teardown.
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARCloudAnchorManager has been disposed.');
    }
  }
}
