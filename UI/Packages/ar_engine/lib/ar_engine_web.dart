import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/ar_anchor.dart';
import 'src/ar_camera.dart';
import 'src/ar_capabilities.dart';
import 'src/ar_controller.dart';
import 'src/ar_hit_test.dart';
import 'src/ar_node.dart';
import 'src/ar_plane.dart';
import 'src/ar_runtime_diagnostics.dart';
import 'src/ar_session_config.dart';
import 'src/models/ar_matrix4.dart';
import 'src/models/ar_pose.dart';
import 'src/models/ar_quaternion.dart';
import 'src/models/ar_vector3.dart';
import 'src/platform/ar_platform_interface.dart';

const String _arViewType = 'com.arengine/ar_view';

web.HTMLCanvasElement? _sharedCanvas;
bool _viewFactoryRegistered = false;

Object? getProperty(Object? object, String property) {
  if (object is Map) return object[property];
  return _readJsValue(_asJsObject(object).getProperty<JSAny?>(property.toJS));
}

void setProperty(Object? object, String property, Object? value) {
  _asJsObject(object).setProperty(property.toJS, _toJsValue(value));
}

Object? callMethod(Object? object, String method, List<Object?> arguments) =>
    _readJsValue(
      _asJsObject(object).callMethodVarArgs<JSAny?>(
        method.toJS,
        _toJsArguments(arguments),
      ),
    );

Object? callConstructor(Object? constructor, List<Object?> arguments) =>
    (constructor as JSFunction).callAsConstructorVarArgs<JSObject>(
      _toJsArguments(arguments),
    );

Future<T> promiseToFuture<T>(Object? promise) async {
  final value = await (promise as JSPromise<JSAny?>).toDart;
  return _readJsValue(value) as T;
}

JSExportedDartFunction _allowInteropFrame(
  void Function(JSAny?, JSAny?) function,
) =>
    function.toJS;

JSExportedDartFunction _allowInteropForEach(
  void Function(JSAny?, JSAny?, JSAny?) function,
) =>
    function.toJS;

JSExportedDartFunction _allowInteropValue(
  void Function(JSAny?) function,
) =>
    function.toJS;

JSAny? jsify(Object? object) => _toJsValue(object);

JSAny? _toJsValue(Object? object) => object.jsify();

List<JSAny?> _toJsArguments(List<Object?> arguments) =>
    arguments.map<JSAny?>(_toJsValue).toList();

JSObject _asJsObject(Object? object) {
  if (object != null) return JSObject.fromInteropObject(object);
  throw ArgumentError.value(object, 'object', 'Expected a JavaScript object');
}

Object? _readJsValue(JSAny? value) {
  if (value == null) return null;
  if (value.isA<JSArray<JSAny?>>()) {
    return (value as JSArray<JSAny?>).toDart.map(_readJsValue).toList();
  }
  if (value.isA<JSString>() ||
      value.isA<JSNumber>() ||
      value.isA<JSBoolean>() ||
      value.isA<JSArrayBuffer>() ||
      value.isA<JSTypedArray>()) {
    return value.dartify();
  }
  return value;
}

web.HTMLCanvasElement _ensureCanvas() =>
    _sharedCanvas ??= web.HTMLCanvasElement()
      ..id = 'ar-engine-canvas'
      ..style.cssText =
          'position:absolute;top:0;left:0;width:100%;height:100%;';

Uint8List _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma == -1) return Uint8List(0);

  final metadata = dataUrl.substring(0, comma).toLowerCase();
  final payload = dataUrl.substring(comma + 1);
  if (metadata.contains(';base64')) {
    return base64Decode(payload);
  }
  return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
}

/// Tracks web renderer runtime state and publishes a JSON-friendly snapshot.
///
/// Apps and browser tooling can read `window.__arEngineWebDiagnostics` to
/// inspect Three.js availability, model loader outcomes, fallback usage, and
/// texture cache behavior without depending on a Flutter method channel.
class _WebRuntimeDiagnostics {
  _WebRuntimeDiagnostics() {
    reset();
  }

  final _values = <String, Object?>{};

  Map<String, Object?> get snapshot =>
      Map<String, Object?>.unmodifiable(_values);

  void reset({bool sessionActive = false}) {
    _values
      ..clear()
      ..addAll(<String, Object?>{
        'source': 'web',
        'sessionActive': sessionActive,
        'sessionReconfigured': 0,
        'threeAvailable': false,
        'gltfLoaderAvailable': false,
        'objLoaderAvailable': false,
        'textureLoaderAvailable': false,
        'nodesAdded': 0,
        'nodesUpdated': 0,
        'nodesRemoved': 0,
        'nodesRendered': 0,
        'nodesSkippedMissingThree': 0,
        'modelLoadStarted': 0,
        'modelLoadSucceeded': 0,
        'modelLoadFailed': 0,
        'modelFallbackUsed': 0,
        'modelCacheHits': 0,
        'modelCacheSize': 0,
        'modelStaleCallbacksIgnored': 0,
        'textureLoadStarted': 0,
        'textureLoadSucceeded': 0,
        'textureLoadFailed': 0,
        'textureBytesMissing': 0,
        'textureCacheHits': 0,
        'textureCacheSize': 0,
        'lastNodeStatus': null,
        'lastModelNodeId': null,
        'lastModelUrl': null,
        'lastModelStatus': null,
        'lastModelError': null,
      });
    _touch();
    _publish();
  }

  void increment(String key, [int delta = 1]) {
    _values[key] = ((_values[key] as int?) ?? 0) + delta;
    _touch();
    _publish();
  }

  void setSessionActive(bool isActive) {
    setValue('sessionActive', isActive);
  }

  void setValue(String key, Object? value) {
    _values[key] = value;
    _touch();
    _publish();
  }

  void setValues(Map<String, Object?> values) {
    _values.addAll(values);
    _touch();
    _publish();
  }

  void recordThreeAvailability(Object? three) {
    setValues(<String, Object?>{
      'threeAvailable': three != null,
      'gltfLoaderAvailable': _hasConstructor(three, 'GLTFLoader'),
      'objLoaderAvailable': _hasConstructor(three, 'OBJLoader'),
      'textureLoaderAvailable': _hasConstructor(three, 'TextureLoader'),
    });
  }

  void _touch() {
    _values['lastUpdatedAt'] = DateTime.now().toUtc().toIso8601String();
  }

  void _publish() {
    setProperty(
      web.window,
      '__arEngineWebDiagnostics',
      Map<String, Object?>.from(_values),
    );
  }

  bool _hasConstructor(Object? three, String constructorName) {
    if (three == null) return false;
    return getProperty(three, constructorName) != null ||
        getProperty(web.window, constructorName) != null;
  }
}

// ─── Web plugin ───────────────────────────────────────────────────────────────

/// WebXR Device API implementation (immersive-ar + hit-test + light-estimation).
///
/// Falls back gracefully when optional features are unavailable.
class ArEngineWebPlugin extends ArEnginePlatform {
  static void registerWith(Registrar registrar) {
    if (!_viewFactoryRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _arViewType,
        (int viewId, {Object? params}) => _ensureCanvas(),
      );
      _viewFactoryRegistered = true;
    }
    ArEnginePlatform.instance = ArEngineWebPlugin();
  }

  // ── State ─────────────────────────────────────────────────────────────────

  Object? _xrSession;
  Object? _xrRefSpace;
  Object? _gl;
  web.HTMLCanvasElement? _canvas;
  late final web.EventListener _visibilityListener = _onVisibility.toJS;
  int _sessionEpoch = 0;

  // Hit-test source created once per session.
  Object? _hitTestSource;
  // Pending hit-test results buffered from the last XR frame.
  List<Map<String, Object?>> _pendingHits = <Map<String, Object?>>[];

  // Node & anchor registries.
  final _anchors = <String, ARPose>{};
  final _nodes = <String, ARNode>{};
  final _nodeAnchorIds = <String, String?>{};
  final _nodeRenderEpochs = <String, int>{};
  final _threeModelCache = <String, Object?>{};
  final _threeTextureCache = <String, Object?>{};
  final _webDiagnostics = _WebRuntimeDiagnostics();
  int _nextNodeRenderEpoch = 0;

  // Stream controllers.
  final _camCtrl = StreamController<ARCamera>.broadcast();
  final _plnCtrl = StreamController<List<ARPlane>>.broadcast();
  final _ancrCtrl = StreamController<ARAnchor>.broadcast();
  final _lgtCtrl = StreamController<double>.broadcast();

  @override
  Stream<ARCamera> get cameraStream => _camCtrl.stream;
  @override
  Stream<List<ARPlane>> get planeStream => _plnCtrl.stream;
  @override
  Stream<ARAnchor> get anchorStream => _ancrCtrl.stream;
  @override
  Stream<double> get lightIntensityStream => _lgtCtrl.stream;

  // ── Support check ─────────────────────────────────────────────────────────

  @override
  Future<bool> isARSupported() async {
    final xr = getProperty(web.window.navigator, 'xr');
    if (xr == null) return false;
    try {
      return await promiseToFuture<bool>(
        callMethod(xr, 'isSessionSupported', <Object?>['immersive-ar']),
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<ARCapabilities> getCapabilities() async {
    final supported = await isARSupported();
    return ARCapabilities(
      isARSupported: supported,
      supportsWorldTracking: supported,
      supportsPlaneDetection: supported,
      supportsHitTesting: supported,
      supportsLightEstimation: supported,
      supportsSnapshotCapture: supported,
    );
  }

  @override
  Future<ARRuntimeDiagnostics> getRuntimeDiagnostics() async =>
      ARRuntimeDiagnostics.fromMap(
        _webDiagnostics.snapshot,
        source: 'web',
      );

  // ── Session init ──────────────────────────────────────────────────────────

  @override
  Future<void> initSession(ARSessionConfig config) async {
    _webDiagnostics.reset();
    await _startXRSession(config);
    _webDiagnostics.setSessionActive(true);
  }

  @override
  Future<void> reconfigureSession(ARSessionConfig config) async {
    // WebXR does not support in-place reconfiguration; restart the session.
    _webDiagnostics.increment('sessionReconfigured');
    await _endXRSession();
    await _startXRSession(config);
    _webDiagnostics.setSessionActive(true);
  }

  Future<void> _startXRSession(ARSessionConfig config) async {
    // Create a WebGL2 canvas if needed.
    _canvas ??= _ensureCanvas();

    _gl = _canvas!.getContext(
      'webgl2',
      jsify(<String, Object?>{
        'xrCompatible': true,
        'alpha': true,
        'antialias': true,
        'depth': true,
      }),
    );
    if (_gl == null) throw Exception('WebGL2 not available in this browser.');

    final xr = getProperty(web.window.navigator, 'xr');

    // Build requiredFeatures / optionalFeatures from config.
    final required = <String>['hit-test', 'local-floor'];
    final optional = <String>['dom-overlay', 'light-estimation', 'anchors'];
    if (config.detectHorizontalPlanes || config.detectVerticalPlanes) {
      optional.add('plane-detection');
    }

    final session = await promiseToFuture<Object?>(
      callMethod(xr, 'requestSession', <Object?>[
        'immersive-ar',
        jsify(<String, Object?>{
          'requiredFeatures': required,
          'optionalFeatures': optional,
        }),
      ]),
    );
    _xrSession = session;
    final epoch = ++_sessionEpoch;

    await promiseToFuture<Object?>(
      callMethod(_gl, 'makeXRCompatible', <Object?>[]),
    );

    final xrLayer = callConstructor(
      getProperty(web.window, 'XRWebGLLayer'),
      <Object?>[session, _gl],
    );
    callMethod(session, 'updateRenderState', <Object?>[
      jsify(<String, Object?>{'baseLayer': xrLayer}),
    ]);

    _xrRefSpace = await promiseToFuture<Object?>(
      callMethod(
        session,
        'requestReferenceSpace',
        <Object?>['local-floor'],
      ),
    );

    // Request a persistent hit-test source (ViewerSpace).
    try {
      final viewerSpace = await promiseToFuture<Object?>(
        callMethod(session, 'requestReferenceSpace', <Object?>['viewer']),
      );
      _hitTestSource = await promiseToFuture<Object?>(
        callMethod(session, 'requestHitTestSource', <Object?>[
          jsify(<String, Object?>{'space': viewerSpace}),
        ]),
      );
    } on Object {
      _hitTestSource =
          null; // hit-test not available; fallback to plane intersection
    }

    _startRenderLoop(session, epoch);
  }

  // ── Render loop ───────────────────────────────────────────────────────────

  void _startRenderLoop(Object? session, int epoch) {
    void frame(JSAny? _, JSAny? xrFrame) {
      if (!identical(_xrSession, session) || _sessionEpoch != epoch) return;
      _processXRFrame(xrFrame);
      callMethod(session, 'requestAnimationFrame', <Object?>[
        _allowInteropFrame(frame),
      ]);
    }

    callMethod(session, 'requestAnimationFrame', <Object?>[
      _allowInteropFrame(frame),
    ]);
  }

  void _processXRFrame(Object? xrFrame) {
    // ── Camera pose ─────────────────────────────────────────────────────────
    final viewerPose = callMethod(
      xrFrame,
      'getViewerPose',
      <Object?>[_xrRefSpace],
    );
    if (viewerPose == null) return;

    final views = getProperty(viewerPose, 'views') as List<Object?>?;
    if (views == null || views.isEmpty) return;

    final view = views.first;
    final transform = getProperty(view, 'transform');
    final projMatrix = getProperty(view, 'projectionMatrix') as List<Object?>;
    final matrix = getProperty(transform, 'matrix') as List<Object?>;

    final position = ARVector3(
      (matrix[12] as num).toDouble(),
      (matrix[13] as num).toDouble(),
      (matrix[14] as num).toDouble(),
    );
    final rotation = _quatFromMatrix(matrix);
    final projList = projMatrix.map((e) => (e as num).toDouble()).toList();
    final matList = matrix.map((e) => (e as num).toDouble()).toList();

    _camCtrl.add(
      ARCamera(
        pose: ARPose(position: position, rotation: rotation),
        projectionMatrix: ARMatrix4(projList),
        viewMatrix: ARMatrix4(matList),
        trackingState: ARTrackingState.tracking,
        intrinsics: [projList[0], projList[5], projList[8], projList[9]],
        imageResolution: [_canvas?.width ?? 1280, _canvas?.height ?? 720],
      ),
    );

    // ── Hit-test results (buffered for next hitTest() call) ─────────────────
    if (_hitTestSource != null) {
      try {
        final hits = callMethod(
          xrFrame,
          'getHitTestResults',
          <Object?>[_hitTestSource],
        );
        if (hits != null) {
          _pendingHits = [];
          callMethod(hits, 'forEach', <Object?>[
            _allowInteropForEach((
              JSAny? hit,
              JSAny? _,
              JSAny? __,
            ) {
              final hitPose = callMethod(
                hit,
                'getPose',
                <Object?>[_xrRefSpace],
              );
              if (hitPose == null) return;
              final m = getProperty(
                getProperty(hitPose, 'transform'),
                'matrix',
              ) as List<Object?>;
              _pendingHits.add(<String, Object?>{
                'type': 'estimatedHorizontalPlane',
                'worldPose': ARPose(
                  position: ARVector3(
                    (m[12] as num).toDouble(),
                    (m[13] as num).toDouble(),
                    (m[14] as num).toDouble(),
                  ),
                  rotation: _quatFromMatrix(m),
                ),
                'distance': _dist(m, matrix),
                'planeId': '',
                'anchorId': '',
              });
            }),
          ]);
        }
      } on Object {
        // Hit-test results are optional and can disappear between XR frames.
      }
    }

    // ── Plane detection (optional feature) ──────────────────────────────────
    _processDetectedPlanes(xrFrame);

    // ── Light estimation (optional feature) ─────────────────────────────────
    _processLightProbe(xrFrame);
  }

  double _dist(List<Object?> hitMatrix, List<Object?> camMatrix) {
    final dx = (hitMatrix[12] as num) - (camMatrix[12] as num);
    final dy = (hitMatrix[13] as num) - (camMatrix[13] as num);
    final dz = (hitMatrix[14] as num) - (camMatrix[14] as num);
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  ARQuaternion _quatFromMatrix(List<Object?> m) {
    final m00 = (m[0] as num).toDouble();
    final m11 = (m[5] as num).toDouble();
    final m22 = (m[10] as num).toDouble();
    final trace = m00 + m11 + m22;
    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1.0);
      return ARQuaternion(
        ((m[6] as num).toDouble() - (m[9] as num).toDouble()) * s,
        ((m[8] as num).toDouble() - (m[2] as num).toDouble()) * s,
        ((m[1] as num).toDouble() - (m[4] as num).toDouble()) * s,
        0.25 / s,
      );
    }
    if (m00 > m11 && m00 > m22) {
      final s = 2.0 * math.sqrt(1.0 + m00 - m11 - m22);
      return ARQuaternion(
        0.25 * s,
        ((m[4] as num).toDouble() + (m[1] as num).toDouble()) / s,
        ((m[8] as num).toDouble() + (m[2] as num).toDouble()) / s,
        ((m[6] as num).toDouble() - (m[9] as num).toDouble()) / s,
      );
    }
    if (m11 > m22) {
      final s = 2.0 * math.sqrt(1.0 + m11 - m00 - m22);
      return ARQuaternion(
        ((m[4] as num).toDouble() + (m[1] as num).toDouble()) / s,
        0.25 * s,
        ((m[9] as num).toDouble() + (m[6] as num).toDouble()) / s,
        ((m[8] as num).toDouble() - (m[2] as num).toDouble()) / s,
      );
    }
    final s = 2.0 * math.sqrt(1.0 + m22 - m00 - m11);
    return ARQuaternion(
      ((m[8] as num).toDouble() + (m[2] as num).toDouble()) / s,
      ((m[9] as num).toDouble() + (m[6] as num).toDouble()) / s,
      0.25 * s,
      ((m[1] as num).toDouble() - (m[4] as num).toDouble()) / s,
    );
  }

  void _processDetectedPlanes(Object? xrFrame) {
    final detected = getProperty(xrFrame, 'detectedPlanes');
    if (detected == null) return;
    final planes = <ARPlane>[];
    callMethod(detected, 'forEach', <Object?>[
      _allowInteropForEach((
        JSAny? plane,
        JSAny? _,
        JSAny? __,
      ) {
        final pp = callMethod(
          xrFrame,
          'getPose',
          <Object?>[getProperty(plane, 'planeSpace'), _xrRefSpace],
        );
        if (pp == null) return;
        final m = getProperty(
          getProperty(pp, 'transform'),
          'matrix',
        ) as List<Object?>;
        final pos = ARVector3(
          (m[12] as num).toDouble(),
          (m[13] as num).toDouble(),
          (m[14] as num).toDouble(),
        );
        final poly =
            getProperty(plane, 'polygon') as List<Object?>? ?? <Object?>[];
        final boundary = poly
            .map(
              (pt) => ARVector3(
                (getProperty(pt, 'x') as num? ?? 0).toDouble(),
                0,
                (getProperty(pt, 'z') as num? ?? 0).toDouble(),
              ),
            )
            .toList();
        final orient =
            getProperty(plane, 'orientation') as String? ?? 'horizontal';
        planes.add(
          ARPlane(
            id: identityHashCode(plane).toString(),
            alignment: orient == 'vertical'
                ? ARPlaneAlignment.vertical
                : ARPlaneAlignment.horizontal,
            centerPose: ARPose(
              position: pos,
              rotation: const ARQuaternion.identity(),
            ),
            extentMeters: const ARVector3(1, 0, 1),
            boundaryVertices: boundary,
            trackingState: ARTrackingState.tracking,
          ),
        );
      }),
    ]);
    if (planes.isNotEmpty) _plnCtrl.add(planes);
  }

  void _processLightProbe(Object? xrFrame) {
    final le = getProperty(xrFrame, 'lightEstimate');
    if (le == null) return;
    final intensity = getProperty(le, 'primaryLightIntensity') as num? ?? 1000;
    _lgtCtrl.add(intensity.toDouble());
  }

  // ── Hit testing ───────────────────────────────────────────────────────────

  @override
  Future<List<ARHitTestResult>> hitTest(double x, double y) async {
    // Return the last frame's buffered hit-test results.
    // They are already in world space from getHitTestResults().
    if (_pendingHits.isNotEmpty) {
      return _pendingHits
          .map(
            (h) => ARHitTestResult(
              type: ARHitTestResultType.estimatedHorizontalPlane,
              worldPose: h['worldPose'] as ARPose,
              distance: h['distance'] as double,
              planeId: h['planeId'] as String?,
              anchorId: h['anchorId'] as String?,
            ),
          )
          .toList();
    }
    // Fallback: unproject screen coords to ground plane y=0.
    return [_groundPlaneHit(x, y)];
  }

  ARHitTestResult _groundPlaneHit(double nx, double ny) {
    final worldX = (nx - 0.5) * 1.6;
    const worldY = 0.0;
    const worldZ = -1.0;
    return ARHitTestResult(
      type: ARHitTestResultType.estimatedHorizontalPlane,
      worldPose: ARPose(
        position: ARVector3(worldX, worldY, worldZ),
        rotation: const ARQuaternion.identity(),
      ),
      distance: 1.0,
    );
  }

  // ── Snapshot ──────────────────────────────────────────────────────────────

  @override
  Future<Uint8List?> captureSnapshot() async {
    final canvas = _canvas;
    if (canvas == null) return null;
    try {
      // Read WebGL framebuffer into a 2D canvas, then encode to JPEG bytes.
      final snap = web.HTMLCanvasElement()
        ..width = canvas.width
        ..height = canvas.height;
      final ctx = snap.context2D;
      ctx.drawImage(canvas, 0, 0, canvas.width, canvas.height);
      return _decodeDataUrl(snap.toDataUrl('image/jpeg', 0.85));
    } on Object {
      return null;
    }
  }

  // ── Session lifecycle ─────────────────────────────────────────────────────

  @override
  Future<void> pauseSession() async {
    // WebXR has no pause; handle via page visibility.
    web.document.addEventListener('visibilitychange', _visibilityListener);
  }

  void _onVisibility(web.Event _) {
    if (web.document.hidden) {
      // session is still running but we stop updating streams
    }
  }

  @override
  Future<void> resumeSession() async {
    web.document.removeEventListener('visibilitychange', _visibilityListener);
  }

  @override
  Future<void> destroySession() async {
    web.document.removeEventListener('visibilitychange', _visibilityListener);
    await _endXRSession();
    for (final nodeId in _nodes.keys.toList()) {
      _removeWebGLNode(nodeId);
    }
    _anchors.clear();
    _nodes.clear();
    _nodeAnchorIds.clear();
    _nodeRenderEpochs.clear();
    _threeModelCache.clear();
    _threeTextureCache.clear();
    _gl = null;
    _canvas = null;
    _webDiagnostics
      ..setValue('modelCacheSize', 0)
      ..setValue('textureCacheSize', 0)
      ..setSessionActive(false);
  }

  Future<void> _endXRSession() async {
    final session = _xrSession;
    _sessionEpoch += 1;
    _hitTestSource = null;
    _xrRefSpace = null;
    _pendingHits.clear();
    if (session != null) {
      try {
        await promiseToFuture<Object?>(
          callMethod(session, 'end', <Object?>[]),
        );
      } on Object {
        // The browser may have already ended the XR session.
      }
    }
    if (identical(_xrSession, session)) {
      _xrSession = null;
    }
  }

  // ── Anchors ───────────────────────────────────────────────────────────────

  @override
  Future<ARAnchor> addAnchor(ARHitTestResult hitResult) async =>
      _storeAnchor(hitResult.worldPose);

  @override
  Future<ARAnchor> addAnchorAtPose(ARPoseInput pose) async => _storeAnchor(
        ARPose(
          position: ARVector3(pose.x, pose.y, pose.z),
          rotation: ARQuaternion(pose.qx, pose.qy, pose.qz, pose.qw),
        ),
      );

  ARAnchor _storeAnchor(ARPose pose) {
    final id = 'anchor_${DateTime.now().microsecondsSinceEpoch}';
    _anchors[id] = pose;
    final anchor =
        ARAnchor(id: id, pose: pose, trackingState: ARTrackingState.tracking);
    _ancrCtrl.add(anchor);
    return anchor;
  }

  @override
  Future<void> removeAnchor(String anchorId) async {
    _anchors.remove(anchorId);
    final detachedNodes = _nodeAnchorIds.entries
        .where((entry) => entry.value == anchorId)
        .map((entry) => entry.key)
        .toList();
    for (final nodeId in detachedNodes) {
      _nodeAnchorIds.remove(nodeId);
      final node = _nodes[nodeId];
      if (node != null) {
        _rebuildWebGLNode(node);
      }
    }
    // Emit stopped event so controller cache cleans up.
    _ancrCtrl.add(
      ARAnchor(
        id: anchorId,
        pose: const ARPose.identity(),
        trackingState: ARTrackingState.stopped,
      ),
    );
  }

  // ── Nodes ─────────────────────────────────────────────────────────────────

  @override
  Future<String> addNode(ARNode node, {String? anchorId}) async {
    final resolvedAnchorId =
        anchorId ?? _metadataString(node.metadata['anchorId']);
    _nodes[node.id] = node;
    _nodeAnchorIds[node.id] = resolvedAnchorId;
    _webDiagnostics.increment('nodesAdded');
    _injectWebGLNode(node, anchorId: resolvedAnchorId);
    return node.id;
  }

  @override
  Future<void> updateNode(ARNode node) async {
    final resolvedAnchorId = node.metadata.containsKey('anchorId')
        ? _metadataString(node.metadata['anchorId'])
        : _nodeAnchorIds[node.id];
    _nodes[node.id] = node;
    _nodeAnchorIds[node.id] = resolvedAnchorId;
    _webDiagnostics.increment('nodesUpdated');
    _rebuildWebGLNode(node, anchorId: resolvedAnchorId);
  }

  @override
  Future<void> removeNode(String nodeId) async {
    _nodes.remove(nodeId);
    _nodeAnchorIds.remove(nodeId);
    _nodeRenderEpochs.remove(nodeId);
    _webDiagnostics.increment('nodesRemoved');
    _removeWebGLNode(nodeId);
  }

  // ── WebGL node rendering via inline Three.js (if available) ──────────────

  void _injectWebGLNode(ARNode node, {String? anchorId}) {
    final renderEpoch = _beginWebGLNodeRender(node.id);
    // Three.js is not bundled; we use a minimal WebGL draw call instead.
    // If window.THREE exists (loaded via CDN in index.html), use it.
    final three = getProperty(web.window, 'THREE');
    _webDiagnostics.recordThreeAvailability(three);
    if (three == null) {
      _webDiagnostics
        ..increment('nodesSkippedMissingThree')
        ..setValue('lastNodeStatus', 'skippedMissingThree');
      return;
    }

    final root = callConstructor(getProperty(three, 'Group'), <Object?>[]);
    setProperty(root, 'name', node.id);
    _applyThreeAnchorTransform(root, anchorId);

    final localNode = _buildThreeObject(
      three,
      node,
      name: '${node.id}_local',
      rootNodeId: node.id,
      renderEpoch: renderEpoch,
    );
    callMethod(root, 'add', <Object?>[localNode]);

    final scene = _getOrCreateThreeScene(three);
    callMethod(scene, 'add', <Object?>[root]);
    _webDiagnostics
      ..increment('nodesRendered')
      ..setValue('lastNodeStatus', 'rendered');
  }

  void _rebuildWebGLNode(ARNode node, {String? anchorId}) {
    _removeWebGLNode(node.id);
    _injectWebGLNode(node, anchorId: anchorId);
  }

  int _beginWebGLNodeRender(String nodeId) {
    final renderEpoch = ++_nextNodeRenderEpoch;
    _nodeRenderEpochs[nodeId] = renderEpoch;
    return renderEpoch;
  }

  bool _isCurrentWebGLNodeRender(String rootNodeId, int renderEpoch) =>
      _nodeRenderEpochs[rootNodeId] == renderEpoch &&
      _nodes.containsKey(rootNodeId);

  Object? _buildThreeObject(
    Object? three,
    ARNode node, {
    String? name,
    required String rootNodeId,
    required int renderEpoch,
  }) {
    final group = callConstructor(getProperty(three, 'Group'), <Object?>[]);
    setProperty(group, 'name', name ?? node.id);
    _applyThreeLocalTransform(group, node);
    _applyThreeNodeProperties(group, node);

    final mesh = _buildThreeMesh(three, node);
    if (mesh != null) {
      callMethod(group, 'add', <Object?>[mesh]);
    }

    if (node.isModelNode) {
      _loadThreeModelIntoGroup(
        three,
        group,
        node,
        rootNodeId: rootNodeId,
        renderEpoch: renderEpoch,
      );
    }

    for (final child in node.children) {
      final childObject = _buildThreeObject(
        three,
        child,
        rootNodeId: rootNodeId,
        renderEpoch: renderEpoch,
      );
      callMethod(group, 'add', <Object?>[childObject]);
    }

    return group;
  }

  void _loadThreeModelIntoGroup(
    Object? three,
    Object? group,
    ARNode node, {
    required String rootNodeId,
    required int renderEpoch,
  }) {
    final modelUrl = _modelUrlFor(node);
    final loaderConstructor = _modelLoaderConstructor(three, node);
    if (modelUrl == null || loaderConstructor == null) {
      _webDiagnostics
        ..increment('modelFallbackUsed')
        ..setValues(<String, Object?>{
          'lastModelNodeId': node.id,
          'lastModelUrl': modelUrl,
          'lastModelStatus':
              modelUrl == null ? 'fallbackMissingUrl' : 'fallbackMissingLoader',
          'lastModelError': null,
        });
      return;
    }

    final cacheKey = '${_modelFormatName(node)}:$modelUrl';
    final cachedModel = _threeModelCache[cacheKey];
    if (cachedModel != null) {
      _webDiagnostics
        ..increment('modelCacheHits')
        ..setValues(<String, Object?>{
          'lastModelNodeId': node.id,
          'lastModelUrl': modelUrl,
          'lastModelStatus': 'cacheHit',
          'lastModelError': null,
        });
      if (!_isCurrentWebGLNodeRender(rootNodeId, renderEpoch)) return;
      _attachThreeModel(group, cachedModel, node);
      return;
    }

    final loader = callConstructor(loaderConstructor, <Object?>[]);
    _webDiagnostics
      ..increment('modelLoadStarted')
      ..setValues(<String, Object?>{
        'lastModelNodeId': node.id,
        'lastModelUrl': modelUrl,
        'lastModelStatus': 'loading',
        'lastModelError': null,
      });
    callMethod(loader, 'load', <Object?>[
      modelUrl,
      _allowInteropValue((JSAny? loaded) {
        final model = _loadedThreeModelObject(loaded, node);
        if (model == null) {
          _webDiagnostics
            ..increment('modelLoadFailed')
            ..increment('modelFallbackUsed')
            ..setValues(<String, Object?>{
              'lastModelNodeId': node.id,
              'lastModelUrl': modelUrl,
              'lastModelStatus': 'fallbackInvalidModel',
              'lastModelError': 'Loader returned no model object.',
            });
          return;
        }
        _threeModelCache[cacheKey] = model;
        _webDiagnostics
          ..increment('modelLoadSucceeded')
          ..setValue('modelCacheSize', _threeModelCache.length);
        if (!_isCurrentWebGLNodeRender(rootNodeId, renderEpoch)) {
          _webDiagnostics
            ..increment('modelStaleCallbacksIgnored')
            ..setValues(<String, Object?>{
              'lastModelNodeId': node.id,
              'lastModelUrl': modelUrl,
              'lastModelStatus': 'staleLoadIgnored',
              'lastModelError': null,
            });
          return;
        }
        _webDiagnostics.setValues(<String, Object?>{
          'lastModelNodeId': node.id,
          'lastModelUrl': modelUrl,
          'lastModelStatus': 'loaded',
          'lastModelError': null,
        });
        _attachThreeModel(group, model, node);
      }),
      null,
      _allowInteropValue((JSAny? error) {
        // Keep the primitive fallback visible when a web model loader fails.
        _webDiagnostics
          ..increment('modelLoadFailed')
          ..increment('modelFallbackUsed')
          ..setValues(<String, Object?>{
            'lastModelNodeId': node.id,
            'lastModelUrl': modelUrl,
            'lastModelStatus': 'fallbackAfterLoadError',
            'lastModelError': _webDiagnosticErrorMessage(error),
          });
      }),
    ]);
  }

  void _attachThreeModel(Object? group, Object? modelTemplate, ARNode node) {
    final model = _cloneThreeObject(modelTemplate) ?? modelTemplate;
    if (model == null) return;

    setProperty(model, 'name', '${node.id}_model');
    _applyThreeNodePropertiesRecursively(model, node);
    _removeThreeObjectByName(group, '${node.id}_mesh');
    callMethod(group, 'add', <Object?>[model]);
  }

  void _applyThreeNodePropertiesRecursively(Object? object, ARNode node) {
    _applyThreeNodeProperties(object, node);
    try {
      callMethod(object, 'traverse', <Object?>[
        _allowInteropValue((JSAny? child) {
          _applyThreeNodeProperties(child, node);
        }),
      ]);
    } on Object {
      // Not every Three.js object-like loader result exposes traverse().
    }
  }

  void _removeThreeObjectByName(Object? parent, String name) {
    final object = callMethod(parent, 'getObjectByName', <Object?>[name]);
    if (object != null) {
      callMethod(parent, 'remove', <Object?>[object]);
    }
  }

  Object? _cloneThreeObject(Object? object) {
    try {
      return callMethod(object, 'clone', <Object?>[true]);
    } on Object {
      return null;
    }
  }

  Object? _loadedThreeModelObject(Object? loaded, ARNode node) {
    if (_modelFormatName(node) == 'gltf' || _modelFormatName(node) == 'glb') {
      return getProperty(loaded, 'scene') ?? loaded;
    }
    return loaded;
  }

  Object? _modelLoaderConstructor(Object? three, ARNode node) {
    final constructorName = switch (_modelFormatName(node)) {
      'glb' || 'gltf' => 'GLTFLoader',
      'obj' => 'OBJLoader',
      _ => null,
    };
    if (constructorName == null) return null;
    return getProperty(three, constructorName) ??
        getProperty(web.window, constructorName);
  }

  String? _modelUrlFor(ARNode node) {
    final asset = node.effectiveModelAsset;
    final path =
        _metadataString(asset?.path) ?? _metadataString(node.modelPath);
    if (path == null) return null;

    final uri = Uri.tryParse(path);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'blob' ||
            uri.scheme == 'data')) {
      return path;
    }

    final source = asset?.source.name;
    if (source == 'file') {
      if (uri != null && uri.scheme == 'file') return null;
      if (path.startsWith('/')) return null;
      return path;
    }

    return _flutterWebAssetUrl(path, package: asset?.package);
  }

  String _modelFormatName(ARNode node) =>
      node.effectiveModelAsset?.format.name ?? node.contentType.name;

  String _flutterWebAssetUrl(String path, {String? package}) {
    final normalized =
        path.replaceAll(String.fromCharCode(92), '/').replaceFirst(
              RegExp('^/+'),
              '',
            );
    final assetKey = package != null &&
            package.trim().isNotEmpty &&
            !normalized.startsWith('packages/')
        ? 'packages/${package.trim()}/$normalized'
        : normalized;
    return _joinWebPathSegments(<String>['assets', ...assetKey.split('/')]);
  }

  String _joinWebPathSegments(List<String> segments) => segments
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');

  Object? _buildThreeMesh(Object? three, ARNode node) {
    final geometry = _buildThreeGeometry(three, node);
    final material = _buildThreeMaterial(three, node);
    if (geometry == null || material == null) return null;

    final mesh = callConstructor(
      getProperty(three, 'Mesh'),
      <Object?>[geometry, material],
    );
    setProperty(mesh, 'name', '${node.id}_mesh');
    _orientThreePrimitiveMesh(mesh, node);
    _applyThreeNodeProperties(mesh, node);
    return mesh;
  }

  void _applyThreeNodeProperties(Object? object, ARNode node) {
    setProperty(object, 'visible', node.isVisible);
    setProperty(object, 'castShadow', node.castsShadow);
    setProperty(object, 'receiveShadow', node.receivesShadow);
    setProperty(object, 'renderOrder', node.renderOrder);
  }

  void _orientThreePrimitiveMesh(Object? mesh, ARNode node) {
    if (node.primitiveShape != ARPrimitiveShape.plane) return;
    final rotation = getProperty(mesh, 'rotation');
    setProperty(rotation, 'x', math.pi / 2);
  }

  void _applyThreeAnchorTransform(Object? object, String? anchorId) {
    final pose = anchorId == null ? null : _anchors[anchorId];
    if (pose == null) {
      final position = getProperty(object, 'position');
      setProperty(position, 'x', 0.0);
      setProperty(position, 'y', 0.0);
      setProperty(position, 'z', 0.0);
      final quaternion = getProperty(object, 'quaternion');
      setProperty(quaternion, 'x', 0.0);
      setProperty(quaternion, 'y', 0.0);
      setProperty(quaternion, 'z', 0.0);
      setProperty(quaternion, 'w', 1.0);
      return;
    }

    final position = getProperty(object, 'position');
    setProperty(position, 'x', pose.position.x);
    setProperty(position, 'y', pose.position.y);
    setProperty(position, 'z', pose.position.z);

    final quaternion = getProperty(object, 'quaternion');
    setProperty(quaternion, 'x', pose.rotation.x);
    setProperty(quaternion, 'y', pose.rotation.y);
    setProperty(quaternion, 'z', pose.rotation.z);
    setProperty(quaternion, 'w', pose.rotation.w);
  }

  void _applyThreeLocalTransform(Object? object, ARNode node) {
    final position = getProperty(object, 'position');
    setProperty(position, 'x', node.position.x);
    setProperty(position, 'y', node.position.y);
    setProperty(position, 'z', node.position.z);

    final quaternion = getProperty(object, 'quaternion');
    setProperty(quaternion, 'x', node.rotation.x);
    setProperty(quaternion, 'y', node.rotation.y);
    setProperty(quaternion, 'z', node.rotation.z);
    setProperty(quaternion, 'w', node.rotation.w);

    final scale = getProperty(object, 'scale');
    setProperty(scale, 'x', node.scale.x);
    setProperty(scale, 'y', node.scale.y);
    setProperty(scale, 'z', node.scale.z);
  }

  void _removeWebGLNode(String nodeId) {
    final three = getProperty(web.window, 'THREE');
    if (three == null) return;
    final scene = getProperty(web.window, '__arEngineScene');
    if (scene == null) return;
    final obj = callMethod(scene, 'getObjectByName', <Object?>[nodeId]);
    if (obj != null) callMethod(scene, 'remove', <Object?>[obj]);
  }

  Object? _getOrCreateThreeScene(Object? three) {
    var scene = getProperty(web.window, '__arEngineScene');
    if (scene == null) {
      scene = callConstructor(getProperty(three, 'Scene'), <Object?>[]);
      setProperty(web.window, '__arEngineScene', scene);
    }
    return scene;
  }

  Object? _buildThreeGeometry(Object? three, ARNode node) {
    final shape = node.primitiveShape ?? ARPrimitiveShape.cube;
    final s = node.primitiveSize ?? _defaultPrimitiveSize(shape);
    switch (shape) {
      case ARPrimitiveShape.sphere:
        return callConstructor(
          getProperty(three, 'SphereGeometry'),
          <Object?>[s.x / 2, 32, 16],
        );
      case ARPrimitiveShape.cylinder:
        return callConstructor(
          getProperty(three, 'CylinderGeometry'),
          <Object?>[s.x / 2, s.x / 2, s.y, 32],
        );
      case ARPrimitiveShape.cone:
        return _callThreeConstructor(
              three,
              'ConeGeometry',
              <Object?>[s.x / 2, s.y, 32],
            ) ??
            _callThreeConstructor(
              three,
              'CylinderGeometry',
              <Object?>[0.0, s.x / 2, s.y, 32],
            );
      case ARPrimitiveShape.torus:
        return _callThreeConstructor(
              three,
              'TorusGeometry',
              <Object?>[s.x / 2, s.y / 2, 16, 48],
            ) ??
            _callThreeConstructor(
              three,
              'BoxGeometry',
              <Object?>[s.x, s.y, s.z],
            );
      case ARPrimitiveShape.capsule:
        return _callThreeConstructor(
              three,
              'CapsuleGeometry',
              <Object?>[s.x / 2, math.max(0.001, s.y - s.x), 16, 32],
            ) ??
            _callThreeConstructor(
              three,
              'CylinderGeometry',
              <Object?>[s.x / 2, s.x / 2, s.y, 32],
            );
      case ARPrimitiveShape.plane:
        return callConstructor(
          getProperty(three, 'PlaneGeometry'),
          <Object?>[s.x, s.z],
        );
      default:
        return callConstructor(
          getProperty(three, 'BoxGeometry'),
          <Object?>[s.x, s.y, s.z],
        );
    }
  }

  Object? _buildThreeMaterial(Object? three, ARNode node) {
    final mat = node.material;
    final col = mat?.baseColor ?? const ARMaterialColor(r: 0.2, g: 0.6, b: 1);
    final effectiveOpacity = ((mat?.opacity ?? 1.0) * col.a).clamp(0.0, 1.0);
    final hexColor = (_colorComponent(col.r) << 16) |
        (_colorComponent(col.g) << 8) |
        _colorComponent(col.b);
    final material = callConstructor(
      getProperty(three, 'MeshStandardMaterial'),
      <Object?>[
        jsify(<String, Object?>{
          'color': hexColor,
          'metalness': mat?.metallic ?? 0.1,
          'roughness': mat?.roughness ?? 0.5,
          'opacity': effectiveOpacity,
          'transparent': effectiveOpacity < 1.0 ||
              (mat?.blendMode ?? ARBlendMode.opaque) != ARBlendMode.opaque,
        }),
      ],
    );

    final side = getProperty(
      three,
      (mat?.doubleSided ?? false) ||
              node.primitiveShape == ARPrimitiveShape.plane
          ? 'DoubleSide'
          : 'FrontSide',
    );
    if (side != null) setProperty(material, 'side', side);

    final texture = _buildThreeBaseColorTexture(three, node);
    if (texture != null) {
      setProperty(material, 'map', texture);
      setProperty(material, 'needsUpdate', true);
    }
    return material;
  }

  Object? _buildThreeBaseColorTexture(Object? three, ARNode node) {
    final loaderConstructor = getProperty(three, 'TextureLoader');
    _webDiagnostics.setValue(
      'textureLoaderAvailable',
      loaderConstructor != null,
    );
    if (loaderConstructor == null) return null;

    final bytes = _metadataBytes(node.metadata['photoTextureBytes']);
    if (bytes == null || bytes.isEmpty) {
      if (node.metadata.containsKey('photoTextureBytes')) {
        _webDiagnostics.increment('textureBytesMissing');
      }
      return null;
    }

    final cacheKey = _photoTextureCacheKey(node, bytes);
    final cached = _threeTextureCache[cacheKey];
    if (cached != null) {
      _webDiagnostics.increment('textureCacheHits');
      return cached;
    }

    final mimeType =
        _metadataString(node.metadata['photoTextureMimeType']) ?? 'image/jpeg';
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final loader = callConstructor(loaderConstructor, <Object?>[]);
    _webDiagnostics.increment('textureLoadStarted');
    final texture = callMethod(loader, 'load', <Object?>[dataUrl]);
    if (texture == null) {
      _webDiagnostics.increment('textureLoadFailed');
      return null;
    }

    final colorSpace = getProperty(three, 'SRGBColorSpace');
    if (colorSpace != null) {
      setProperty(texture, 'colorSpace', colorSpace);
    }
    final encoding = getProperty(three, 'sRGBEncoding');
    if (encoding != null) {
      setProperty(texture, 'encoding', encoding);
    }
    _threeTextureCache[cacheKey] = texture;
    _webDiagnostics
      ..increment('textureLoadSucceeded')
      ..setValue('textureCacheSize', _threeTextureCache.length);
    return texture;
  }

  Object? _callThreeConstructor(
    Object? three,
    String constructorName,
    List<Object?> arguments,
  ) {
    final constructor = getProperty(three, constructorName);
    if (constructor == null) return null;
    return callConstructor(constructor, arguments);
  }

  ARVector3 _defaultPrimitiveSize(ARPrimitiveShape shape) {
    switch (shape) {
      case ARPrimitiveShape.plane:
        return const ARVector3(1, 0.001, 1);
      case ARPrimitiveShape.cylinder:
      case ARPrimitiveShape.cone:
      case ARPrimitiveShape.capsule:
      case ARPrimitiveShape.sphere:
      case ARPrimitiveShape.torus:
      case ARPrimitiveShape.cube:
        return const ARVector3.one();
    }
  }

  String _photoTextureCacheKey(ARNode node, Uint8List bytes) {
    final explicitKey = _metadataString(node.metadata['photoTextureKey']) ??
        _metadataString(node.metadata['mediaId']) ??
        _metadataString(node.metadata['memoryId']) ??
        node.id;
    final fingerprint = Object.hash(
      bytes.length,
      bytes.first,
      bytes[bytes.length ~/ 2],
      bytes.last,
    );
    return '$explicitKey:${bytes.length}:$fingerprint';
  }

  Uint8List? _metadataBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is ByteBuffer) return value.asUint8List();
    if (value is Iterable) {
      final bytes = <int>[];
      for (final entry in value) {
        if (entry is! num) return null;
        bytes.add(_clampedByte(entry));
      }
      return Uint8List.fromList(bytes);
    }
    return null;
  }

  String? _metadataString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int _clampedByte(num value) {
    final byte = value.toInt();
    if (byte < 0) return 0;
    if (byte > 255) return 255;
    return byte;
  }

  int _colorComponent(double value) => (value.clamp(0.0, 1.0) * 255).round();

  String _webDiagnosticErrorMessage(Object? error) {
    if (error == null) return 'Unknown model load error.';
    try {
      final message = getProperty(error, 'message');
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } on Object {
      // JavaScript error values are not always objects with a message field.
    }
    final fallback = error.toString();
    return fallback.isEmpty ? 'Unknown model load error.' : fallback;
  }
}
