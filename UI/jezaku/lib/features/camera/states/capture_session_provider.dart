import 'dart:async';
import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:jejaku/features/camera/services/capture_metadata_service.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:sensors_plus/sensors_plus.dart';

const _unchanged = Object();

final captureSessionProvider =
    NotifierProvider<CaptureSessionController, CaptureSessionState>(
  CaptureSessionController.new,
);

class CaptureSessionState {
  const CaptureSessionState({
    required this.previewSnapshot,
    this.capturedSnapshot,
    this.capturedBytes,
    this.recordingDraft,
    this.capturedAt,
    this.draftSource = CaptureDraftSource.camera,
    this.anchorPreset = CaptureAnchorPreset.standard,
    this.localPose,
    this.arDiagnostics,
  });

  final CaptureSensorSnapshot previewSnapshot;
  final CaptureSensorSnapshot? capturedSnapshot;
  final Uint8List? capturedBytes;
  final CaptureRecordingDraft? recordingDraft;
  final DateTime? capturedAt;
  final CaptureDraftSource draftSource;
  final CaptureAnchorPreset anchorPreset;
  final AnchorLocalPose? localPose;
  final Map<String, Object?>? arDiagnostics;

  CaptureSensorSnapshot get activeSnapshot {
    return capturedSnapshot ?? previewSnapshot;
  }

  bool get hasCapturedSnapshot => capturedSnapshot != null;

  bool get hasCapturedBytes => capturedBytes != null;

  bool get hasRecordingDraft => recordingDraft != null;

  bool get hasArDiagnostics =>
      arDiagnostics != null && arDiagnostics!.isNotEmpty;

  ARCaptureDiagnostics? get arCaptureDiagnostics {
    return ARCaptureDiagnostics.tryFromMap(arDiagnostics);
  }

  List<String> get arDiagnosticsMetadataLabels {
    return arCaptureDiagnostics?.metadataLabels ?? const <String>[];
  }

  double get anchorRadiusMeters => anchorPreset.radiusMeters;

  String get anchorPlanLabel {
    return anchorPreset.planLabel;
  }

  String get anchorTypeLabel {
    if (draftSource != CaptureDraftSource.camera && hasCapturedSnapshot) {
      return '${activeSnapshot.anchorType} - ${anchorPreset.label} plan';
    }
    return anchorPreset.anchorType;
  }

  String get statusLabel {
    if (!hasCapturedSnapshot) {
      return 'Live preview';
    }
    return switch (draftSource) {
      CaptureDraftSource.camera => 'Captured snapshot',
      CaptureDraftSource.importedPhoto => 'Imported photo',
      CaptureDraftSource.arSnapshot => 'AR snapshot',
      CaptureDraftSource.arRecording => 'AR screen recording',
    };
  }

  String get captureTimeLabel {
    final timestamp = capturedAt;
    if (timestamp == null) {
      return 'Not captured yet';
    }
    return _formatClock(timestamp);
  }

  CaptureSessionState copyWith({
    CaptureSensorSnapshot? previewSnapshot,
    Object? capturedSnapshot = _unchanged,
    Object? capturedBytes = _unchanged,
    Object? recordingDraft = _unchanged,
    Object? capturedAt = _unchanged,
    CaptureDraftSource? draftSource,
    CaptureAnchorPreset? anchorPreset,
    Object? localPose = _unchanged,
    Object? arDiagnostics = _unchanged,
  }) {
    return CaptureSessionState(
      previewSnapshot: previewSnapshot ?? this.previewSnapshot,
      capturedSnapshot: identical(capturedSnapshot, _unchanged)
          ? this.capturedSnapshot
          : capturedSnapshot as CaptureSensorSnapshot?,
      capturedBytes: identical(capturedBytes, _unchanged)
          ? this.capturedBytes
          : capturedBytes as Uint8List?,
      recordingDraft: identical(recordingDraft, _unchanged)
          ? this.recordingDraft
          : recordingDraft as CaptureRecordingDraft?,
      capturedAt: identical(capturedAt, _unchanged)
          ? this.capturedAt
          : capturedAt as DateTime?,
      draftSource: draftSource ?? this.draftSource,
      anchorPreset: anchorPreset ?? this.anchorPreset,
      localPose: identical(localPose, _unchanged)
          ? this.localPose
          : localPose as AnchorLocalPose?,
      arDiagnostics: identical(arDiagnostics, _unchanged)
          ? this.arDiagnostics
          : _normalizeARDiagnosticsPayload(arDiagnostics),
    );
  }
}

enum CaptureDraftSource {
  camera,
  importedPhoto,
  arSnapshot,
  arRecording,
}

class CaptureRecordingDraft {
  const CaptureRecordingDraft({
    required this.filePath,
    required this.duration,
    required this.frameCount,
    this.targetFps,
    this.videoBitrateKbps,
    this.outputFormat,
    this.includesUIOverlay = true,
    this.includesAudio = false,
    this.fileSizeBytes,
    this.arDiagnostics,
  });

  final String filePath;
  final Duration duration;
  final int frameCount;
  final int? targetFps;
  final int? videoBitrateKbps;
  final String? outputFormat;
  final bool includesUIOverlay;
  final bool includesAudio;
  final int? fileSizeBytes;
  final Map<String, Object?>? arDiagnostics;

  bool get hasArDiagnostics =>
      arDiagnostics != null && arDiagnostics!.isNotEmpty;

  ARCaptureDiagnostics? get arCaptureDiagnostics {
    return ARCaptureDiagnostics.tryFromMap(arDiagnostics);
  }

  String get label => 'AR screen recording';

  String get detailLabel => '$durationLabel - $frameCountLabel';

  double? get actualFpsValue {
    final seconds = duration.inMilliseconds / 1000;
    if (seconds <= 0 || frameCount <= 0) {
      return null;
    }
    return frameCount / seconds;
  }

  String? get recordingQualityWarningLabel {
    final actualFps = actualFpsValue;
    final target = targetFps;
    if (actualFps == null || target == null || target <= 0) {
      return null;
    }
    final ratio = actualFps / target;
    if (ratio < 0.5) {
      return 'Low captured FPS';
    }
    if (ratio < 0.8) {
      return 'Reduced captured FPS';
    }
    return null;
  }

  String? get recordingQualityDetailLabel {
    final actualFps = actualFpsValue;
    final target = targetFps;
    if (actualFps == null || target == null || target <= 0) {
      return null;
    }
    return 'Captured ${actualFps.toStringAsFixed(1)} of $target fps target';
  }

  String get recordingHealthStatusLabel {
    return recordingQualityWarningLabel == null
        ? 'Ready to publish'
        : 'Needs quality review';
  }

  String get recordingHealthDetailLabel {
    final qualityDetail = recordingQualityDetailLabel;
    if (qualityDetail != null) {
      return qualityDetail;
    }
    return 'Recording profile captured';
  }

  List<String> get metadataLabels {
    return <String>[
      if (targetFps != null) '$targetFps fps target',
      if (actualFpsLabel != null) actualFpsLabel!,
      if (videoBitrateLabel != null) videoBitrateLabel!,
      if (outputFormatLabel != null) outputFormatLabel!,
      includesUIOverlay ? 'AR visual overlay' : 'Raw AR frame',
      includesAudio ? 'Audio on' : 'Silent',
      if (fileSizeLabel != null) fileSizeLabel!,
      ...?arCaptureDiagnostics?.metadataLabels,
    ];
  }

  String get durationLabel {
    final milliseconds = duration.inMilliseconds;
    if (milliseconds < 1000) {
      return '$milliseconds ms';
    }
    return '${(milliseconds / 1000).toStringAsFixed(1)} s';
  }

  String get frameCountLabel {
    return '$frameCount frame${frameCount == 1 ? '' : 's'}';
  }

  String? get actualFpsLabel {
    final actualFps = actualFpsValue;
    if (actualFps == null) {
      return null;
    }
    return '${actualFps.toStringAsFixed(1)} fps captured';
  }

  String? get videoBitrateLabel {
    final bitrate = videoBitrateKbps;
    if (bitrate == null || bitrate <= 0) {
      return null;
    }
    return '${(bitrate / 1000).toStringAsFixed(1)} Mbps';
  }

  String? get outputFormatLabel {
    final format = outputFormat?.trim();
    if (format == null || format.isEmpty) {
      return null;
    }
    return format.toUpperCase();
  }

  String? get fileSizeLabel {
    final bytes = fileSizeBytes;
    if (bytes == null || bytes <= 0) {
      return null;
    }
    return _formatByteCount(bytes);
  }
}

enum CaptureAnchorPreset {
  tight,
  standard,
  area,
  perimeter,
}

extension CaptureAnchorPresetDetails on CaptureAnchorPreset {
  String get label {
    return switch (this) {
      CaptureAnchorPreset.tight => 'Tight',
      CaptureAnchorPreset.standard => 'Standard',
      CaptureAnchorPreset.area => 'Area',
      CaptureAnchorPreset.perimeter => 'Perimeter',
    };
  }

  String get description {
    return switch (this) {
      CaptureAnchorPreset.tight => 'Best for a single object or table.',
      CaptureAnchorPreset.standard => 'Balanced for nearby memory sharing.',
      CaptureAnchorPreset.area => 'Covers a room, courtyard, or small venue.',
      CaptureAnchorPreset.perimeter => 'Scans the full 100 m nearby radius.',
    };
  }

  String get planLabel {
    return '$label - ${radiusMeters.round()} m';
  }

  double get radiusMeters {
    return switch (this) {
      CaptureAnchorPreset.tight => 15,
      CaptureAnchorPreset.standard => 30,
      CaptureAnchorPreset.area => 60,
      CaptureAnchorPreset.perimeter => 100,
    };
  }

  String get anchorType {
    return switch (this) {
      CaptureAnchorPreset.tight => 'Tight hybrid geo/orientation',
      CaptureAnchorPreset.standard => 'Hybrid geo/orientation',
      CaptureAnchorPreset.area => 'Area geo/orientation',
      CaptureAnchorPreset.perimeter => 'Perimeter geo/orientation',
    };
  }
}

String _formatClock(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatByteCount(int byteCount) {
  if (byteCount < 1024) {
    return '$byteCount B';
  }
  final kib = byteCount / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

Map<String, Object?>? _normalizeARDiagnosticsPayload(Object? source) {
  return ARCaptureDiagnostics.tryNormalizeSyncableMap(source);
}

class CaptureSessionController extends Notifier<CaptureSessionState> {
  final ARCaptureDiagnosticsMemoryCache _arDiagnosticsCache =
      ARCaptureDiagnosticsMemoryCache(capacity: 8);

  ARCaptureDiagnostics? get latestArDiagnostics => _arDiagnosticsCache.latest;

  Map<String, Object?> get arDiagnosticsCacheSnapshot {
    return _arDiagnosticsCache.toSyncableMap();
  }

  int get arDiagnosticsCacheLength => _arDiagnosticsCache.length;

  @override
  CaptureSessionState build() {
    final snapshot = ref.read(captureMetadataServiceProvider).previewSnapshot();
    _restoreARDiagnosticsCache();
    return CaptureSessionState(previewSnapshot: snapshot);
  }

  void refreshPreview() {
    final snapshot = ref.read(captureMetadataServiceProvider).previewSnapshot();
    state = state.copyWith(previewSnapshot: snapshot);
  }

  Future<CaptureSensorSnapshot> refreshPreviewFromDeviceSensors() async {
    final current = state.previewSnapshot;
    final locationFuture = _readLocationFix(current);
    final orientationFuture = _readOrientationFix(current);
    final location = await locationFuture;
    final orientation = await orientationFuture;
    if (!ref.mounted) {
      return current;
    }

    final resolvedLocation = location ??
        CaptureLocationFix(
          latitude: current.latitude,
          longitude: current.longitude,
          altitudeMeters: current.altitudeMeters,
          gpsAccuracyMeters: current.gpsAccuracyMeters,
        );
    final resolvedOrientation = orientation ??
        CaptureOrientationFix(
          headingDegrees: current.headingDegrees,
          pitchDegrees: current.pitchDegrees,
          rollDegrees: current.rollDegrees,
        );
    final snapshot = ref.read(captureMetadataServiceProvider).previewSnapshot(
          location: resolvedLocation,
          orientation: resolvedOrientation,
          gpsAccuracyMeters: resolvedLocation.gpsAccuracyMeters,
        );
    final enrichedSnapshot = snapshot.copyWith(
      anchorType: current.anchorType,
      captureSource: _captureSourceFor(
        hasDeviceLocation: location != null,
        hasDeviceOrientation: orientation != null,
        fallbackSource: current.captureSource,
      ),
    );
    if (!ref.mounted) {
      return enrichedSnapshot;
    }
    state = state.copyWith(previewSnapshot: enrichedSnapshot);
    return enrichedSnapshot;
  }

  void stageCurrentCapture({DateTime? capturedAt, Uint8List? bytes}) {
    state = state.copyWith(
      capturedSnapshot: state.previewSnapshot,
      capturedBytes: bytes == null ? null : Uint8List.fromList(bytes),
      recordingDraft: null,
      capturedAt: capturedAt ?? DateTime.now(),
      draftSource: CaptureDraftSource.camera,
      localPose: null,
      arDiagnostics: null,
    );
  }

  void stageImportedCapture(
    CaptureSensorSnapshot snapshot, {
    required DateTime capturedAt,
  }) {
    state = state.copyWith(
      capturedSnapshot: snapshot,
      capturedBytes: null,
      recordingDraft: null,
      capturedAt: capturedAt,
      draftSource: CaptureDraftSource.importedPhoto,
      localPose: null,
      arDiagnostics: null,
    );
  }

  void stageARSnapshot({
    required DateTime capturedAt,
    Uint8List? bytes,
    AnchorLocalPose? localPose,
    Map<String, Object?>? arDiagnostics,
  }) {
    final captureSource = state.previewSnapshot.captureSource;
    final snapshot = state.previewSnapshot.copyWith(
      anchorType: 'AR viewer geo/orientation',
      captureSource: 'AR snapshot + $captureSource',
    );
    final normalizedDiagnostics = _cacheARDiagnostics(arDiagnostics);
    state = state.copyWith(
      capturedSnapshot: snapshot,
      capturedBytes: bytes == null ? null : Uint8List.fromList(bytes),
      recordingDraft: null,
      capturedAt: capturedAt,
      draftSource: CaptureDraftSource.arSnapshot,
      localPose: localPose,
      arDiagnostics: normalizedDiagnostics,
    );
  }

  void stageARRecording({
    required DateTime capturedAt,
    required String filePath,
    required Duration duration,
    required int frameCount,
    int? targetFps,
    int? videoBitrateKbps,
    String? outputFormat,
    bool includesUIOverlay = true,
    bool includesAudio = false,
    int? fileSizeBytes,
    Map<String, Object?>? arDiagnostics,
  }) {
    final captureSource = state.previewSnapshot.captureSource;
    final snapshot = state.previewSnapshot.copyWith(
      anchorType: 'AR screen recording geo/orientation',
      captureSource: 'AR screen recording + $captureSource',
    );
    final normalizedDiagnostics = _cacheARDiagnostics(arDiagnostics);
    state = state.copyWith(
      capturedSnapshot: snapshot,
      capturedBytes: null,
      recordingDraft: CaptureRecordingDraft(
        filePath: filePath,
        duration: duration,
        frameCount: frameCount,
        targetFps: targetFps,
        videoBitrateKbps: videoBitrateKbps,
        outputFormat: outputFormat,
        includesUIOverlay: includesUIOverlay,
        includesAudio: includesAudio,
        fileSizeBytes: fileSizeBytes,
        arDiagnostics: normalizedDiagnostics,
      ),
      capturedAt: capturedAt,
      draftSource: CaptureDraftSource.arRecording,
      localPose: null,
      arDiagnostics: normalizedDiagnostics,
    );
  }

  void clearArDiagnosticsCache() {
    _arDiagnosticsCache.clear();
    ref.read(arCaptureDiagnosticsCacheStoreProvider).clearCache();
  }

  void setAnchorPreset(CaptureAnchorPreset preset) {
    state = state.copyWith(anchorPreset: preset);
  }

  void updateGpsAccuracy(double gpsAccuracyMeters) {
    state = state.copyWith(
      previewSnapshot: state.previewSnapshot.copyWith(
        gpsAccuracyMeters: gpsAccuracyMeters,
      ),
      capturedSnapshot: state.capturedSnapshot?.copyWith(
        gpsAccuracyMeters: gpsAccuracyMeters,
      ),
    );
  }

  void updatePreviewPose({
    double? latitude,
    double? longitude,
    double? altitudeMeters,
    double? gpsAccuracyMeters,
    double? headingDegrees,
    double? pitchDegrees,
    double? rollDegrees,
    String? captureSource,
  }) {
    state = state.copyWith(
      previewSnapshot: state.previewSnapshot.copyWith(
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        gpsAccuracyMeters: gpsAccuracyMeters,
        headingDegrees: headingDegrees,
        pitchDegrees: pitchDegrees,
        rollDegrees: rollDegrees,
        captureSource: captureSource,
      ),
    );
  }

  void clearDraft() {
    state = state.copyWith(
      capturedSnapshot: null,
      capturedBytes: null,
      recordingDraft: null,
      capturedAt: null,
      draftSource: CaptureDraftSource.camera,
      anchorPreset: CaptureAnchorPreset.standard,
      localPose: null,
      arDiagnostics: null,
    );
  }

  Map<String, Object?>? _cacheARDiagnostics(Object? payload) {
    final normalized = _normalizeARDiagnosticsPayload(payload);
    final diagnostics = ARCaptureDiagnostics.tryFromMap(normalized);
    if (diagnostics != null) {
      _arDiagnosticsCache.put(diagnostics);
      ref
          .read(arCaptureDiagnosticsCacheStoreProvider)
          .saveCache(_arDiagnosticsCache);
    }
    return normalized;
  }

  void _restoreARDiagnosticsCache() {
    final restoredCache =
        ref.read(arCaptureDiagnosticsCacheStoreProvider).loadCache();
    _arDiagnosticsCache
      ..clear()
      ..putAll(restoredCache.values);
  }

  Future<CaptureLocationFix?> _readLocationFix(
    CaptureSensorSnapshot fallback,
  ) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission()
          .timeout(const Duration(milliseconds: 500));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 2));
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 2),
      ).timeout(const Duration(seconds: 2));
      return CaptureLocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        altitudeMeters: position.altitude.isFinite
            ? position.altitude
            : fallback.altitudeMeters,
        gpsAccuracyMeters: position.accuracy.isFinite
            ? position.accuracy
            : fallback.gpsAccuracyMeters,
      );
    } on MissingPluginException {
      return null;
    } on Object {
      return null;
    }
  }

  Future<CaptureOrientationFix?> _readOrientationFix(
    CaptureSensorSnapshot fallback,
  ) async {
    final headingFuture = _readCompassHeading();
    final attitudeFuture = _readAccelerometerAttitude();
    final heading = await headingFuture;
    final attitude = await attitudeFuture;
    if (heading == null && attitude == null) {
      return null;
    }

    return CaptureOrientationFix(
      headingDegrees: heading ?? fallback.headingDegrees,
      pitchDegrees: attitude?.pitchDegrees ?? fallback.pitchDegrees,
      rollDegrees: attitude?.rollDegrees ?? fallback.rollDegrees,
    );
  }

  Future<double?> _readCompassHeading() async {
    try {
      final stream = FlutterCompass.events;
      if (stream == null) {
        return null;
      }
      final event = await stream
          .firstWhere(
            (event) =>
                event.headingForCameraMode != null || event.heading != null,
          )
          .timeout(
            const Duration(milliseconds: 300),
            onTimeout: () => CompassEvent.fromList(null),
          );
      final heading = event.headingForCameraMode ?? event.heading;
      if (heading == null || !heading.isFinite) {
        return null;
      }
      return _normalizeHeading(heading);
    } on MissingPluginException {
      return null;
    } on Object {
      return null;
    }
  }

  Future<({double pitchDegrees, double rollDegrees})?>
      _readAccelerometerAttitude() async {
    try {
      final event = await accelerometerEventStream().first.timeout(
            const Duration(milliseconds: 300),
          );
      final pitchRadians = math.atan2(
        -event.x,
        math.sqrt((event.y * event.y) + (event.z * event.z)),
      );
      final rollRadians = math.atan2(event.y, event.z);
      return (
        pitchDegrees: pitchRadians * 180 / math.pi,
        rollDegrees: rollRadians * 180 / math.pi,
      );
    } on MissingPluginException {
      return null;
    } on Object {
      return null;
    }
  }

  double _normalizeHeading(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  String _captureSourceFor({
    required bool hasDeviceLocation,
    required bool hasDeviceOrientation,
    required String fallbackSource,
  }) {
    if (hasDeviceLocation && hasDeviceOrientation) {
      return 'Device GPS + compass + accelerometer';
    }
    if (hasDeviceLocation) {
      return 'Device GPS + orientation fallback';
    }
    if (hasDeviceOrientation) {
      return 'Demo location + device compass/accelerometer';
    }
    return fallbackSource;
  }
}
