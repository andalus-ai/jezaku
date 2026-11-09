import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

Future<void> showAnchorMediaDetailSheet(
  BuildContext context, {
  required AnchorMemory memory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return AnchorMediaDetailSheet(memory: memory);
    },
  );
}

class AnchorMediaDetailSheet extends ConsumerWidget {
  const AnchorMediaDetailSheet({
    super.key,
    required this.memory,
  });

  final AnchorMemory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachment = memory.mediaAttachment;
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));
    final uploadEntries = ref.watch(anchorMediaUploadQueueProvider);
    final uploadEntry =
        attachment == null ? null : mediaUploadEntryFor(uploadEntries, memory);
    final uploadManifest = attachment == null
        ? null
        : AnchorMediaSyncManifest.fromAttachment(
            attachment,
            uploadEntry: uploadEntry,
          );

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: attachment == null
              ? const _NoMediaBody()
              : _MediaDetailBody(
                  memory: memory,
                  attachment: attachment,
                  resolvedMedia: resolvedMedia,
                  uploadManifest: uploadManifest,
                ),
        ),
      ),
    );
  }
}

class _NoMediaBody extends StatelessWidget {
  const _NoMediaBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No media attached'),
    );
  }
}

class _MediaDetailBody extends StatelessWidget {
  const _MediaDetailBody({
    required this.memory,
    required this.attachment,
    required this.resolvedMedia,
    required this.uploadManifest,
  });

  final AnchorMemory memory;
  final AnchorMediaAttachment attachment;
  final AnchorResolvedMedia? resolvedMedia;
  final AnchorMediaSyncManifest? uploadManifest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = memory.captureMetadata;
    final previewBytes = resolvedMedia?.previewBytes;
    final storedByteLength = resolvedMedia?.storedByteLength;
    final mediaId = resolvedMedia?.mediaId ?? attachment.mediaId;
    final storagePath = resolvedMedia?.storagePath ?? attachment.storagePath;
    final filePath = attachment.filePath?.trim();
    final manifest = uploadManifest;
    final uploadErrorMessage = manifest?.errorMessage;
    final arDiagnostics = attachment.arDiagnostics;
    final arCaptureDiagnostics = attachment.arCaptureDiagnostics;
    final localSurfacePoseLabel = attachment.arDiagnosticsLocalSurfacePoseLabel;
    final localSurfacePoseDetailLabel =
        attachment.arDiagnosticsLocalSurfacePoseDetailLabel;

    return ListView(
      key: ValueKey('anchor_media_detail_sheet_${memory.id}'),
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Icon(anchorMediaIconFor(attachment.type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    attachment.detailLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
              ),
              child: previewBytes == null
                  ? _MediaPreviewFallback(attachment: attachment)
                  : Image.memory(
                      previewBytes,
                      key: ValueKey('anchor_media_detail_preview_${memory.id}'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _MediaPreviewFallback(attachment: attachment);
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Media',
          children: [
            _DetailRow(
              icon: Icons.info_outline,
              label: 'Availability',
              value: resolvedMedia?.availabilityLabel ??
                  _attachmentAvailabilityLabel(attachment),
            ),
            if (manifest != null && manifest.requiresUpload)
              _DetailRow(
                icon: _mediaUploadIcon(manifest.uploadStatus),
                label: 'Upload',
                value: '${manifest.uploadStatusLabel} - ${manifest.retryLabel}',
              )
            else if (manifest != null)
              const _DetailRow(
                icon: Icons.check_circle_outline,
                label: 'Upload',
                value: 'No media upload needed',
              ),
            if (manifest?.requiresUpload == true && uploadErrorMessage != null)
              _DetailRow(
                icon: Icons.error_outline,
                label: 'Upload issue',
                value: uploadErrorMessage,
              ),
            if (mediaId != null && mediaId.isNotEmpty)
              _DetailRow(
                icon: Icons.tag_outlined,
                label: 'Media ID',
                value: mediaId,
              ),
            if (storagePath != null && storagePath.isNotEmpty)
              _DetailRow(
                icon: Icons.storage_outlined,
                label: 'Storage',
                value: storagePath,
              ),
            if (storedByteLength != null && storedByteLength > 0)
              _DetailRow(
                icon: Icons.data_object_outlined,
                label: 'Stored size',
                value: _formatBytes(storedByteLength),
              ),
            if (filePath != null && filePath.isNotEmpty)
              _DetailRow(
                icon: Icons.video_file_outlined,
                label: 'Source file',
                value: filePath,
              ),
            if (attachment.recordingQualityWarningLabel != null)
              _DetailRow(
                icon: Icons.warning_amber,
                label: 'Quality',
                value: '${attachment.recordingQualityWarningLabel} - '
                    '${attachment.recordingQualityDetailLabel}',
              ),
            if (attachment.recordingQualityReviewLabel != null)
              _DetailRow(
                icon: Icons.fact_check_outlined,
                label: 'Quality review',
                value: attachment.recordingQualityReviewLabel!,
              ),
            if (attachment.recordingQualityReviewedAtLabel != null)
              _DetailRow(
                icon: Icons.schedule,
                label: 'Reviewed',
                value: attachment.recordingQualityReviewedAtLabel!,
              ),
            if (attachment.targetFpsLabel != null)
              _DetailRow(
                icon: Icons.speed,
                label: 'Target FPS',
                value: attachment.targetFpsLabel!,
              ),
            if (attachment.actualFpsLabel != null)
              _DetailRow(
                icon: Icons.timeline,
                label: 'Captured FPS',
                value: attachment.actualFpsLabel!,
              ),
            if (_recordingEncodingLabel(attachment) != null)
              _DetailRow(
                icon: Icons.movie_creation_outlined,
                label: 'Encoding',
                value: _recordingEncodingLabel(attachment)!,
              ),
            if (attachment.type == AnchorMediaType.arRecording)
              _DetailRow(
                icon: Icons.view_in_ar,
                label: 'Visual',
                value: attachment.includesUIOverlay
                    ? 'AR visual overlay'
                    : 'Raw AR frame',
              ),
            if (attachment.type == AnchorMediaType.arRecording)
              _DetailRow(
                icon: Icons.mic_none,
                label: 'Audio',
                value: attachment.includesAudio ? 'Audio on' : 'Silent',
              ),
            if (attachment.fileSizeLabel != null)
              _DetailRow(
                icon: Icons.data_object_outlined,
                label: 'Recording size',
                value: attachment.fileSizeLabel!,
              ),
          ],
        ),
        if (attachment.type == AnchorMediaType.arModel) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: '3D Object',
            children: [
              if (attachment.modelFormatLabel != null)
                _DetailRow(
                  icon: Icons.view_in_ar_outlined,
                  label: 'Format',
                  value: attachment.modelFormatLabel!,
                ),
              if (attachment.modelSourceLabel != null)
                _DetailRow(
                  icon: Icons.source_outlined,
                  label: 'Source',
                  value: attachment.modelSourceLabel!,
                ),
              if (attachment.modelPathLabel != null)
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Asset path',
                  value: attachment.modelPathLabel!,
                ),
              if (attachment.modelPackageLabel != null)
                _DetailRow(
                  icon: Icons.inventory_outlined,
                  label: 'Package',
                  value: attachment.modelPackageLabel!,
                ),
              if (attachment.modelFallbackSizeLabel != null)
                _DetailRow(
                  icon: Icons.straighten,
                  label: 'Fallback size',
                  value: attachment.modelFallbackSizeLabel!,
                ),
              if (attachment.modelOriginLabel != null)
                _DetailRow(
                  icon: Icons.center_focus_strong_outlined,
                  label: 'Origin',
                  value: attachment.modelOriginLabel!,
                ),
              if (attachment.modelPayloadLabel != null)
                _DetailRow(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Sync payload',
                  value: attachment.modelPayloadLabel!,
                ),
              if (attachment.modelValidationLabel != null)
                _DetailRow(
                  icon: attachment.modelValidationReport?.isValid == true
                      ? Icons.verified_outlined
                      : Icons.error_outline,
                  label: 'Readiness',
                  value: attachment.modelValidationLabel!,
                ),
              for (final issueLabel in attachment.modelValidationIssueLabels)
                _DetailRow(
                  icon: Icons.tips_and_updates_outlined,
                  label: 'Readiness note',
                  value: issueLabel,
                ),
              if (attachment.modelRenderProfileLabel != null)
                _DetailRow(
                  icon: Icons.view_in_ar_outlined,
                  label: 'Render profile',
                  value: attachment.modelRenderProfileLabel!,
                ),
              for (final profileLabel
                  in attachment.modelRenderProfilePlatformLabels)
                _DetailRow(
                  icon: Icons.devices_outlined,
                  label: 'Platform render',
                  value: profileLabel,
                ),
              for (final noteLabel in attachment.modelRenderProfileNoteLabels)
                _DetailRow(
                  icon: Icons.tips_and_updates_outlined,
                  label: 'Render note',
                  value: noteLabel,
                ),
              if (attachment.modelMetadataKeyLabel != null)
                _DetailRow(
                  icon: Icons.data_object_outlined,
                  label: 'Model metadata',
                  value: attachment.modelMetadataKeyLabel!,
                ),
            ],
          ),
        ],
        if (arDiagnostics != null && arDiagnostics.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'AR Diagnostics',
            children: [
              _DetailRow(
                icon: Icons.view_in_ar,
                label: 'Status',
                value: arCaptureDiagnostics?.summaryLabel ??
                    attachment.arDiagnosticsSummaryLabel,
              ),
              if (arCaptureDiagnostics != null) ...[
                _DetailRow(
                  icon: Icons.task_alt,
                  label: 'Readiness',
                  value: arCaptureDiagnostics.sessionReadinessLabel,
                ),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Placement',
                  value: arCaptureDiagnostics.nativePlacementStatusLabel,
                ),
                _DetailRow(
                  icon: Icons.sensors_outlined,
                  label: 'Health',
                  value: arCaptureDiagnostics.sessionHealthStatusLabel,
                ),
                if (arCaptureDiagnostics.captureCapabilityLabel != null)
                  _DetailRow(
                    icon: Icons.verified_outlined,
                    label: 'Capture gate',
                    value: arCaptureDiagnostics.captureCapabilityLabel!,
                  ),
                if (arCaptureDiagnostics.captureReadinessGuidanceLabel != null)
                  _DetailRow(
                    icon: Icons.tips_and_updates_outlined,
                    label: 'Capture hint',
                    value: arCaptureDiagnostics.captureReadinessGuidanceLabel!,
                  ),
                _DetailRow(
                  icon: Icons.sync,
                  label: 'Native sync',
                  value: arCaptureDiagnostics.syncStatusLabel,
                ),
                if (arCaptureDiagnostics.unsupportedSessionFeatureCountLabel !=
                    null)
                  _DetailRow(
                    icon: Icons.extension_off_outlined,
                    label: 'Native limits',
                    value: arCaptureDiagnostics
                        .unsupportedSessionFeatureCountLabel!,
                  ),
                if (arCaptureDiagnostics.hasNativeSceneFailure)
                  const _DetailRow(
                    icon: Icons.sync_problem_outlined,
                    label: 'Native scene',
                    value: 'Native scene sync issue',
                  ),
                if (arCaptureDiagnostics.hasCloudAnchorFailures)
                  const _DetailRow(
                    icon: Icons.cloud_off_outlined,
                    label: 'Cloud anchor',
                    value: 'Cloud anchor issue',
                  ),
                if (localSurfacePoseLabel != null)
                  _DetailRow(
                    icon: Icons.wallpaper_outlined,
                    label: 'Local surface',
                    value: localSurfacePoseLabel,
                  ),
                if (localSurfacePoseDetailLabel != null)
                  _DetailRow(
                    icon: Icons.center_focus_strong_outlined,
                    label: 'Local pose',
                    value: localSurfacePoseDetailLabel,
                  ),
              ] else
                const _DetailRow(
                  icon: Icons.error_outline,
                  label: 'Diagnostics',
                  value: 'Unrecognized AR diagnostics payload',
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey(
                    'anchor_media_ar_diagnostics_copy_button',
                  ),
                  onPressed: () => _copyArDiagnostics(context, arDiagnostics),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy diagnostics'),
                ),
              ),
              _ArDiagnosticsPayloadPreview(diagnostics: arDiagnostics),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Capture',
          children: [
            _DetailRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: memory.locationLabel,
            ),
            _DetailRow(
              icon: Icons.height,
              label: 'Altitude',
              value: '${metadata.altitudeMeters.toStringAsFixed(1)} m',
            ),
            _DetailRow(
              icon: Icons.navigation,
              label: 'Heading',
              value: metadata.headingLabel,
            ),
            _DetailRow(
              icon: Icons.screen_rotation_alt,
              label: 'Pitch / Roll',
              value: metadata.attitudeLabel,
            ),
            _DetailRow(
              icon: Icons.gps_fixed,
              label: 'Accuracy',
              value: '${metadata.accuracyLabel} - ${metadata.qualityLabel}',
            ),
            _DetailRow(
              icon: Icons.view_in_ar,
              label: 'Anchor',
              value: metadata.anchorType,
            ),
            _DetailRow(
              icon: Icons.sensors_outlined,
              label: 'Source',
              value: metadata.captureSource,
            ),
            _DetailRow(
              icon: Icons.tune,
              label: 'Calibration',
              value: metadata.hasManualCorrection
                  ? '${metadata.manualCorrectionOffsetLabel}. '
                      '${metadata.manualCorrectionSavedLabel}'
                  : metadata.calibrationReasonLabel,
            ),
            _DetailRow(
              icon: Icons.cloud_outlined,
              label: 'Cloud anchor',
              value: metadata.cloudAnchorStatusLabel(),
            ),
            _DetailRow(
              icon: Icons.schedule,
              label: 'Captured',
              value: memory.capturedTimelineLabel,
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaPreviewFallback extends StatelessWidget {
  const _MediaPreviewFallback({required this.attachment});

  final AnchorMediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            anchorMediaIconFor(attachment.type),
            color: colorScheme.onSurfaceVariant,
            size: 54,
          ),
          const SizedBox(height: 8),
          Text(
            attachment.type == AnchorMediaType.arRecording
                ? 'Screen recording clip'
                : attachment.typeLabel,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ArDiagnosticsPayloadPreview extends StatelessWidget {
  const _ArDiagnosticsPayloadPreview({required this.diagnostics});

  final Map<String, Object?> diagnostics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final encoded = const JsonEncoder.withIndent('  ').convert(diagnostics);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: const ValueKey('anchor_media_ar_diagnostics_payload_tile'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.data_object_outlined,
            color: colorScheme.primary,
          ),
          title: const Text(
            'Raw payload',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 8),
                child: SelectableText(
                  encoded,
                  key: const ValueKey(
                    'anchor_media_ar_diagnostics_payload_json',
                  ),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _attachmentAvailabilityLabel(AnchorMediaAttachment attachment) {
  if (attachment.hasBytes) {
    return 'Preview attached';
  }
  if (attachment.hasFile) {
    return 'File-backed media';
  }
  if (attachment.isStored) {
    return 'Stored media';
  }
  return 'Media pending';
}

IconData _mediaUploadIcon(AnchorMediaUploadStatus status) {
  return switch (status) {
    AnchorMediaUploadStatus.queued => Icons.cloud_queue,
    AnchorMediaUploadStatus.uploading => Icons.sync,
    AnchorMediaUploadStatus.uploaded => Icons.cloud_done,
    AnchorMediaUploadStatus.failed => Icons.error_outline,
  };
}

String? _recordingEncodingLabel(AnchorMediaAttachment attachment) {
  final labels = <String>[
    if (attachment.outputFormatLabel != null) attachment.outputFormatLabel!,
    if (attachment.videoBitrateLabel != null) attachment.videoBitrateLabel!,
  ];
  if (labels.isEmpty) {
    return null;
  }
  return labels.join(' - ');
}

Future<void> _copyArDiagnostics(
  BuildContext context,
  Map<String, Object?> diagnostics,
) async {
  final encoded = const JsonEncoder.withIndent('  ').convert(diagnostics);
  await Clipboard.setData(ClipboardData(text: encoded));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(content: Text('AR diagnostics copied')),
    );
}

String _formatBytes(int byteLength) {
  if (byteLength < 1024) {
    return '$byteLength B';
  }
  final kib = byteLength / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}
