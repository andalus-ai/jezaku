import 'ar_session_health_assessment.dart';

const _unsetCaptureCapability = Object();

class ARCaptureCapability {
  const ARCaptureCapability({
    required this.hasSession,
    required this.supportsSnapshotCapture,
    required this.supportsRecording,
    this.readiness,
  });

  factory ARCaptureCapability.fromAssessment({
    required bool hasSession,
    required bool supportsSnapshotCapture,
    required bool supportsRecording,
    ARSessionHealthAssessment? assessment,
    ARSessionReadiness? readiness,
  }) =>
      ARCaptureCapability(
        hasSession: hasSession,
        supportsSnapshotCapture: supportsSnapshotCapture,
        supportsRecording: supportsRecording,
        readiness: assessment?.readiness ?? readiness,
      );

  factory ARCaptureCapability.fromMap(Map<dynamic, dynamic> map) {
    final readinessMap = map['readiness'];
    return ARCaptureCapability(
      hasSession: map['hasSession'] as bool? ?? false,
      supportsSnapshotCapture: map['supportsSnapshotCapture'] as bool? ?? false,
      supportsRecording: map['supportsRecording'] as bool? ?? false,
      readiness: readinessMap is Map
          ? ARSessionReadiness.fromMap(
              Map<dynamic, dynamic>.from(readinessMap),
            )
          : null,
    );
  }

  final bool hasSession;
  final bool supportsSnapshotCapture;
  final bool supportsRecording;
  final ARSessionReadiness? readiness;

  bool get canCaptureSnapshot =>
      hasSession &&
      supportsSnapshotCapture &&
      (readiness?.canCaptureSnapshot ?? true);

  bool get canControlRecording => hasSession && supportsRecording;

  bool get canStartRecording =>
      canControlRecording && (readiness?.canRecord ?? true);

  bool get hasReadinessWarning {
    final activeReadiness = readiness;
    return activeReadiness != null && !activeReadiness.isReady;
  }

  ARSessionHealthGuidance? get readinessGuidance {
    final activeReadiness = readiness;
    if (activeReadiness == null || activeReadiness.isReady) {
      return null;
    }
    final guidance = activeReadiness.guidance;
    if (guidance != null) {
      return guidance;
    }
    final primaryIssue = activeReadiness.primaryIssue;
    return primaryIssue == null
        ? null
        : ARSessionHealthGuidance.forIssue(primaryIssue);
  }

  String? get readinessActionLabel => readinessGuidance?.actionLabel;

  String? get readinessGuidanceLabel {
    final guidance = readinessGuidance;
    if (guidance == null) {
      return null;
    }
    return '${guidance.actionLabel}: ${guidance.message}';
  }

  String? get readinessDetailLabel {
    final activeReadiness = readiness;
    if (activeReadiness == null || activeReadiness.isReady) {
      return null;
    }
    return activeReadiness.detailLabel;
  }

  String get idleStatusLabel {
    final activeReadiness = readiness;
    if (activeReadiness != null && !activeReadiness.isReady) {
      return activeReadiness.isBlocked
          ? 'AR capture blocked'
          : 'AR capture limited';
    }
    return 'AR capture ready';
  }

  String get snapshotUnavailableLabel {
    if (!hasSession) {
      return 'AR capture waiting for a session';
    }
    if (!supportsSnapshotCapture) {
      return 'Snapshots unavailable on this device';
    }
    final activeReadiness = readiness;
    if (activeReadiness != null && !activeReadiness.canCaptureSnapshot) {
      return activeReadiness.detailLabel;
    }
    return 'AR snapshot unavailable';
  }

  String get recordingUnavailableLabel {
    if (!hasSession) {
      return 'AR screen recording waiting for a session';
    }
    if (!supportsRecording) {
      return 'Screen recording unavailable on this device';
    }
    final activeReadiness = readiness;
    if (activeReadiness != null && !activeReadiness.canRecord) {
      return activeReadiness.detailLabel;
    }
    return 'AR screen recording unavailable';
  }

  ARCaptureCapability copyWith({
    bool? hasSession,
    bool? supportsSnapshotCapture,
    bool? supportsRecording,
    Object? readiness = _unsetCaptureCapability,
  }) =>
      ARCaptureCapability(
        hasSession: hasSession ?? this.hasSession,
        supportsSnapshotCapture:
            supportsSnapshotCapture ?? this.supportsSnapshotCapture,
        supportsRecording: supportsRecording ?? this.supportsRecording,
        readiness: identical(readiness, _unsetCaptureCapability)
            ? this.readiness
            : readiness as ARSessionReadiness?,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'hasSession': hasSession,
        'supportsSnapshotCapture': supportsSnapshotCapture,
        'supportsRecording': supportsRecording,
        'readiness': readiness?.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      other is ARCaptureCapability &&
      hasSession == other.hasSession &&
      supportsSnapshotCapture == other.supportsSnapshotCapture &&
      supportsRecording == other.supportsRecording &&
      readiness == other.readiness;

  @override
  int get hashCode => Object.hash(
        hasSession,
        supportsSnapshotCapture,
        supportsRecording,
        readiness,
      );

  @override
  String toString() => 'ARCaptureCapability('
      'hasSession:$hasSession '
      'supportsSnapshotCapture:$supportsSnapshotCapture '
      'supportsRecording:$supportsRecording '
      'readiness:${readiness?.level.name})';
}
