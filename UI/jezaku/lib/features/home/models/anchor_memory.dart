import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';

const _unchanged = Object();

class AnchorMemory {
  const AnchorMemory({
    required this.id,
    required this.title,
    required this.caption,
    required this.distanceLabel,
    required this.capturedAgo,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.reactions,
    required this.captureMetadata,
    this.mediaAttachment,
    this.capturedAt,
    this.syncStatus = AnchorSyncStatus.synced,
    this.syncReason = AnchorSyncReason.none,
    this.moderationStatus = AnchorModerationStatus.approved,
    this.reportReason,
    this.reportCount = 0,
    this.isPrivate = false,
    this.allowComments = true,
    this.hasArExperience = true,
  });

  final String id;
  final String title;
  final String caption;
  final String distanceLabel;
  final String capturedAgo;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final int reactions;
  final AnchorCaptureMetadata captureMetadata;
  final AnchorMediaAttachment? mediaAttachment;
  final DateTime? capturedAt;
  final AnchorSyncStatus syncStatus;
  final AnchorSyncReason syncReason;
  final AnchorModerationStatus moderationStatus;
  final String? reportReason;
  final int reportCount;
  final bool isPrivate;
  final bool allowComments;
  final bool hasArExperience;

  AnchorMemory copyWith({
    String? id,
    String? title,
    String? caption,
    String? distanceLabel,
    String? capturedAgo,
    String? locationLabel,
    double? latitude,
    double? longitude,
    int? reactions,
    AnchorCaptureMetadata? captureMetadata,
    Object? mediaAttachment = _unchanged,
    DateTime? capturedAt,
    AnchorSyncStatus? syncStatus,
    AnchorSyncReason? syncReason,
    AnchorModerationStatus? moderationStatus,
    String? reportReason,
    int? reportCount,
    bool? isPrivate,
    bool? allowComments,
    bool? hasArExperience,
  }) {
    return AnchorMemory(
      id: id ?? this.id,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      capturedAgo: capturedAgo ?? this.capturedAgo,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reactions: reactions ?? this.reactions,
      captureMetadata: captureMetadata ?? this.captureMetadata,
      mediaAttachment: identical(mediaAttachment, _unchanged)
          ? this.mediaAttachment
          : mediaAttachment as AnchorMediaAttachment?,
      capturedAt: capturedAt ?? this.capturedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncReason: syncReason ?? this.syncReason,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      reportReason: reportReason ?? this.reportReason,
      reportCount: reportCount ?? this.reportCount,
      isPrivate: isPrivate ?? this.isPrivate,
      allowComments: allowComments ?? this.allowComments,
      hasArExperience: hasArExperience ?? this.hasArExperience,
    );
  }

  String get capturedTimelineLabel {
    final timestamp = capturedAt;
    if (timestamp == null) {
      return capturedAgo;
    }
    return '$capturedAgo at ${_formatCaptureTime(timestamp)}';
  }

  bool get needsCalibrationReview {
    return captureMetadata.needsCalibration &&
        !captureMetadata.hasManualCorrection;
  }

  String get anchorHealthLabel {
    if (needsCalibrationReview) {
      return 'Needs calibration';
    }
    if (captureMetadata.hasManualCorrection) {
      return 'Calibrated';
    }
    return captureMetadata.qualityLabel;
  }

  String get syncStatusLabel {
    return switch (syncStatus) {
      AnchorSyncStatus.synced => 'Synced',
      AnchorSyncStatus.uploading
          when syncReason == AnchorSyncReason.metadataUpdate =>
        'Updating metadata',
      AnchorSyncStatus.uploading => 'Uploading',
      AnchorSyncStatus.queued
          when syncReason == AnchorSyncReason.metadataUpdate =>
        'Queued update',
      AnchorSyncStatus.queued => 'Queued upload',
      AnchorSyncStatus.failed
          when syncReason == AnchorSyncReason.metadataUpdate =>
        'Update failed',
      AnchorSyncStatus.failed => 'Upload failed',
    };
  }

  String get reportCountLabel {
    return '$reportCount report${reportCount == 1 ? '' : 's'}';
  }

  bool get hasMediaAttachment => mediaAttachment != null;

  bool get hasUploadableMediaPayload =>
      mediaAttachment?.hasUploadablePayload ?? false;

  bool matchesMediaQuery(String query) {
    return mediaAttachment?.matchesQuery(query) ?? false;
  }
}

enum AnchorMediaType {
  cameraPhoto,
  importedPhoto,
  arSnapshot,
  arRecording,
  arModel;

  String get label {
    return switch (this) {
      AnchorMediaType.cameraPhoto => 'Camera photo',
      AnchorMediaType.importedPhoto => 'Imported photo',
      AnchorMediaType.arSnapshot => 'AR snapshot',
      AnchorMediaType.arRecording => 'AR screen recording',
      AnchorMediaType.arModel => '3D AR object',
    };
  }
}

class AnchorMediaAttachment {
  const AnchorMediaAttachment({
    required this.type,
    this.mediaId,
    this.storagePath,
    this.storedAt,
    this.bytes,
    this.filePath,
    this.duration,
    this.frameCount,
    this.targetFps,
    this.videoBitrateKbps,
    this.outputFormat,
    this.includesUIOverlay = true,
    this.includesAudio = false,
    this.fileSizeBytes,
    this.recordingQualityReviewedAt,
    this.arDiagnostics,
    this.modelAsset,
  });

  final AnchorMediaType type;
  final String? mediaId;
  final String? storagePath;
  final DateTime? storedAt;
  final Uint8List? bytes;
  final String? filePath;
  final Duration? duration;
  final int? frameCount;
  final int? targetFps;
  final int? videoBitrateKbps;
  final String? outputFormat;
  final bool includesUIOverlay;
  final bool includesAudio;
  final int? fileSizeBytes;
  final DateTime? recordingQualityReviewedAt;
  final Map<String, Object?>? arDiagnostics;
  final ARModelAsset? modelAsset;

  bool get hasBytes => bytes != null;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  bool get hasLocalPayload =>
      hasBytes ||
      hasFile ||
      (type == AnchorMediaType.arModel &&
          modelAsset?.source == ARModelAssetSource.file);

  bool get isStored => mediaId != null && mediaId!.isNotEmpty;

  bool get hasArDiagnostics =>
      arDiagnostics != null && arDiagnostics!.isNotEmpty;

  bool get hasUploadablePayload {
    if (type != AnchorMediaType.arModel) {
      return true;
    }
    if (hasLocalPayload) {
      return true;
    }
    return modelAsset?.source == ARModelAssetSource.file;
  }

  bool get isMetadataOnlyPayload => !hasUploadablePayload;

  ARCaptureDiagnostics? get arCaptureDiagnostics {
    return ARCaptureDiagnostics.tryFromMap(arDiagnostics);
  }

  AnchorLocalPose? get arDiagnosticsLocalSurfacePose {
    final value = arCaptureDiagnostics?.extra['localSurfacePose'] ??
        arDiagnostics?['localSurfacePose'];
    if (value is! Map) {
      return null;
    }
    return AnchorLocalPose.fromMap(Map<String, Object?>.from(value));
  }

  String? get arDiagnosticsLocalSurfacePoseLabel {
    final label = arCaptureDiagnostics?.extra['localSurfacePoseLabel'] ??
        arDiagnostics?['localSurfacePoseLabel'];
    if (label is String && label.trim().isNotEmpty) {
      return label.trim();
    }
    return arDiagnosticsLocalSurfacePose?.surfaceLabel;
  }

  String? get arDiagnosticsLocalSurfacePoseDetailLabel {
    final pose = arDiagnosticsLocalSurfacePose;
    if (pose == null) {
      return null;
    }
    final details = <String>[
      pose.surfaceTypeLabel,
      if (pose.planeId != null && pose.planeId!.trim().isNotEmpty)
        'Plane ${pose.planeId}',
      'Confidence ${(pose.confidence.clamp(0, 1) * 100).toStringAsFixed(0)}%',
    ];
    return details.join(' - ');
  }

  String get typeLabel => type.label;

  String get summaryLabel => '$typeLabel: $detailLabel';

  String get arDiagnosticsSummaryLabel {
    if (!hasArDiagnostics) {
      return 'No AR diagnostics attached';
    }
    return arCaptureDiagnostics?.summaryLabel ?? 'AR diagnostics attached';
  }

  String get detailLabel {
    if (type == AnchorMediaType.arRecording) {
      return '${durationLabel ?? 'Screen recording clip'} - '
          '${frameCountLabel ?? 'frames pending'}';
    }
    if (type == AnchorMediaType.arModel) {
      return modelAssetLabel ?? 'Model asset pending';
    }
    final byteCount = bytes?.lengthInBytes;
    if (byteCount != null) {
      return _formatBytes(byteCount);
    }
    return switch (type) {
      AnchorMediaType.cameraPhoto => 'Captured in camera',
      AnchorMediaType.importedPhoto => 'Imported from library',
      AnchorMediaType.arSnapshot => 'Captured in AR viewer',
      AnchorMediaType.arRecording => 'Screen recording clip',
      AnchorMediaType.arModel => 'Model asset pending',
    };
  }

  String? get modelAssetLabel {
    final asset = modelAsset;
    if (asset == null) {
      final path = filePath?.trim();
      return path == null || path.isEmpty ? null : _basename(path);
    }
    return '${asset.format.name.toUpperCase()} model: ${_basename(asset.path)}';
  }

  String? get modelFormatLabel {
    final asset = modelAsset;
    if (type != AnchorMediaType.arModel || asset == null) {
      return null;
    }
    return '${asset.format.name.toUpperCase()} model';
  }

  String? get modelSourceLabel {
    final asset = modelAsset;
    if (type != AnchorMediaType.arModel || asset == null) {
      return null;
    }
    return switch (asset.source) {
      ARModelAssetSource.flutterAsset => 'Flutter asset',
      ARModelAssetSource.file => 'Local model file',
      ARModelAssetSource.network => 'Network model',
      ARModelAssetSource.bundle => 'Bundled model',
    };
  }

  String? get modelPathLabel {
    if (type != AnchorMediaType.arModel) {
      return null;
    }
    final path = modelAsset?.path.trim() ?? filePath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }

  String? get modelPackageLabel {
    final package = modelAsset?.package?.trim();
    if (type != AnchorMediaType.arModel || package == null || package.isEmpty) {
      return null;
    }
    return package;
  }

  String? get modelFallbackSizeLabel {
    final size = modelAsset?.fallbackSizeMeters;
    if (type != AnchorMediaType.arModel || size == null) {
      return null;
    }
    return '${_formatMeters(size.x)} x ${_formatMeters(size.y)} x '
        '${_formatMeters(size.z)} m';
  }

  String? get modelOriginLabel {
    final asset = modelAsset;
    if (type != AnchorMediaType.arModel || asset == null) {
      return null;
    }
    return asset.centerOrigin ? 'Centered origin' : 'Preserve model origin';
  }

  String? get modelPayloadLabel {
    if (type != AnchorMediaType.arModel) {
      return null;
    }
    return hasUploadablePayload
        ? 'Model file upload required'
        : 'Model metadata only';
  }

  ARModelAssetValidationReport? get modelValidationReport {
    if (type != AnchorMediaType.arModel) {
      return null;
    }
    return modelAsset?.validate();
  }

  String? get modelValidationLabel {
    return modelValidationReport?.summaryLabel;
  }

  List<String> get modelValidationIssueLabels {
    return modelValidationReport?.issueLabels ?? const <String>[];
  }

  ARModelAssetRenderProfile? get modelRenderProfile {
    if (type != AnchorMediaType.arModel) {
      return null;
    }
    return modelAsset?.renderProfile();
  }

  String? get modelRenderProfileLabel {
    return modelRenderProfile?.summaryLabel;
  }

  List<String> get modelRenderProfilePlatformLabels {
    return modelRenderProfile?.platformLabels ?? const <String>[];
  }

  List<String> get modelRenderProfileNoteLabels {
    return modelRenderProfile?.noteLabels ?? const <String>[];
  }

  String? get modelMetadataKeyLabel {
    final metadata = modelAsset?.metadata;
    if (type != AnchorMediaType.arModel ||
        metadata == null ||
        metadata.isEmpty) {
      return null;
    }
    final keys = metadata.keys.where((key) => key.trim().isNotEmpty).toList()
      ..sort();
    if (keys.isEmpty) {
      return null;
    }
    final keyLabel = keys.length == 1 ? 'metadata key' : 'metadata keys';
    return '${keys.length} $keyLabel: ${keys.join(', ')}';
  }

  String? get durationLabel {
    final duration = this.duration;
    if (duration == null) {
      return null;
    }
    final milliseconds = duration.inMilliseconds;
    if (milliseconds < 1000) {
      return '$milliseconds ms';
    }
    return '${(milliseconds / 1000).toStringAsFixed(1)} s';
  }

  String? get frameCountLabel {
    final frameCount = this.frameCount;
    if (frameCount == null) {
      return null;
    }
    return '$frameCount frame${frameCount == 1 ? '' : 's'}';
  }

  String? get actualFpsLabel {
    final actualFps = actualFpsValue;
    if (actualFps == null) {
      return null;
    }
    return '${actualFps.toStringAsFixed(1)} fps captured';
  }

  double? get actualFpsValue {
    final duration = this.duration;
    final frameCount = this.frameCount;
    if (duration == null || frameCount == null || frameCount <= 0) {
      return null;
    }
    final seconds = duration.inMilliseconds / 1000;
    if (seconds <= 0) {
      return null;
    }
    return frameCount / seconds;
  }

  String? get recordingQualityWarningLabel {
    final actualFps = actualFpsValue;
    final target = targetFps;
    if (type != AnchorMediaType.arRecording ||
        actualFps == null ||
        target == null ||
        target <= 0) {
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
    if (type != AnchorMediaType.arRecording ||
        actualFps == null ||
        target == null ||
        target <= 0) {
      return null;
    }
    return 'Captured ${actualFps.toStringAsFixed(1)} of $target fps target';
  }

  String? get recordingQualityReviewLabel {
    if (type != AnchorMediaType.arRecording ||
        recordingQualityWarningLabel == null) {
      return null;
    }
    return recordingQualityReviewedAt == null
        ? 'Quality review pending'
        : 'Quality review accepted';
  }

  bool get needsRecordingQualityReview {
    return type == AnchorMediaType.arRecording &&
        recordingQualityWarningLabel != null &&
        recordingQualityReviewedAt == null;
  }

  String? get recordingQualityReviewedAtLabel {
    final reviewedAt = recordingQualityReviewedAt;
    if (type != AnchorMediaType.arRecording || reviewedAt == null) {
      return null;
    }
    return 'Reviewed ${_formatCaptureTime(reviewedAt)}';
  }

  List<String> get recordingQualitySearchLabels {
    if (recordingQualityWarningLabel == null) {
      return const <String>[];
    }
    return const <String>[
      'quality issue',
      'recording quality issue',
      'fps issue',
    ];
  }

  String? get targetFpsLabel {
    final targetFps = this.targetFps;
    if (targetFps == null || targetFps <= 0) {
      return null;
    }
    return '$targetFps fps target';
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
    return _formatBytes(bytes);
  }

  List<String> get recordingMetadataLabels {
    if (type != AnchorMediaType.arRecording) {
      return const <String>[];
    }
    return <String>[
      if (targetFpsLabel != null) targetFpsLabel!,
      if (actualFpsLabel != null) actualFpsLabel!,
      if (videoBitrateLabel != null) videoBitrateLabel!,
      if (outputFormatLabel != null) outputFormatLabel!,
      includesUIOverlay ? 'AR visual overlay' : 'Raw AR frame',
      includesAudio ? 'Audio on' : 'Silent',
      if (recordingQualityReviewLabel != null) recordingQualityReviewLabel!,
      if (recordingQualityReviewedAtLabel != null)
        recordingQualityReviewedAtLabel!,
      if (fileSizeLabel != null) fileSizeLabel!,
      if (hasArDiagnostics) 'AR diagnostics attached',
    ];
  }

  List<String> get modelMetadataLabels {
    if (type != AnchorMediaType.arModel) {
      return const <String>[];
    }
    return <String>[
      if (modelFormatLabel != null) modelFormatLabel!,
      if (modelSourceLabel != null) modelSourceLabel!,
      if (modelFallbackSizeLabel != null) modelFallbackSizeLabel!,
      if (modelOriginLabel != null) modelOriginLabel!,
      if (modelPayloadLabel != null) modelPayloadLabel!,
      if (modelValidationLabel != null) modelValidationLabel!,
      ...modelValidationIssueLabels,
      if (modelRenderProfileLabel != null) modelRenderProfileLabel!,
      ...modelRenderProfilePlatformLabels,
      ...modelRenderProfileNoteLabels,
      if (modelPackageLabel != null) modelPackageLabel!,
      if (modelMetadataKeyLabel != null) modelMetadataKeyLabel!,
      if (fileSizeLabel != null) fileSizeLabel!,
      if (modelAssetLabel != null) modelAssetLabel!,
    ];
  }

  List<String> get arDiagnosticsMetadataLabels {
    if (!hasArDiagnostics) {
      return const <String>[];
    }
    return <String>[
      ...(arCaptureDiagnostics?.metadataLabels ??
          const <String>['AR diagnostics attached']),
      if (arDiagnosticsLocalSurfacePoseLabel != null)
        'Local surface: $arDiagnosticsLocalSurfacePoseLabel',
      if (arDiagnosticsLocalSurfacePoseDetailLabel != null)
        arDiagnosticsLocalSurfacePoseDetailLabel!,
    ];
  }

  String get searchLabel {
    final labels = <String>{
      typeLabel,
      detailLabel,
      if (durationLabel != null) durationLabel!,
      if (frameCountLabel != null) frameCountLabel!,
      if (recordingQualityWarningLabel != null) recordingQualityWarningLabel!,
      if (recordingQualityDetailLabel != null) recordingQualityDetailLabel!,
      ...recordingQualitySearchLabels,
      ...recordingMetadataLabels,
      ...modelMetadataLabels,
      ...arDiagnosticsMetadataLabels,
    };
    return labels.map((label) => label.toLowerCase()).join(' ');
  }

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return false;
    }
    return searchLabel.contains(normalizedQuery);
  }

  AnchorMediaAttachment detached() {
    final bytes = this.bytes;
    if (bytes == null && arDiagnostics == null) {
      return this;
    }
    return AnchorMediaAttachment(
      type: type,
      mediaId: mediaId,
      storagePath: storagePath,
      storedAt: storedAt,
      bytes: bytes == null ? null : Uint8List.fromList(bytes),
      filePath: filePath,
      duration: duration,
      frameCount: frameCount,
      targetFps: targetFps,
      videoBitrateKbps: videoBitrateKbps,
      outputFormat: outputFormat,
      includesUIOverlay: includesUIOverlay,
      includesAudio: includesAudio,
      fileSizeBytes: fileSizeBytes,
      recordingQualityReviewedAt: recordingQualityReviewedAt,
      arDiagnostics: _copyJsonMap(arDiagnostics),
      modelAsset: modelAsset,
    );
  }

  AnchorMediaAttachment markRecordingQualityReviewed(DateTime reviewedAt) {
    return AnchorMediaAttachment(
      type: type,
      mediaId: mediaId,
      storagePath: storagePath,
      storedAt: storedAt,
      bytes: bytes,
      filePath: filePath,
      duration: duration,
      frameCount: frameCount,
      targetFps: targetFps,
      videoBitrateKbps: videoBitrateKbps,
      outputFormat: outputFormat,
      includesUIOverlay: includesUIOverlay,
      includesAudio: includesAudio,
      fileSizeBytes: fileSizeBytes,
      recordingQualityReviewedAt: reviewedAt.toUtc(),
      arDiagnostics: arDiagnostics,
      modelAsset: modelAsset,
    );
  }
}

String _basename(String path) {
  final normalized = path.split('?').first;
  final parts = normalized.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? normalized : parts.last;
}

String _formatMeters(double value) {
  return value.toStringAsFixed(2);
}

Map<String, Object?>? _copyJsonMap(Map<String, Object?>? source) {
  if (source == null) {
    return null;
  }
  return Map<String, Object?>.unmodifiable(
    source.map(
      (key, value) => MapEntry<String, Object?>(
        key,
        _copyJsonValue(value),
      ),
    ),
  );
}

Object? _copyJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _copyJsonValue(entry.value),
    });
  }
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_copyJsonValue));
  }
  return value.toString();
}

String _formatBytes(int byteCount) {
  if (byteCount < 1024) {
    return '$byteCount B';
  }
  final kib = byteCount / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

String _formatCaptureTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

enum AnchorModerationStatus {
  approved,
  flagged,
  hidden;

  String get label {
    return switch (this) {
      AnchorModerationStatus.approved => 'Approved',
      AnchorModerationStatus.flagged => 'Flagged for review',
      AnchorModerationStatus.hidden => 'Hidden',
    };
  }
}

enum AnchorSyncStatus {
  queued,
  uploading,
  synced,
  failed;

  String get label {
    return switch (this) {
      AnchorSyncStatus.queued => 'Queued upload',
      AnchorSyncStatus.uploading => 'Uploading',
      AnchorSyncStatus.synced => 'Synced',
      AnchorSyncStatus.failed => 'Upload failed',
    };
  }
}

enum AnchorSyncReason {
  none,
  newCapture,
  metadataUpdate;

  String get label {
    return switch (this) {
      AnchorSyncReason.none => 'No local changes',
      AnchorSyncReason.newCapture => 'New memory upload',
      AnchorSyncReason.metadataUpdate => 'Metadata update',
    };
  }
}

class AnchorCaptureMetadata {
  const AnchorCaptureMetadata({
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.gpsAccuracyMeters,
    required this.anchorType,
    required this.captureSource,
    this.correctionEastMeters = 0,
    this.correctionNorthMeters = 0,
    this.correctionUpMeters = 0,
    this.manualCorrectionSavedAt,
    this.localAnchorId,
    this.localAnchorPose,
    this.cloudAnchorId,
    this.cloudAnchorExpiresAt,
  });

  final double altitudeMeters;
  final double headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;
  final double gpsAccuracyMeters;
  final String anchorType;
  final String captureSource;
  final double correctionEastMeters;
  final double correctionNorthMeters;
  final double correctionUpMeters;
  final DateTime? manualCorrectionSavedAt;
  final String? localAnchorId;
  final AnchorLocalPose? localAnchorPose;
  final String? cloudAnchorId;
  final DateTime? cloudAnchorExpiresAt;

  bool get hasManualCorrection {
    return correctionEastMeters != 0 ||
        correctionNorthMeters != 0 ||
        correctionUpMeters != 0;
  }

  String get manualCorrectionOffsetLabel {
    if (!hasManualCorrection) {
      return 'No manual correction';
    }
    return 'Correction E ${correctionEastMeters.toStringAsFixed(1)} m, '
        'N ${correctionNorthMeters.toStringAsFixed(1)} m, '
        'U ${correctionUpMeters.toStringAsFixed(1)} m';
  }

  String get manualCorrectionSavedLabel {
    final savedAt = manualCorrectionSavedAt;
    if (savedAt == null) {
      return 'Correction not saved';
    }
    return 'Correction saved ${_formatCaptureTime(savedAt)}';
  }

  bool get hasCloudAnchor {
    return localAnchorId != null && cloudAnchorId != null;
  }

  bool get hasLocalPose {
    return localAnchorPose != null;
  }

  String get localPoseStatusLabel {
    final pose = localAnchorPose;
    if (pose == null) {
      return 'Geo/orientation placement';
    }
    return pose.surfaceLabel;
  }

  bool isCloudAnchorExpired({DateTime? now}) {
    final expiresAt = cloudAnchorExpiresAt;
    if (!hasCloudAnchor || expiresAt == null) {
      return false;
    }
    return expiresAt
            .toUtc()
            .difference((now ?? DateTime.now()).toUtc())
            .inMicroseconds <=
        0;
  }

  String cloudAnchorStatusLabel({DateTime? now}) {
    if (!hasCloudAnchor) {
      return 'Local AR anchor';
    }
    final expiresAt = cloudAnchorExpiresAt;
    if (expiresAt == null) {
      return 'Cloud anchor persisted';
    }

    final remaining = expiresAt.toUtc().difference(
          (now ?? DateTime.now()).toUtc(),
        );
    if (remaining.inMicroseconds <= 0) {
      return 'Cloud anchor expired';
    }
    if (remaining.inDays == 0) {
      return 'Cloud anchor expires today';
    }
    if (remaining.inDays == 1) {
      return 'Cloud anchor expires tomorrow';
    }
    return 'Cloud anchor ${remaining.inDays} days left';
  }

  String get qualityLabel {
    if (gpsAccuracyMeters <= 3) {
      return 'High precision';
    }
    if (gpsAccuracyMeters <= 8) {
      return 'Good precision';
    }
    return 'Needs calibration';
  }

  String get accuracyLabel => '+/- ${gpsAccuracyMeters.toStringAsFixed(1)} m';

  String get headingLabel {
    if (!headingDegrees.isFinite) {
      return 'No heading';
    }
    return '${headingDegrees.toStringAsFixed(0)} deg $directionLabel';
  }

  String get directionLabel {
    if (!headingDegrees.isFinite) {
      return 'Unknown';
    }
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalizedHeading = headingDegrees % 360;
    final index = ((normalizedHeading + 22.5) / 45).floor() % directions.length;
    return directions[index];
  }

  String get attitudeLabel {
    return '${pitchDegrees.toStringAsFixed(1)} deg / '
        '${rollDegrees.toStringAsFixed(1)} deg';
  }

  String get calibrationReasonLabel {
    final reasons = calibrationReasonLabels;
    if (reasons.isEmpty) {
      return 'Placement aligned';
    }
    return reasons.join(' - ');
  }

  String get calibrationIssueCountLabel {
    final count = calibrationIssueCount;
    return '$count placement issue${count == 1 ? '' : 's'}';
  }

  int get calibrationIssueCount => calibrationReasonLabels.length;

  int get calibrationPriorityScore {
    return (hasGpsDrift ? 3 : 0) +
        (hasCompassDrift ? 2 : 0) +
        (hasTiltDrift ? 1 : 0);
  }

  AnchorCalibrationSuggestion get suggestedCorrection {
    if (calibrationIssueCount > 1) {
      return const AnchorCalibrationSuggestion(
        title: 'Multi-sensor correction',
        description: 'Balances GPS drift, compass alignment, and tilt cleanup.',
        eastMeters: 2.0,
        northMeters: -0.8,
        upMeters: 0.6,
      );
    }
    if (hasGpsDrift) {
      return const AnchorCalibrationSuggestion(
        title: 'GPS drift correction',
        description: 'Nudges the anchor back toward the capture point.',
        eastMeters: 1.5,
        northMeters: -0.5,
        upMeters: 0.3,
      );
    }
    if (hasCompassDrift) {
      return const AnchorCalibrationSuggestion(
        title: 'Compass alignment correction',
        description: 'Offsets the anchor laterally while compass is reviewed.',
        eastMeters: 0.8,
        northMeters: 0.8,
        upMeters: 0,
      );
    }
    if (hasTiltDrift) {
      return const AnchorCalibrationSuggestion(
        title: 'Leveling correction',
        description: 'Raises the anchor slightly to compensate for high tilt.',
        eastMeters: 0,
        northMeters: 0.4,
        upMeters: 0.6,
      );
    }
    return const AnchorCalibrationSuggestion(
      title: 'Standard alignment correction',
      description: 'Applies a small manual nudge for visual alignment.',
      eastMeters: 1.5,
      northMeters: -0.5,
      upMeters: 0.3,
    );
  }

  List<String> get calibrationReasonLabels {
    return [
      if (hasGpsDrift) 'GPS drift high',
      if (hasCompassDrift) 'Compass unavailable',
      if (hasTiltDrift) 'High tilt',
    ];
  }

  String get calibrationGuidanceLabel {
    if (hasGpsDrift) {
      return 'Move near open sky for better GPS.';
    }
    if (hasCompassDrift) {
      return 'Rotate slowly until compass locks.';
    }
    if (hasTiltDrift) {
      return 'Level the phone before capture.';
    }
    return 'Anchor placement is ready.';
  }

  bool get needsCalibration {
    return hasGpsDrift || hasCompassDrift || hasTiltDrift;
  }

  bool get hasGpsDrift => gpsAccuracyMeters > 8;

  bool get hasCompassDrift => !headingDegrees.isFinite;

  bool get hasTiltDrift => _attitudeNeedsCalibration;

  bool get _attitudeNeedsCalibration {
    return pitchDegrees.abs() > 10 || rollDegrees.abs() > 6;
  }

  AnchorCaptureMetadata copyWith({
    double? altitudeMeters,
    double? headingDegrees,
    double? pitchDegrees,
    double? rollDegrees,
    double? gpsAccuracyMeters,
    String? anchorType,
    String? captureSource,
    double? correctionEastMeters,
    double? correctionNorthMeters,
    double? correctionUpMeters,
    Object? manualCorrectionSavedAt = _unchanged,
    String? localAnchorId,
    Object? localAnchorPose = _unchanged,
    String? cloudAnchorId,
    DateTime? cloudAnchorExpiresAt,
  }) {
    return AnchorCaptureMetadata(
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      rollDegrees: rollDegrees ?? this.rollDegrees,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      anchorType: anchorType ?? this.anchorType,
      captureSource: captureSource ?? this.captureSource,
      correctionEastMeters: correctionEastMeters ?? this.correctionEastMeters,
      correctionNorthMeters:
          correctionNorthMeters ?? this.correctionNorthMeters,
      correctionUpMeters: correctionUpMeters ?? this.correctionUpMeters,
      manualCorrectionSavedAt: identical(manualCorrectionSavedAt, _unchanged)
          ? this.manualCorrectionSavedAt
          : manualCorrectionSavedAt as DateTime?,
      localAnchorId: localAnchorId ?? this.localAnchorId,
      localAnchorPose: identical(localAnchorPose, _unchanged)
          ? this.localAnchorPose
          : localAnchorPose as AnchorLocalPose?,
      cloudAnchorId: cloudAnchorId ?? this.cloudAnchorId,
      cloudAnchorExpiresAt: cloudAnchorExpiresAt ?? this.cloudAnchorExpiresAt,
    );
  }
}

class AnchorLocalPose {
  const AnchorLocalPose({
    required this.x,
    required this.y,
    required this.z,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
    this.planeId,
    this.surfaceType = 'unknown',
    this.distanceMeters,
    this.confidence = 1,
    this.capturedAt,
  });

  final double x;
  final double y;
  final double z;
  final double qx;
  final double qy;
  final double qz;
  final double qw;
  final String? planeId;
  final String surfaceType;
  final double? distanceMeters;
  final double confidence;
  final DateTime? capturedAt;

  bool get isPlane {
    return surfaceType == 'plane' || surfaceType == 'planeAnchor';
  }

  String get surfaceTypeLabel {
    return switch (surfaceType) {
      'plane' || 'planeAnchor' => 'Tracked plane',
      'estimatedHorizontalPlane' => 'Estimated horizontal plane',
      'estimatedVerticalPlane' => 'Estimated vertical plane',
      'hangingPhotoFrame' => 'Hanging photo frame',
      'featurePoint' => 'Feature point',
      'unknown' => 'Unknown surface',
      _ => surfaceType,
    };
  }

  String get surfaceLabel {
    final distance = distanceMeters;
    final distanceLabel =
        distance == null ? null : '${distance.toStringAsFixed(2)} m';
    final kind = surfaceType == 'hangingPhotoFrame'
        ? 'Hanging frame anchor'
        : isPlane
            ? 'Wall/plane anchor'
            : 'Feature anchor';
    return distanceLabel == null ? kind : '$kind - $distanceLabel';
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'x': x,
      'y': y,
      'z': z,
      'qx': qx,
      'qy': qy,
      'qz': qz,
      'qw': qw,
      'planeId': planeId,
      'surfaceType': surfaceType,
      'distanceMeters': distanceMeters,
      'confidence': confidence,
      'capturedAt': capturedAt?.toIso8601String(),
    };
  }

  factory AnchorLocalPose.fromMap(Map<String, Object?> map) {
    return AnchorLocalPose(
      x: _doubleValue(map['x'], 0),
      y: _doubleValue(map['y'], 0),
      z: _doubleValue(map['z'], 0),
      qx: _doubleValue(map['qx'], 0),
      qy: _doubleValue(map['qy'], 0),
      qz: _doubleValue(map['qz'], 0),
      qw: _doubleValue(map['qw'], 1),
      planeId: map['planeId'] as String?,
      surfaceType: (map['surfaceType'] as String?) ?? 'unknown',
      distanceMeters: _nullableDoubleValue(map['distanceMeters']),
      confidence: _doubleValue(map['confidence'], 1),
      capturedAt: _dateTimeValue(map['capturedAt']),
    );
  }
}

class AnchorCalibrationSuggestion {
  const AnchorCalibrationSuggestion({
    required this.title,
    required this.description,
    required this.eastMeters,
    required this.northMeters,
    required this.upMeters,
  });

  final String title;
  final String description;
  final double eastMeters;
  final double northMeters;
  final double upMeters;

  String get offsetLabel {
    return 'East ${eastMeters.toStringAsFixed(1)} m, '
        'north ${northMeters.toStringAsFixed(1)} m, '
        'up ${upMeters.toStringAsFixed(1)} m';
  }
}

double _doubleValue(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

double? _nullableDoubleValue(Object? value) {
  if (value == null) {
    return null;
  }
  return _doubleValue(value, 0);
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
