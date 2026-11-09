import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final TextEditingController _captionController = TextEditingController();
  double _radius = 30;
  double _gpsAccuracy = 3.2;
  bool _isPrivate = false;
  bool _allowComments = true;
  bool _acceptedPlacementReview = false;
  bool _acceptedRecordingQualityReview = false;
  final _selectedWallIds = <String>{};

  @override
  void initState() {
    super.initState();
    final captureSession = ref.read(captureSessionProvider);
    final settings = ref.read(appSettingsProvider);
    _gpsAccuracy = captureSession.activeSnapshot.gpsAccuracyMeters;
    _radius = captureSession.anchorRadiusMeters;
    _isPrivate = settings.privateByDefault;
    _allowComments = settings.commentsEnabledByDefault;
  }

  @override
  Widget build(BuildContext context) {
    final captureSession = ref.watch(captureSessionProvider);
    final captureSnapshot =
        captureSession.activeSnapshot.copyWith(gpsAccuracyMeters: _gpsAccuracy);
    final recordingDraft = captureSession.recordingDraft;
    final hasRecordingQualityWarning =
        recordingDraft?.recordingQualityWarningLabel != null;
    final needsPlacementReview = captureSnapshot.captureReadinessLevel ==
            CaptureReadinessLevel.calibrate &&
        !_acceptedPlacementReview;
    final needsRecordingQualityReview =
        hasRecordingQualityWarning && !_acceptedRecordingQualityReview;
    final walls = ref.watch(arWallsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish Memory'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          _CapturePreview(
            captureSession: captureSession,
            recordingQualityReviewAccepted: _acceptedRecordingQualityReview,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('publish_caption_field'),
            controller: _captionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Anchor radius: ${_radius.round()} m',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            min: 5,
            max: 100,
            divisions: 19,
            value: _radius,
            label: '${_radius.round()} m',
            onChanged: (value) => setState(() => _radius = value),
          ),
          if (walls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PublishWallLinkPanel(
              walls: walls,
              selectedWallIds: _selectedWallIds,
              onToggleWall: _toggleWall,
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('private_memory_switch'),
            title: const Text('Private memory'),
            subtitle: const Text('Only approved viewers can see this anchor.'),
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
          ),
          SwitchListTile(
            key: const ValueKey('allow_comments_switch'),
            title: const Text('Allow comments'),
            value: _allowComments,
            onChanged: (value) => setState(() => _allowComments = value),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Capture Metadata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _PlacementConfidencePanel(snapshot: captureSnapshot),
                  const SizedBox(height: 12),
                  _MetadataRow(
                    key: const ValueKey('capture_state_row'),
                    icon: Icons.radio_button_checked,
                    label: 'Capture State',
                    value: captureSession.statusLabel,
                  ),
                  _MetadataRow(
                    icon: Icons.view_in_ar,
                    label: 'Anchor Plan',
                    value:
                        '${captureSession.anchorPreset.label} - ${_radius.round()} m',
                  ),
                  _MetadataRow(
                    icon: Icons.schedule,
                    label: 'Captured',
                    value: captureSession.captureTimeLabel,
                  ),
                  _MetadataRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: captureSnapshot.locationLabel,
                  ),
                  _MetadataRow(
                    icon: Icons.height,
                    label: 'Altitude',
                    value:
                        '${captureSnapshot.altitudeMeters.toStringAsFixed(1)} m',
                  ),
                  _MetadataRow(
                    icon: Icons.navigation,
                    label: 'Heading',
                    value: captureSnapshot.headingLabel,
                  ),
                  _MetadataRow(
                    icon: Icons.screen_rotation_alt,
                    label: 'Pitch / Roll',
                    value: captureSnapshot.attitudeLabel,
                  ),
                  _MetadataRow(
                    icon: Icons.sensors_outlined,
                    label: 'Source',
                    value: captureSnapshot.captureSource,
                  ),
                  if (captureSession.localPose != null)
                    _MetadataRow(
                      icon: Icons.wallpaper,
                      label: 'AR Surface',
                      value: captureSession.localPose!.surfaceLabel,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.gps_fixed, size: 18),
                        label: Text(captureSnapshot.accuracyLabel),
                      ),
                      Chip(
                        avatar: const Icon(Icons.verified_outlined, size: 18),
                        label: Text(captureSnapshot.qualityLabel),
                      ),
                    ],
                  ),
                  if (captureSnapshot.captureReadinessLevel ==
                      CaptureReadinessLevel.calibrate) ...[
                    const SizedBox(height: 8),
                    _PlacementReviewPanel(
                      snapshot: captureSnapshot,
                      accepted: _acceptedPlacementReview,
                      onImproveFix: _improveLocationFix,
                      onUseAnyway: () {
                        setState(() => _acceptedPlacementReview = true);
                      },
                    ),
                  ],
                  if (recordingDraft?.recordingQualityWarningLabel != null) ...[
                    const SizedBox(height: 8),
                    _RecordingQualityReviewPanel(
                      draft: recordingDraft!,
                      accepted: _acceptedRecordingQualityReview,
                      onUseAnyway: () {
                        setState(() {
                          _acceptedRecordingQualityReview = true;
                        });
                      },
                    ),
                  ],
                  Slider(
                    key: const ValueKey('gps_accuracy_slider'),
                    min: 1,
                    max: 15,
                    divisions: 28,
                    value: _gpsAccuracy,
                    label: '+/- ${_gpsAccuracy.toStringAsFixed(1)} m',
                    onChanged: _setGpsAccuracy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: needsPlacementReview
              ? _requestPlacementReview
              : needsRecordingQualityReview
                  ? _requestRecordingQualityReview
                  : _publish,
          icon: Icon(
            needsPlacementReview || needsRecordingQualityReview
                ? Icons.warning_amber
                : Icons.cloud_upload,
          ),
          label: Text(
            _publishButtonLabel(
              captureSnapshot,
              hasRecordingQualityWarning: hasRecordingQualityWarning,
            ),
          ),
        ),
      ),
    );
  }

  String _publishButtonLabel(
    CaptureSensorSnapshot snapshot, {
    required bool hasRecordingQualityWarning,
  }) {
    final needsPlacementCalibration =
        snapshot.captureReadinessLevel == CaptureReadinessLevel.calibrate;
    if (needsPlacementCalibration && !_acceptedPlacementReview) {
      return 'Review Placement';
    }
    if (hasRecordingQualityWarning && !_acceptedRecordingQualityReview) {
      return 'Review Recording';
    }
    if (needsPlacementCalibration || hasRecordingQualityWarning) {
      return 'Publish Anyway';
    }
    return 'Publish';
  }

  void _setGpsAccuracy(double value) {
    setState(() {
      _gpsAccuracy = value;
      _acceptedPlacementReview = false;
    });
    ref.read(captureSessionProvider.notifier).updateGpsAccuracy(value);
  }

  void _improveLocationFix() {
    _setGpsAccuracy(6);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location fix improved.')),
    );
  }

  void _requestPlacementReview() {
    final captureSession = ref.read(captureSessionProvider);
    final captureSnapshot =
        captureSession.activeSnapshot.copyWith(gpsAccuracyMeters: _gpsAccuracy);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Review capture placement before publishing. '
          '${captureSnapshot.captureGuidanceLabel}',
        ),
      ),
    );
  }

  void _requestRecordingQualityReview() {
    final recordingDraft = ref.read(captureSessionProvider).recordingDraft;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recordingDraft == null
              ? 'Review recording quality before publishing.'
              : 'Review recording quality before publishing. '
                  '${recordingDraft.recordingQualityDetailLabel}',
        ),
      ),
    );
  }

  void _toggleWall(String wallId, bool selected) {
    setState(() {
      if (selected) {
        _selectedWallIds.add(wallId);
      } else {
        _selectedWallIds.remove(wallId);
      }
    });
  }

  void _publish() {
    final captureSession = ref.read(captureSessionProvider);
    final settings = ref.read(appSettingsProvider);
    final captureSnapshot =
        captureSession.activeSnapshot.copyWith(gpsAccuracyMeters: _gpsAccuracy);
    final mediaAttachment =
        ref.read(anchorMediaRepositoryProvider).storeAttachment(
              _mediaAttachmentFor(captureSession),
              storedAt: captureSession.capturedAt,
            );

    final memory = ref.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: _captionController.text,
          radiusMeters: _radius,
          isPrivate: _isPrivate,
          allowComments: _allowComments,
          capturedAt: captureSession.capturedAt,
          latitude: captureSnapshot.latitude,
          longitude: captureSnapshot.longitude,
          altitudeMeters: captureSnapshot.altitudeMeters,
          headingDegrees: captureSnapshot.headingDegrees,
          pitchDegrees: captureSnapshot.pitchDegrees,
          rollDegrees: captureSnapshot.rollDegrees,
          gpsAccuracyMeters: captureSnapshot.gpsAccuracyMeters,
          locationLabel: settings.sharePreciseLocation
              ? captureSnapshot.locationLabel
              : 'Approximate area',
          anchorType: captureSession.anchorTypeLabel,
          captureSource: captureSnapshot.captureSource,
          localPose: captureSession.localPose,
          mediaAttachment: mediaAttachment,
        );
    if (_selectedWallIds.isNotEmpty) {
      ref.read(arWallsProvider.notifier).linkMemoryToWalls(
            memoryId: memory.id,
            wallIds: List<String>.unmodifiable(_selectedWallIds),
          );
    }
    ref.read(captureSessionProvider.notifier).clearDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedWallIds.isEmpty
              ? 'Memory queued for upload.'
              : 'Memory queued and linked to ${_selectedWallIds.length} wall${_selectedWallIds.length == 1 ? '' : 's'}.',
        ),
      ),
    );
    Navigator.pop(context, memory.id);
  }

  AnchorMediaAttachment _mediaAttachmentFor(
    CaptureSessionState captureSession,
  ) {
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
                    _acceptedRecordingQualityReview
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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}

class _CapturePreview extends StatelessWidget {
  const _CapturePreview({
    required this.captureSession,
    required this.recordingQualityReviewAccepted,
  });

  final CaptureSessionState captureSession;
  final bool recordingQualityReviewAccepted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = captureSession.capturedBytes;
    final recordingDraft = captureSession.recordingDraft;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
          ),
          child: recordingDraft != null
              ? _RecordingPreview(
                  draft: recordingDraft,
                  qualityReviewAccepted: recordingQualityReviewAccepted,
                )
              : bytes == null
                  ? const Center(child: Icon(Icons.photo_camera, size: 64))
                  : Image.memory(
                      bytes,
                      key: const ValueKey('publish_capture_preview_image'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image_outlined, size: 64),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _RecordingPreview extends StatelessWidget {
  const _RecordingPreview({
    required this.draft,
    required this.qualityReviewAccepted,
  });

  final CaptureRecordingDraft draft;
  final bool qualityReviewAccepted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      key: const ValueKey('publish_recording_preview'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_file_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              draft.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              draft.detailLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _RecordingHealthSummary(
              draft: draft,
              qualityReviewAccepted: qualityReviewAccepted,
            ),
            if (draft.recordingQualityWarningLabel != null) ...[
              const SizedBox(height: 10),
              _RecordingQualityNotice(draft: draft),
            ],
            if (draft.metadataLabels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in draft.metadataLabels)
                    _RecordingMetadataChip(label: label),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              draft.filePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingHealthSummary extends StatelessWidget {
  const _RecordingHealthSummary({
    required this.draft,
    required this.qualityReviewAccepted,
  });

  final CaptureRecordingDraft draft;
  final bool qualityReviewAccepted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final needsReview =
        draft.recordingQualityWarningLabel != null && !qualityReviewAccepted;
    final label =
        draft.recordingQualityWarningLabel != null && qualityReviewAccepted
            ? 'Recording quality accepted'
            : draft.recordingHealthStatusLabel;
    final backgroundColor =
        needsReview ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final foregroundColor = needsReview
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              needsReview
                  ? Icons.warning_amber_rounded
                  : Icons.verified_outlined,
              color: foregroundColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label - ${draft.recordingHealthDetailLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingQualityNotice extends StatelessWidget {
  const _RecordingQualityNotice({required this.draft});

  final CaptureRecordingDraft draft;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber,
              size: 16,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${draft.recordingQualityWarningLabel} - '
                '${draft.recordingQualityDetailLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingQualityReviewPanel extends StatelessWidget {
  const _RecordingQualityReviewPanel({
    required this.draft,
    required this.accepted,
    required this.onUseAnyway,
  });

  final CaptureRecordingDraft draft;
  final bool accepted;
  final VoidCallback onUseAnyway;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: colorScheme.onErrorContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    accepted
                        ? 'Recording quality review accepted'
                        : 'Recording quality needs review',
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${draft.recordingQualityWarningLabel}: '
              '${draft.recordingQualityDetailLabel}',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: accepted ? null : onUseAnyway,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Use Anyway'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingMetadataChip extends StatelessWidget {
  const _RecordingMetadataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _PlacementConfidencePanel extends StatelessWidget {
  const _PlacementConfidencePanel({required this.snapshot});

  final CaptureSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Placement Confidence',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(
                  key: const ValueKey('placement_confidence_chip'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.insights_outlined, size: 16),
                  label: Text(snapshot.placementConfidencePercentLabel),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.placementConfidenceLabel,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _ConfidenceFactorRow(
              icon: Icons.gps_fixed,
              label: 'GPS',
              value: '${snapshot.qualityLabel} ${snapshot.accuracyLabel}',
            ),
            _ConfidenceFactorRow(
              icon: Icons.navigation,
              label: 'Heading',
              value: snapshot.compassLabel,
            ),
            _ConfidenceFactorRow(
              icon: Icons.screen_rotation_alt,
              label: 'Level',
              value: '${snapshot.attitudeStabilityLabel} '
                  '${snapshot.attitudeLabel}',
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishWallLinkPanel extends StatelessWidget {
  const _PublishWallLinkPanel({
    required this.walls,
    required this.selectedWallIds,
    required this.onToggleWall,
  });

  final List<ARWall> walls;
  final Set<String> selectedWallIds;
  final void Function(String wallId, bool selected) onToggleWall;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCount = selectedWallIds.length;

    return Card(
      key: const ValueKey('publish_wall_link_panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Virtual Wall',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.grid_view, size: 16),
                  label: Text('$selectedCount selected'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Link this memory to collaborative wall context.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wall in walls)
                  FilterChip(
                    key: ValueKey('publish_wall_${wall.id}'),
                    avatar: Icon(
                      wall.isPublic ? Icons.public : Icons.group,
                      size: 18,
                    ),
                    label: Text(wall.title),
                    selected: selectedWallIds.contains(wall.id),
                    onSelected: (selected) => onToggleWall(wall.id, selected),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceFactorRow extends StatelessWidget {
  const _ConfidenceFactorRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PlacementReviewPanel extends StatelessWidget {
  const _PlacementReviewPanel({
    required this.snapshot,
    required this.accepted,
    required this.onImproveFix,
    required this.onUseAnyway,
  });

  final CaptureSensorSnapshot snapshot;
  final bool accepted;
  final VoidCallback onImproveFix;
  final VoidCallback onUseAnyway;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canImproveGps = snapshot.gpsAccuracyMeters > 8;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: colorScheme.onErrorContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    accepted
                        ? 'Placement review accepted'
                        : 'Placement needs calibration',
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${snapshot.captureReadinessLabel}: '
              '${snapshot.captureGuidanceLabel}',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 4),
            Text(
              'GPS ${snapshot.accuracyLabel} - '
              '${snapshot.compassStabilityLabel} - '
              '${snapshot.attitudeStabilityLabel}.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: canImproveGps ? onImproveFix : null,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Improve GPS'),
                ),
                TextButton.icon(
                  onPressed: accepted ? null : onUseAnyway,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Use Anyway'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
