import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/services/anchor_spatial_journey_service.dart';
import 'package:jejaku/features/home/services/sample_anchor_service.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

const viewerLatitude = fallbackViewerLatitude;
const viewerLongitude = fallbackViewerLongitude;
const _journeyRadiusMeters = 100.0;
final _sampleMemoryIds = const SampleAnchorService()
    .nearbyAnchors()
    .map((memory) => memory.id)
    .toSet();

final nearbyAnchorsProvider =
    NotifierProvider<AnchorMemoryController, List<AnchorMemory>>(
  AnchorMemoryController.new,
);

final spatialJourneyProvider = Provider<List<AnchorJourneyStep>>((ref) {
  final origin = ref.watch(viewerLocationProvider);
  return const AnchorSpatialJourneyService().stepsFor(
    anchors: ref.watch(nearbyAnchorsProvider),
    originLatitude: origin.latitude,
    originLongitude: origin.longitude,
    useCoordinateDistance: origin.isLive,
    radiusMeters: _journeyRadiusMeters,
  );
});

final spatialJourneyStepProvider =
    Provider.family<AnchorJourneyStep?, String>((ref, memoryId) {
  for (final step in ref.watch(spatialJourneyProvider)) {
    if (step.memory.id == memoryId) {
      return step;
    }
  }
  return null;
});

final pendingSyncMemoriesProvider = Provider<List<AnchorMemory>>((ref) {
  return ref
      .watch(nearbyAnchorsProvider)
      .where((memory) => memory.syncStatus != AnchorSyncStatus.synced)
      .toList();
});

final pendingUploadMemoriesProvider = Provider<List<AnchorMemory>>((ref) {
  return ref
      .watch(nearbyAnchorsProvider)
      .where(
        (memory) =>
            memory.syncStatus != AnchorSyncStatus.synced &&
            memory.syncReason == AnchorSyncReason.newCapture,
      )
      .toList();
});

final pendingMediaUploadMemoriesProvider = Provider<List<AnchorMemory>>((ref) {
  final uploadEntries = ref.watch(anchorMediaUploadQueueProvider);
  return ref
      .watch(pendingUploadMemoriesProvider)
      .where(
        (memory) =>
            memory.hasUploadableMediaPayload &&
            mediaUploadEntryFor(uploadEntries, memory).status !=
                AnchorMediaUploadStatus.uploaded,
      )
      .toList();
});

final pendingMetadataSyncMemoriesProvider = Provider<List<AnchorMemory>>((ref) {
  return ref
      .watch(nearbyAnchorsProvider)
      .where(
        (memory) =>
            memory.syncStatus != AnchorSyncStatus.synced &&
            memory.syncReason == AnchorSyncReason.metadataUpdate,
      )
      .toList();
});

final moderationQueueProvider = Provider<List<AnchorMemory>>((ref) {
  final flaggedMemories = ref
      .watch(nearbyAnchorsProvider)
      .where(
          (memory) => memory.moderationStatus == AnchorModerationStatus.flagged)
      .toList();

  flaggedMemories.sort(_compareModerationPriority);
  return flaggedMemories;
});

final calibrationReviewMemoriesProvider = Provider<List<AnchorMemory>>((ref) {
  final memories = ref
      .watch(nearbyAnchorsProvider)
      .where(
        (memory) =>
            memory.needsCalibrationReview &&
            memory.moderationStatus != AnchorModerationStatus.hidden,
      )
      .toList();
  memories.sort(_compareCalibrationPriority);
  return memories;
});

class AnchorMemoryController extends Notifier<List<AnchorMemory>> {
  @override
  List<AnchorMemory> build() {
    final storedMemories =
        ref.watch(anchorMemoryStoreProvider).loadCapturedMemories();
    final samples = ref.watch(sampleDataEnabledProvider)
        ? const SampleAnchorService().nearbyAnchors()
        : const <AnchorMemory>[];
    return [
      ...storedMemories,
      for (final sample in samples)
        if (!storedMemories.any((memory) => memory.id == sample.id)) sample,
    ];
  }

  AnchorMemory addCapturedMemory({
    required String caption,
    required double radiusMeters,
    required bool isPrivate,
    bool allowComments = true,
    DateTime? capturedAt,
    double latitude = -6.9175,
    double longitude = 107.6191,
    double altitudeMeters = 714.2,
    double headingDegrees = 245,
    double pitchDegrees = -2,
    double rollDegrees = 0.4,
    double gpsAccuracyMeters = 3.2,
    String? locationLabel,
    String anchorType = 'Hybrid geo/orientation',
    String captureSource = 'GPS + compass + gyro',
    AnchorLocalPose? localPose,
    AnchorMediaAttachment? mediaAttachment,
  }) {
    final trimmedCaption = caption.trim();
    final resolvedCapturedAt = capturedAt ?? DateTime.now();
    final radiusLabel = radiusMeters.round();
    // Ids derive from the capture time. Two captures within the same
    // millisecond (burst capture, imports, fast devices) must not collide.
    final takenIds = {for (final existing in state) existing.id};
    var createdAt = resolvedCapturedAt.millisecondsSinceEpoch;
    while (takenIds.contains('captured_$createdAt')) {
      createdAt += 1;
    }

    final memory = AnchorMemory(
      id: 'captured_$createdAt',
      title:
          trimmedCaption.isEmpty ? 'New AR memory' : _titleFrom(trimmedCaption),
      caption: trimmedCaption.isEmpty
          ? 'Captured with a $radiusLabel m anchor radius.'
          : trimmedCaption,
      distanceLabel: '$radiusLabel m radius',
      capturedAgo: 'Just now',
      locationLabel: locationLabel ??
          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
      latitude: latitude,
      longitude: longitude,
      reactions: 0,
      capturedAt: resolvedCapturedAt,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: altitudeMeters,
        headingDegrees: headingDegrees,
        pitchDegrees: pitchDegrees,
        rollDegrees: rollDegrees,
        gpsAccuracyMeters: gpsAccuracyMeters,
        anchorType: anchorType,
        captureSource: captureSource,
        localAnchorPose: localPose,
      ),
      mediaAttachment: mediaAttachment?.detached(),
      isPrivate: isPrivate,
      allowComments: allowComments,
      syncStatus: AnchorSyncStatus.queued,
      syncReason: AnchorSyncReason.newCapture,
    );

    state = [memory, ...state];
    if (memory.hasUploadableMediaPayload) {
      ref
          .read(anchorMediaUploadQueueProvider.notifier)
          .queueMedia(memory, queuedAt: resolvedCapturedAt);
    }
    _persistLocalMemories();
    return memory;
  }

  void deleteMemory(String memoryId) {
    AnchorMemory? deletedMemory;
    final remainingMemories = <AnchorMemory>[];

    for (final memory in state) {
      if (memory.id == memoryId) {
        deletedMemory = memory;
      } else {
        remainingMemories.add(memory);
      }
    }

    if (deletedMemory == null) {
      return;
    }

    state = remainingMemories;
    _releaseDeletedMediaIfUnused(deletedMemory, remainingMemories);
    _persistLocalMemories();
  }

  void _releaseDeletedMediaIfUnused(
    AnchorMemory deletedMemory,
    List<AnchorMemory> remainingMemories,
  ) {
    final attachment = deletedMemory.mediaAttachment;
    if (attachment == null) {
      return;
    }

    final mediaId = attachment.mediaId?.trim();
    final mediaStillReferenced = mediaId != null &&
        mediaId.isNotEmpty &&
        remainingMemories.any(
          (memory) => memory.mediaAttachment?.mediaId?.trim() == mediaId,
        );
    if (mediaStillReferenced) {
      return;
    }

    ref.read(anchorMediaUploadQueueProvider.notifier).removeMedia(
          deletedMemory,
        );
    if (mediaId != null && mediaId.isNotEmpty) {
      ref.read(anchorMediaRepositoryProvider).removeMedia(mediaId);
    }
  }

  void togglePrivacy(String memoryId) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            isPrivate: !memory.isPrivate,
            syncStatus: _syncStatusAfterLocalChange(memory.syncStatus),
            syncReason: _syncReasonAfterLocalChange(memory.syncReason),
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void updateManualCorrection({
    required String memoryId,
    required double eastMeters,
    required double northMeters,
    required double upMeters,
    DateTime? correctedAt,
    String? anchorType,
  }) {
    final hasCorrection = eastMeters != 0 || northMeters != 0 || upMeters != 0;
    final savedAt = hasCorrection ? correctedAt ?? DateTime.now() : null;

    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            captureMetadata: memory.captureMetadata.copyWith(
              correctionEastMeters: eastMeters,
              correctionNorthMeters: northMeters,
              correctionUpMeters: upMeters,
              manualCorrectionSavedAt: savedAt,
              anchorType: anchorType ??
                  (hasCorrection
                      ? 'Manually calibrated geo anchor'
                      : memory.captureMetadata.anchorType),
            ),
            syncStatus: _syncStatusAfterLocalChange(memory.syncStatus),
            syncReason: _syncReasonAfterLocalChange(memory.syncReason),
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void markMemorySynced(String memoryId) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            syncStatus: AnchorSyncStatus.synced,
            syncReason: AnchorSyncReason.none,
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  bool markRecordingQualityReviewed(
    String memoryId, {
    DateTime? reviewedAt,
  }) {
    var didUpdate = false;
    String? reviewedMediaId;
    final resolvedReviewedAt = (reviewedAt ?? DateTime.now()).toUtc();

    state = [
      for (final memory in state)
        if (memory.id == memoryId &&
            memory.mediaAttachment?.needsRecordingQualityReview == true)
          () {
            didUpdate = true;
            final updatedAttachment = memory.mediaAttachment!
                .markRecordingQualityReviewed(resolvedReviewedAt);
            reviewedMediaId = updatedAttachment.mediaId;
            return memory.copyWith(
              mediaAttachment: updatedAttachment,
              syncStatus: _syncStatusAfterLocalChange(memory.syncStatus),
              syncReason: _syncReasonAfterLocalChange(memory.syncReason),
            );
          }()
        else
          memory,
    ];

    if (didUpdate) {
      final mediaId = reviewedMediaId?.trim();
      if (mediaId != null && mediaId.isNotEmpty) {
        ref.read(anchorMediaRepositoryProvider).markRecordingQualityReviewed(
              mediaId,
              resolvedReviewedAt,
            );
      }
      _persistLocalMemories();
    }
    return didUpdate;
  }

  void attachCloudAnchorRecord({
    required String memoryId,
    required String localAnchorId,
    required String cloudAnchorId,
    DateTime? expiresAt,
  }) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            captureMetadata: memory.captureMetadata.copyWith(
              localAnchorId: localAnchorId,
              cloudAnchorId: cloudAnchorId,
              cloudAnchorExpiresAt: expiresAt,
            ),
            syncStatus: _syncStatusAfterLocalChange(memory.syncStatus),
            syncReason: _syncReasonAfterLocalChange(memory.syncReason),
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void retryMemorySync(String memoryId) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(syncStatus: AnchorSyncStatus.queued)
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void markAllPendingSynced() {
    state = [
      for (final memory in state)
        if (memory.syncStatus == AnchorSyncStatus.synced)
          memory
        else
          memory.copyWith(
            syncStatus: AnchorSyncStatus.synced,
            syncReason: AnchorSyncReason.none,
          ),
    ];
    _persistLocalMemories();
  }

  void reportMemory({
    required String memoryId,
    required String reason,
  }) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            moderationStatus: AnchorModerationStatus.flagged,
            reportReason: reason,
            reportCount: memory.reportCount + 1,
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void approveMemory(String memoryId) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            moderationStatus: AnchorModerationStatus.approved,
            reportReason: 'Reviewed and approved',
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void hideMemory(String memoryId) {
    state = [
      for (final memory in state)
        if (memory.id == memoryId)
          memory.copyWith(
            moderationStatus: AnchorModerationStatus.hidden,
            reportReason: memory.reportReason ?? 'Hidden by moderation',
          )
        else
          memory,
    ];
    _persistLocalMemories();
  }

  void _persistLocalMemories() {
    ref.read(anchorMemoryStoreProvider).saveCapturedMemories(
      [
        for (final memory in state)
          if (_shouldPersistMemory(memory)) memory,
      ],
    );
  }

  String _titleFrom(String caption) {
    if (caption.length <= 28) {
      return caption;
    }
    return '${caption.substring(0, 25)}...';
  }

  AnchorSyncStatus _syncStatusAfterLocalChange(AnchorSyncStatus status) {
    return switch (status) {
      AnchorSyncStatus.uploading => AnchorSyncStatus.uploading,
      _ => AnchorSyncStatus.queued,
    };
  }

  AnchorSyncReason _syncReasonAfterLocalChange(AnchorSyncReason reason) {
    return switch (reason) {
      AnchorSyncReason.newCapture => AnchorSyncReason.newCapture,
      _ => AnchorSyncReason.metadataUpdate,
    };
  }
}

bool _shouldPersistMemory(AnchorMemory memory) {
  if (!_sampleMemoryIds.contains(memory.id)) {
    return true;
  }
  return memory.syncStatus != AnchorSyncStatus.synced ||
      memory.syncReason != AnchorSyncReason.none ||
      memory.moderationStatus != AnchorModerationStatus.approved ||
      memory.reportCount > 0 ||
      memory.isPrivate ||
      memory.mediaAttachment?.recordingQualityReviewedAt != null ||
      memory.captureMetadata.hasManualCorrection ||
      memory.captureMetadata.hasCloudAnchor;
}

int _compareModerationPriority(AnchorMemory a, AnchorMemory b) {
  final reportComparison = b.reportCount.compareTo(a.reportCount);
  if (reportComparison != 0) {
    return reportComparison;
  }

  final aTime = a.capturedAt;
  final bTime = b.capturedAt;
  if (aTime == null && bTime == null) {
    return 0;
  }
  if (aTime == null) {
    return 1;
  }
  if (bTime == null) {
    return -1;
  }
  return bTime.compareTo(aTime);
}

int _compareCalibrationPriority(AnchorMemory a, AnchorMemory b) {
  final priorityComparison = b.captureMetadata.calibrationPriorityScore
      .compareTo(a.captureMetadata.calibrationPriorityScore);
  if (priorityComparison != 0) {
    return priorityComparison;
  }

  final issueComparison = b.captureMetadata.calibrationIssueCount
      .compareTo(a.captureMetadata.calibrationIssueCount);
  if (issueComparison != 0) {
    return issueComparison;
  }

  final aTime = a.capturedAt;
  final bTime = b.capturedAt;
  if (aTime == null && bTime == null) {
    return 0;
  }
  if (aTime == null) {
    return 1;
  }
  if (bTime == null) {
    return -1;
  }
  return bTime.compareTo(aTime);
}
