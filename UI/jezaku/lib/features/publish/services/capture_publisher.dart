import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

/// What the user chose on the publish form, or the defaults when they save
/// straight from the AR viewer.
class CapturePublishOptions {
  const CapturePublishOptions({
    required this.radiusMeters,
    required this.gpsAccuracyMeters,
    required this.audience,
    required this.allowComments,
    this.caption = '',
    this.wallIds = const <String>[],
    this.recordingQualityReviewed = false,
  });

  /// Settings-driven defaults for a capture that skips the publish form.
  factory CapturePublishOptions.defaults(WidgetRef ref) {
    final session = ref.read(captureSessionProvider);
    final settings = ref.read(appSettingsProvider);
    return CapturePublishOptions(
      radiusMeters: session.anchorRadiusMeters,
      gpsAccuracyMeters: session.activeSnapshot.gpsAccuracyMeters,
      audience: settings.privateByDefault
          ? FrameAudience.private
          : FrameAudience.public,
      allowComments: settings.commentsEnabledByDefault,
    );
  }

  final double radiusMeters;
  final double gpsAccuracyMeters;
  final FrameAudience audience;
  final bool allowComments;
  final String caption;
  final List<String> wallIds;
  final bool recordingQualityReviewed;
}

/// Stores the staged capture's media and adds it to the user's memories.
///
/// Shared by the publish form and the AR viewer's "Publish now" so both write
/// exactly the same record.
AnchorMemory publishCapturedMemory(
  WidgetRef ref,
  CapturePublishOptions options,
) {
  final captureSession = ref.read(captureSessionProvider);
  final settings = ref.read(appSettingsProvider);
  final snapshot = captureSession.activeSnapshot
      .copyWith(gpsAccuracyMeters: options.gpsAccuracyMeters);
  final mediaAttachment =
      ref.read(anchorMediaRepositoryProvider).storeAttachment(
            mediaAttachmentForCapture(
              captureSession,
              recordingQualityReviewed: options.recordingQualityReviewed,
            ),
            storedAt: captureSession.capturedAt,
          );

  final memory = ref.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
        caption: options.caption,
        radiusMeters: options.radiusMeters,
        audience: options.audience,
        allowComments: options.allowComments,
        capturedAt: captureSession.capturedAt,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        altitudeMeters: snapshot.altitudeMeters,
        headingDegrees: snapshot.headingDegrees,
        pitchDegrees: snapshot.pitchDegrees,
        rollDegrees: snapshot.rollDegrees,
        gpsAccuracyMeters: snapshot.gpsAccuracyMeters,
        locationLabel: settings.sharePreciseLocation
            ? snapshot.locationLabel
            : 'Approximate area',
        anchorType: captureSession.anchorTypeLabel,
        captureSource: snapshot.captureSource,
        localPose: captureSession.localPose,
        mediaAttachment: mediaAttachment,
      );
  if (options.wallIds.isNotEmpty) {
    ref.read(arWallsProvider.notifier).linkMemoryToWalls(
          memoryId: memory.id,
          wallIds: List<String>.unmodifiable(options.wallIds),
        );
  }
  ref.read(captureSessionProvider.notifier).clearDraft();
  return memory;
}

AnchorMediaAttachment mediaAttachmentForCapture(
  CaptureSessionState captureSession, {
  bool recordingQualityReviewed = false,
}) {
  final recordingDraft = captureSession.recordingDraft;
  if (recordingDraft != null) {
    return AnchorMediaAttachment(
      type: AnchorMediaType.arRecording,
      filePath: recordingDraft.filePath,
      duration: recordingDraft.duration,
      frameCount: recordingDraft.frameCount,
      targetFps: recordingDraft.targetFps,
      videoBitrateKbps: recordingDraft.videoBitrateKbps,
      outputFormat: recordingDraft.outputFormat,
      includesUIOverlay: recordingDraft.includesUIOverlay,
      includesAudio: recordingDraft.includesAudio,
      fileSizeBytes: recordingDraft.fileSizeBytes,
      recordingQualityReviewedAt:
          recordingDraft.recordingQualityWarningLabel != null &&
                  recordingQualityReviewed
              ? DateTime.now().toUtc()
              : null,
      arDiagnostics: recordingDraft.arDiagnostics,
    );
  }
  final capturedBytes = captureSession.capturedBytes;
  if (capturedBytes != null) {
    return AnchorMediaAttachment(
      type: switch (captureSession.draftSource) {
        CaptureDraftSource.importedPhoto => AnchorMediaType.importedPhoto,
        CaptureDraftSource.arSnapshot => AnchorMediaType.arSnapshot,
        CaptureDraftSource.arRecording => AnchorMediaType.arRecording,
        CaptureDraftSource.camera => AnchorMediaType.cameraPhoto,
      },
      bytes: capturedBytes,
      arDiagnostics: captureSession.arDiagnostics,
    );
  }
  return AnchorMediaAttachment(
    type: switch (captureSession.draftSource) {
      CaptureDraftSource.importedPhoto => AnchorMediaType.importedPhoto,
      CaptureDraftSource.camera ||
      CaptureDraftSource.arSnapshot ||
      CaptureDraftSource.arRecording =>
        AnchorMediaType.cameraPhoto,
    },
  );
}
