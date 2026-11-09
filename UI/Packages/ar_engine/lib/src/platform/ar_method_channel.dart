import 'dart:async';

import 'package:flutter/services.dart';

import '../ar_anchor.dart';
import '../ar_camera.dart';
import '../ar_capabilities.dart';
import '../ar_controller.dart';
import '../ar_hit_test.dart';
import '../ar_node.dart';
import '../ar_plane.dart';
import '../ar_runtime_diagnostics.dart';
import '../ar_session_config.dart';
import '../geospatial/ar_geospatial.dart';
import '../models/ar_matrix4.dart';
import '../models/ar_pose.dart';
import 'ar_platform_interface.dart';

/// Default MethodChannel + EventChannel bridge used by Android (ARCore) and
/// iOS (ARKit/Metal). Every method in [ArEnginePlatform] is wired here.
class ArEngineMethodChannel extends ArEnginePlatform {
  // ── Channels ──────────────────────────────────────────────────────────────

  static const _ch = MethodChannel('com.arengine/ar_engine');
  static const _camCh = EventChannel('com.arengine/camera_stream');
  static const _planCh = EventChannel('com.arengine/plane_stream');
  static const _ancrCh = EventChannel('com.arengine/anchor_stream');
  static const _lgtCh = EventChannel('com.arengine/light_stream');

  // ── Broadcast streams (lazily initialised once, shared) ───────────────────

  late final Stream<ARCamera> _cameraStream = _camCh
      .receiveBroadcastStream()
      .map((e) => _parseCamera(e as Map<dynamic, dynamic>))
      .handleError(_logError)
      .asBroadcastStream();

  late final Stream<List<ARPlane>> _planeStream = _planCh
      .receiveBroadcastStream()
      .map(
        (e) => (e as List<dynamic>)
            .cast<Map<dynamic, dynamic>>()
            .map(ARPlane.fromMap)
            .toList(),
      )
      .handleError(_logError)
      .asBroadcastStream();

  late final Stream<ARAnchor> _anchorStream = _ancrCh
      .receiveBroadcastStream()
      .map((e) => ARAnchor.fromMap(e as Map<dynamic, dynamic>))
      .handleError(_logError)
      .asBroadcastStream();

  late final Stream<double> _lightStream = _lgtCh
      .receiveBroadcastStream()
      .map((e) => (e as num).toDouble())
      .handleError(_logError)
      .asBroadcastStream();

  @override
  Stream<ARCamera> get cameraStream => _cameraStream;
  @override
  Stream<List<ARPlane>> get planeStream => _planeStream;
  @override
  Stream<ARAnchor> get anchorStream => _anchorStream;
  @override
  Stream<double> get lightIntensityStream => _lightStream;

  // ── Session lifecycle ─────────────────────────────────────────────────────

  @override
  Future<bool> isARSupported() async =>
      await _ch.invokeMethod<bool>('isARSupported') ?? false;

  @override
  Future<ARCapabilities> getCapabilities() async {
    try {
      final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
        'getCapabilities',
      );
      return ARCapabilities.fromMap(raw);
    } on MissingPluginException {
      return super.getCapabilities();
    }
  }

  @override
  Future<void> initSession(ARSessionConfig config) =>
      _ch.invokeMethod('initSession', config.toMap());

  @override
  Future<void> reconfigureSession(ARSessionConfig config) =>
      _ch.invokeMethod('reconfigureSession', config.toMap());

  @override
  Future<void> pauseSession() => _ch.invokeMethod('pauseSession');

  @override
  Future<void> resumeSession() => _ch.invokeMethod('resumeSession');

  @override
  Future<void> destroySession() => _ch.invokeMethod('destroySession');

  // ── Snapshot ──────────────────────────────────────────────────────────────

  @override
  Future<Uint8List?> captureSnapshot() async {
    final bytes = await _ch.invokeMethod<Uint8List>('captureSnapshot');
    return bytes;
  }

  @override
  Future<Map<String, Object?>?> encodeRecording({
    required List<Uint8List> frames,
    required Map<String, Object?> config,
    required int durationMillis,
  }) async {
    try {
      final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
        'encodeRecording',
        <String, Object?>{
          'frames': frames,
          'config': config,
          'durationMillis': durationMillis,
        },
      );
      if (raw == null) return null;
      return raw.cast<String, Object?>();
    } on PlatformException catch (error) {
      if (error.code == 'UNSUPPORTED_RECORDING') return null;
      rethrow;
    } on MissingPluginException {
      return super.encodeRecording(
        frames: frames,
        config: config,
        durationMillis: durationMillis,
      );
    }
  }

  @override
  Future<double?> sampleDepth(double x, double y) async {
    try {
      final depthMeters = await _ch.invokeMethod<num>(
        'sampleDepth',
        <String, double>{'x': x, 'y': y},
      );
      return depthMeters?.toDouble();
    } on MissingPluginException {
      return super.sampleDepth(x, y);
    }
  }

  @override
  Future<ARRuntimeDiagnostics> getRuntimeDiagnostics() async {
    try {
      final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
        'getRuntimeDiagnostics',
      );
      return ARRuntimeDiagnostics.fromMap(raw, source: 'methodChannel');
    } on MissingPluginException {
      return super.getRuntimeDiagnostics();
    }
  }

  // ── Hit testing ───────────────────────────────────────────────────────────

  @override
  Future<List<ARHitTestResult>> hitTest(double x, double y) async {
    final raw = await _ch.invokeListMethod<Object?>(
      'hitTest',
      <String, double>{'x': x, 'y': y},
    );
    return raw
            ?.cast<Map<dynamic, dynamic>>()
            .map(ARHitTestResult.fromMap)
            .toList() ??
        <ARHitTestResult>[];
  }

  // ── Anchors ───────────────────────────────────────────────────────────────

  @override
  Future<ARAnchor> addAnchor(ARHitTestResult hitResult) async {
    final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
      'addAnchor',
      hitResult.toMap(),
    );
    return ARAnchor.fromMap(raw!);
  }

  @override
  Future<ARAnchor> addAnchorAtPose(ARPoseInput pose) async {
    final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
      'addAnchorAtPose',
      pose.toMap(),
    );
    return ARAnchor.fromMap(raw!);
  }

  @override
  Future<void> removeAnchor(String anchorId) =>
      _ch.invokeMethod('removeAnchor', anchorId);

  @override
  Future<String?> hostCloudAnchor(
    String anchorId, {
    int ttlDays = 30,
  }) async {
    try {
      return _ch.invokeMethod<String>(
        'hostCloudAnchor',
        <String, Object?>{
          'anchorId': anchorId,
          'ttlDays': ttlDays,
        },
      );
    } on PlatformException catch (error) {
      if (error.code == 'UNSUPPORTED_CLOUD_ANCHORS') return null;
      rethrow;
    } on MissingPluginException {
      return super.hostCloudAnchor(anchorId, ttlDays: ttlDays);
    }
  }

  @override
  Future<ARAnchor?> resolveCloudAnchor(String cloudId) async {
    try {
      final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
        'resolveCloudAnchor',
        <String, Object?>{'cloudId': cloudId},
      );
      return raw == null ? null : ARAnchor.fromMap(raw);
    } on PlatformException catch (error) {
      if (error.code == 'UNSUPPORTED_CLOUD_ANCHORS') return null;
      rethrow;
    } on MissingPluginException {
      return super.resolveCloudAnchor(cloudId);
    }
  }

  @override
  Future<ARAnchor> addGeospatialAnchor(
    ARGeospatialAnchor anchor, {
    required ARGeoOrigin origin,
  }) async {
    try {
      final raw = await _ch.invokeMapMethod<dynamic, dynamic>(
        'addGeospatialAnchor',
        <String, dynamic>{
          'anchor': anchor.toMap(),
          'origin': origin.toMap(),
        },
      );
      return ARAnchor.fromMap(raw!);
    } on PlatformException catch (error) {
      if (error.code == 'UNSUPPORTED_GEOSPATIAL') {
        return super.addGeospatialAnchor(anchor, origin: origin);
      }
      rethrow;
    } on MissingPluginException {
      return super.addGeospatialAnchor(anchor, origin: origin);
    }
  }

  // ── Nodes ─────────────────────────────────────────────────────────────────

  @override
  Future<String> addNode(ARNode node, {String? anchorId}) async {
    final map = node.toMap();
    if (anchorId != null) map['anchorId'] = anchorId;
    return await _ch.invokeMethod<String>('addNode', map) ?? node.id;
  }

  @override
  Future<void> updateNode(ARNode node) =>
      _ch.invokeMethod('updateNode', node.toMap());

  @override
  Future<void> removeNode(String nodeId) =>
      _ch.invokeMethod('removeNode', nodeId);

  // ── Desktop texture ───────────────────────────────────────────────────────

  @override
  Future<int?> getDesktopTextureId() =>
      _ch.invokeMethod<int>('getDesktopTextureId');

  // ── Private helpers ───────────────────────────────────────────────────────

  ARCamera _parseCamera(Map<dynamic, dynamic> raw) {
    List<double> doubles(String key) => (raw[key] as List<dynamic>)
        .cast<num>()
        .map((e) => e.toDouble())
        .toList();
    List<int> ints(String key) =>
        (raw[key] as List<dynamic>).cast<num>().map((e) => e.toInt()).toList();

    return ARCamera(
      pose: ARPose.fromMap(raw['pose'] as Map<dynamic, dynamic>),
      projectionMatrix: ARMatrix4(doubles('projectionMatrix')),
      viewMatrix: ARMatrix4(doubles('viewMatrix')),
      trackingState: ARTrackingState.values.firstWhere(
        (e) => e.name == (raw['trackingState'] as String? ?? ''),
        orElse: () => ARTrackingState.tracking,
      ),
      intrinsics: doubles('intrinsics'),
      imageResolution: ints('imageResolution'),
      failureReason: raw['failureReason'] == null
          ? null
          : ARTrackingFailureReason.values.firstWhere(
              (e) => e.name == raw['failureReason'],
              orElse: () => ARTrackingFailureReason.none,
            ),
    );
  }

  void _logError(Object err, StackTrace st) {
    // ignore: avoid_print
    print('[AREngine] EventChannel error: $err');
  }
}
