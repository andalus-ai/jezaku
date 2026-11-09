import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_media_detail_sheet.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:jejaku/features/sync/services/anchor_sync_coordinator.dart';
import 'package:jejaku/features/sync/services/anchor_sync_payload_builder_provider.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';
import 'package:jejaku/features/sync/states/anchor_sync_delivery_log_provider.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

enum _SyncQueueFilter { all, uploads, media, metadata, quality }

class SyncQueueScreen extends ConsumerStatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  ConsumerState<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends ConsumerState<SyncQueueScreen> {
  _SyncQueueFilter _selectedFilter = _SyncQueueFilter.all;

  @override
  Widget build(BuildContext context) {
    final pendingMemories = ref.watch(pendingSyncMemoriesProvider);
    final uploadMemories = ref.watch(pendingUploadMemoriesProvider);
    final mediaMemories = ref.watch(pendingMediaUploadMemoriesProvider);
    final metadataMemories = ref.watch(pendingMetadataSyncMemoriesProvider);
    final qualityMemories = pendingMemories
        .where((memory) => _hasRecordingQualityIssue(memory))
        .toList();
    final pendingQualityReviewMemories = qualityMemories
        .where(
          (memory) =>
              memory.mediaAttachment?.needsRecordingQualityReview == true,
        )
        .toList();
    final syncRuntime = ref.watch(localFirstSyncRuntimeProvider);
    final deliveryEntries = ref.watch(anchorSyncDeliveryLogProvider);
    final filteredMemories = switch (_selectedFilter) {
      _SyncQueueFilter.all => pendingMemories,
      _SyncQueueFilter.uploads => uploadMemories,
      _SyncQueueFilter.media => mediaMemories,
      _SyncQueueFilter.metadata => metadataMemories,
      _SyncQueueFilter.quality => qualityMemories,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Queue'),
        actions: [
          if (pendingMemories.isNotEmpty)
            TextButton(
              onPressed: () => _syncAll(
                context,
                pendingMemories,
              ),
              child: const Text('Sync All'),
            ),
        ],
      ),
      body: pendingMemories.isEmpty
          ? _EmptySyncState(
              deliveryEntries: deliveryEntries,
              onClearDeliveryLog: _clearDeliveryLog,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _LocalFirstSyncBanner(
                    runtime: syncRuntime,
                    pendingCount: pendingMemories.length,
                  ),
                ),
                if (deliveryEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SyncDeliveryLedgerPanel(
                      entries: deliveryEntries,
                      onClear: _clearDeliveryLog,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _SyncQueueFilters(
                    selectedFilter: _selectedFilter,
                    allCount: pendingMemories.length,
                    uploadCount: uploadMemories.length,
                    mediaCount: mediaMemories.length,
                    metadataCount: metadataMemories.length,
                    qualityCount: qualityMemories.length,
                    pendingQualityReviewCount:
                        pendingQualityReviewMemories.length,
                    onUploadMediaPayloads: mediaMemories.isEmpty
                        ? null
                        : () => _uploadMediaPayloads(
                              context,
                              mediaMemories,
                            ),
                    onSyncUploads: uploadMemories.isEmpty
                        ? null
                        : () => _markUploadsSynced(
                              context,
                              uploadMemories,
                            ),
                    onSyncMetadataUpdates: metadataMemories.isEmpty
                        ? null
                        : () => _markMetadataUpdatesSynced(
                              context,
                              metadataMemories,
                            ),
                    onAcceptPendingQualityReviews:
                        pendingQualityReviewMemories.isEmpty
                            ? null
                            : () => _acceptPendingQualityReviews(
                                  context,
                                  pendingQualityReviewMemories,
                                ),
                    onChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filteredMemories.isEmpty
                      ? _FilteredEmptySyncState(filter: _selectedFilter)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: filteredMemories.length,
                          itemBuilder: (context, index) {
                            final memory = filteredMemories[index];
                            return _SyncMemoryCard(memory: memory);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _syncAll(
    BuildContext context,
    List<AnchorMemory> pendingMemories,
  ) {
    _showOutcome(
      context,
      ref.read(anchorSyncCoordinatorProvider).syncAll(pendingMemories),
    );
  }

  void _uploadMediaPayloads(
    BuildContext context,
    List<AnchorMemory> mediaMemories,
  ) {
    _showOutcome(
      context,
      ref
          .read(anchorSyncCoordinatorProvider)
          .uploadMediaPayloads(mediaMemories),
    );
  }

  void _markUploadsSynced(
    BuildContext context,
    List<AnchorMemory> uploadMemories,
  ) {
    _showOutcome(
      context,
      ref.read(anchorSyncCoordinatorProvider).markUploadsSynced(uploadMemories),
    );
  }

  void _markMetadataUpdatesSynced(
    BuildContext context,
    List<AnchorMemory> metadataMemories,
  ) {
    _showOutcome(
      context,
      ref
          .read(anchorSyncCoordinatorProvider)
          .markMetadataUpdatesSynced(metadataMemories),
    );
  }

  void _acceptPendingQualityReviews(
    BuildContext context,
    List<AnchorMemory> memories,
  ) {
    final controller = ref.read(nearbyAnchorsProvider.notifier);
    final reviewedAt = DateTime.now().toUtc();
    var acceptedCount = 0;
    for (final memory in memories) {
      final didUpdate = controller.markRecordingQualityReviewed(
        memory.id,
        reviewedAt: reviewedAt,
      );
      if (didUpdate) {
        acceptedCount += 1;
      }
    }

    final reviewLabel = acceptedCount == 1 ? 'review' : 'reviews';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            acceptedCount == 0
                ? 'Recording quality reviews are already current.'
                : '$acceptedCount recording quality $reviewLabel accepted.',
          ),
        ),
      );
  }

  void _showOutcome(BuildContext context, AnchorSyncOutcome outcome) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(outcome.message),
        ),
      );
  }

  void _clearDeliveryLog() {
    ref.read(anchorSyncDeliveryLogProvider.notifier).clear();
  }
}

bool _hasRecordingQualityIssue(AnchorMemory memory) {
  return memory.mediaAttachment?.recordingQualityWarningLabel != null;
}

class _LocalFirstSyncBanner extends StatelessWidget {
  const _LocalFirstSyncBanner({
    required this.runtime,
    required this.pendingCount,
  });

  final LocalFirstSyncRuntime runtime;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = runtime.canFlushToServer
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer;
    final foregroundColor = runtime.canFlushToServer
        ? colorScheme.onPrimaryContainer
        : colorScheme.onTertiaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              runtime.canFlushToServer
                  ? Icons.cloud_sync_outlined
                  : Icons.phone_android,
              color: foregroundColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    runtime.modeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    runtime.queueMessage(pendingCount),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foregroundColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncDeliveryLedgerPanel extends StatelessWidget {
  const _SyncDeliveryLedgerPanel({
    required this.entries,
    required this.onClear,
  });

  final List<AnchorSyncDeliveryEntry> entries;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final latest = entries.first;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  latest.status == AnchorSyncDeliveryStatus.delivered
                      ? Icons.cloud_done_outlined
                      : Icons.phone_android,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.titleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${latest.itemSummaryLabel} via ${latest.endpointLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear sync ledger',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_all),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SyncMetadataPill(
                  icon: Icons.history,
                  label: latest.attemptedAtLabel,
                ),
                _SyncMetadataPill(
                  icon: Icons.fact_check_outlined,
                  label: latest.statusLabel,
                ),
                _SyncMetadataPill(
                  icon: Icons.inventory_2_outlined,
                  label: latest.itemSummaryLabel,
                ),
                _SyncMetadataPill(
                  icon: Icons.vpn_key_outlined,
                  label: latest.shortIdempotencyKey,
                ),
                _SyncMetadataPill(
                  icon: Icons.fingerprint,
                  label: latest.payloadFingerprint,
                ),
                _SyncMetadataPill(
                  icon: Icons.cloud_queue,
                  label: latest.endpointLabel,
                ),
              ],
            ),
            if (entries.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${entries.length} sync attempts kept on this device',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncQueueFilters extends StatelessWidget {
  const _SyncQueueFilters({
    required this.selectedFilter,
    required this.allCount,
    required this.uploadCount,
    required this.mediaCount,
    required this.metadataCount,
    required this.qualityCount,
    required this.pendingQualityReviewCount,
    required this.onUploadMediaPayloads,
    required this.onSyncUploads,
    required this.onSyncMetadataUpdates,
    required this.onAcceptPendingQualityReviews,
    required this.onChanged,
  });

  final _SyncQueueFilter selectedFilter;
  final int allCount;
  final int uploadCount;
  final int mediaCount;
  final int metadataCount;
  final int qualityCount;
  final int pendingQualityReviewCount;
  final VoidCallback? onUploadMediaPayloads;
  final VoidCallback? onSyncUploads;
  final VoidCallback? onSyncMetadataUpdates;
  final VoidCallback? onAcceptPendingQualityReviews;
  final ValueChanged<_SyncQueueFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_SyncQueueFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _SyncQueueFilter.all,
                label: Text('All'),
              ),
              ButtonSegment(
                value: _SyncQueueFilter.uploads,
                label: Text('Uploads'),
              ),
              ButtonSegment(
                value: _SyncQueueFilter.media,
                label: Text('Media'),
              ),
              ButtonSegment(
                value: _SyncQueueFilter.metadata,
                label: Text('Metadata'),
              ),
              ButtonSegment(
                value: _SyncQueueFilter.quality,
                label: Text('Quality'),
              ),
            ],
            selected: {selectedFilter},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _syncSummaryText,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (selectedFilter == _SyncQueueFilter.quality && qualityCount > 0) ...[
          const SizedBox(height: 8),
          _SyncQualityReviewSummary(
            qualityCount: qualityCount,
            pendingQualityReviewCount: pendingQualityReviewCount,
          ),
        ],
        if (selectedFilter == _SyncQueueFilter.uploads && uploadCount > 0) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('sync_mark_all_uploads_button'),
            onPressed: onSyncUploads,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(_uploadSyncButtonLabel),
          ),
        ],
        if (selectedFilter == _SyncQueueFilter.media && mediaCount > 0) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('sync_upload_all_media_payloads_button'),
            onPressed: onUploadMediaPayloads,
            icon: const Icon(Icons.perm_media_outlined),
            label: Text(_mediaUploadButtonLabel),
          ),
        ],
        if (selectedFilter == _SyncQueueFilter.metadata &&
            metadataCount > 0) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('sync_mark_all_metadata_updates_button'),
            onPressed: onSyncMetadataUpdates,
            icon: const Icon(Icons.edit_note),
            label: Text(_metadataSyncButtonLabel),
          ),
        ],
        if (selectedFilter == _SyncQueueFilter.quality &&
            pendingQualityReviewCount > 0) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('sync_accept_all_quality_reviews_button'),
            onPressed: onAcceptPendingQualityReviews,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(_qualityReviewButtonLabel),
          ),
        ],
      ],
    );
  }

  String get _syncSummaryText {
    final syncLabel = allCount == 1 ? 'item' : 'items';
    final uploadLabel = uploadCount == 1 ? 'upload' : 'uploads';
    final mediaLabel = mediaCount == 1 ? 'media payload' : 'media payloads';
    final metadataLabel =
        metadataCount == 1 ? 'metadata update' : 'metadata updates';
    final qualityLabel = qualityCount == 1 ? 'quality issue' : 'quality issues';

    return '$allCount sync $syncLabel: $uploadCount $uploadLabel, '
        '$mediaCount $mediaLabel, $metadataCount $metadataLabel, '
        '$qualityCount $qualityLabel';
  }

  String get _metadataSyncButtonLabel {
    final updateLabel = metadataCount == 1 ? 'Update' : 'Updates';
    return 'Mark $metadataCount Metadata $updateLabel Synced';
  }

  String get _uploadSyncButtonLabel {
    final uploadLabel = uploadCount == 1 ? 'Upload' : 'Uploads';
    return 'Mark $uploadCount $uploadLabel Synced';
  }

  String get _mediaUploadButtonLabel {
    final payloadLabel = mediaCount == 1 ? 'Payload' : 'Payloads';
    return 'Upload $mediaCount Media $payloadLabel';
  }

  String get _qualityReviewButtonLabel {
    final reviewLabel = pendingQualityReviewCount == 1 ? 'Review' : 'Reviews';
    return 'Accept $pendingQualityReviewCount Quality $reviewLabel';
  }
}

class _SyncQualityReviewSummary extends StatelessWidget {
  const _SyncQualityReviewSummary({
    required this.qualityCount,
    required this.pendingQualityReviewCount,
  });

  final int qualityCount;
  final int pendingQualityReviewCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final acceptedCount = qualityCount - pendingQualityReviewCount;
    final hasPendingReview = pendingQualityReviewCount > 0;

    return DecoratedBox(
      key: const ValueKey('sync_quality_review_summary'),
      decoration: BoxDecoration(
        color: hasPendingReview
            ? colorScheme.errorContainer.withValues(alpha: 0.62)
            : colorScheme.primaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (hasPendingReview ? colorScheme.error : colorScheme.primary)
              .withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              hasPendingReview
                  ? Icons.warning_amber_rounded
                  : Icons.fact_check_outlined,
              color: hasPendingReview
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPendingReview
                        ? 'Quality reviews pending'
                        : 'Quality reviews ready for sync',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasPendingReview
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SyncQualityCountChip(
                        key: const ValueKey('sync_quality_pending_count'),
                        icon: Icons.pending_actions,
                        label: _pendingReviewLabel,
                      ),
                      _SyncQualityCountChip(
                        key: const ValueKey('sync_quality_accepted_count'),
                        icon: Icons.fact_check_outlined,
                        label: _acceptedReviewLabel(acceptedCount),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _pendingReviewLabel {
    final reviewLabel = pendingQualityReviewCount == 1 ? 'review' : 'reviews';
    return '$pendingQualityReviewCount pending $reviewLabel';
  }

  String _acceptedReviewLabel(int acceptedCount) {
    return '$acceptedCount accepted';
  }
}

class _SyncQualityCountChip extends StatelessWidget {
  const _SyncQualityCountChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncMemoryCard extends ConsumerWidget {
  const _SyncMemoryCard({required this.memory});

  final AnchorMemory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final uploadEntries = ref.watch(anchorMediaUploadQueueProvider);
    final mediaUploadEntry = memory.mediaAttachment == null
        ? null
        : mediaUploadEntryFor(uploadEntries, memory);
    final mediaManifest = memory.mediaAttachment == null
        ? null
        : AnchorMediaSyncManifest.fromAttachment(
            memory.mediaAttachment!,
            uploadEntry: mediaUploadEntry,
          );
    final syncPayload =
        ref.watch(anchorSyncPayloadBuilderProvider).memoryPayload(memory);
    final hasPendingMetadataUpdate = _hasPendingMetadataUpdate(memory);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForSync(memory), color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    memory.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(memory.syncStatusLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              memory.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (hasPendingMetadataUpdate) ...[
              const SizedBox(height: 10),
              _SyncMetadataUpdatePanel(
                memory: memory,
                onPreviewAr: () => Navigator.pushNamed(
                  context,
                  AppRoutes.arViewer,
                  arguments: memory.id,
                ),
                onAdjustCalibration: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memoryCalibration,
                  arguments: memory.id,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _SyncMetadataPill(
                  icon: Icons.article_outlined,
                  label: syncPayload.operationLabel,
                ),
                _SyncMetadataPill(
                  icon: Icons.fingerprint,
                  label: syncPayload.mutationLabel,
                ),
                _SyncMetadataPill(
                  icon: memory.isPrivate
                      ? Icons.visibility_off_outlined
                      : Icons.public,
                  label: syncPayload.visibilityLabel,
                ),
                _SyncMetadataPill(
                  icon: Icons.sync_alt,
                  label: memory.syncReason.label,
                ),
                if (memory.mediaAttachment != null)
                  _SyncMetadataPill(
                    icon: anchorMediaIconFor(memory.mediaAttachment!.type),
                    label: anchorMediaSummaryLabel(memory.mediaAttachment!),
                  ),
                if (mediaManifest != null) ...[
                  _SyncMetadataPill(
                    icon: mediaManifest.isStored
                        ? Icons.inventory_2_outlined
                        : Icons.inventory_2,
                    label: mediaManifest.statusLabel,
                  ),
                  _SyncMetadataPill(
                    icon: Icons.badge_outlined,
                    label: mediaManifest.identityLabel,
                  ),
                  _SyncMetadataPill(
                    icon: Icons.folder_outlined,
                    label: mediaManifest.storageLabel,
                  ),
                  _SyncMetadataPill(
                    icon: Icons.data_object,
                    label: mediaManifest.payloadLabel,
                  ),
                  if (mediaManifest.modelFormatLabel != null)
                    _SyncMetadataPill(
                      icon: Icons.view_in_ar_outlined,
                      label: mediaManifest.modelFormatLabel!,
                    ),
                  if (mediaManifest.modelSourceLabel != null)
                    _SyncMetadataPill(
                      icon: Icons.source_outlined,
                      label: mediaManifest.modelSourceLabel!,
                    ),
                  if (mediaManifest.modelPathLabel != null)
                    _SyncMetadataPill(
                      icon: Icons.category_outlined,
                      label: mediaManifest.modelPathLabel!,
                    ),
                  if (mediaManifest.modelPackageLabel != null)
                    _SyncMetadataPill(
                      icon: Icons.inventory_outlined,
                      label: mediaManifest.modelPackageLabel!,
                    ),
                  if (mediaManifest.modelValidationLabel != null)
                    _SyncMetadataPill(
                      icon: mediaManifest.modelValidationIsValid == false
                          ? Icons.error_outline
                          : Icons.verified_outlined,
                      label: mediaManifest.modelValidationLabel!,
                    ),
                  for (final issueLabel
                      in mediaManifest.modelValidationIssueLabels)
                    _SyncMetadataPill(
                      icon: mediaManifest.modelValidationErrorLabels
                              .contains(issueLabel)
                          ? Icons.error_outline
                          : Icons.tips_and_updates_outlined,
                      label: issueLabel,
                    ),
                  if (mediaManifest.modelRenderProfileLabel != null)
                    _SyncMetadataPill(
                      icon: mediaManifest.modelRequiresPreparation
                          ? Icons.build_circle_outlined
                          : mediaManifest.modelUsesAnyPrimitiveFallback
                              ? Icons.category_outlined
                              : Icons.view_in_ar_outlined,
                      label: mediaManifest.modelRenderProfileLabel!,
                    ),
                  for (final profileLabel
                      in mediaManifest.modelRenderProfileLabels)
                    _SyncMetadataPill(
                      icon: Icons.devices_outlined,
                      label: profileLabel,
                    ),
                  for (final noteLabel in mediaManifest.modelRenderProfileNotes)
                    _SyncMetadataPill(
                      icon: Icons.tips_and_updates_outlined,
                      label: noteLabel,
                    ),
                  if (mediaManifest.requiresUpload) ...[
                    _SyncMetadataPill(
                      icon: _mediaUploadIcon(mediaManifest.uploadStatus),
                      label: mediaManifest.uploadStatusLabel,
                    ),
                    _SyncMetadataPill(
                      icon: Icons.refresh,
                      label: mediaManifest.retryLabel,
                    ),
                  ] else
                    const _SyncMetadataPill(
                      icon: Icons.check_circle_outline,
                      label: 'No media upload needed',
                    ),
                  if (mediaManifest.requiresUpload &&
                      mediaManifest.errorMessage != null)
                    _SyncMetadataPill(
                      icon: Icons.error_outline,
                      label: mediaManifest.errorMessage!,
                    ),
                ],
                _SyncMetadataPill(
                  icon: Icons.schedule,
                  label: memory.capturedTimelineLabel,
                ),
                _SyncMetadataPill(
                  icon: Icons.gps_fixed,
                  label:
                      '+/- ${memory.captureMetadata.gpsAccuracyMeters.toStringAsFixed(1)} m',
                ),
                _SyncMetadataPill(
                  icon: Icons.navigation,
                  label: memory.captureMetadata.headingLabel,
                ),
                _SyncMetadataPill(
                  icon: _cloudAnchorIcon(memory.captureMetadata),
                  label: memory.captureMetadata.cloudAnchorStatusLabel(),
                ),
              ],
            ),
            if (memory.mediaAttachment?.recordingMetadataLabels.isNotEmpty ==
                true) ...[
              const SizedBox(height: 12),
              _SyncRecordingProfilePanel(
                attachment: memory.mediaAttachment!,
              ),
            ],
            if (memory.mediaAttachment?.needsRecordingQualityReview ==
                true) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: ValueKey('sync_quality_review_accept_${memory.id}'),
                  onPressed: () => _acceptRecordingQualityReview(context, ref),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Accept Quality Review'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (mediaManifest != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('sync_media_inspect_${memory.id}'),
                      onPressed: () => showAnchorMediaDetailSheet(
                        context,
                        memory: memory,
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Inspect Media'),
                    ),
                  ),
                  if (mediaManifest.requiresUpload) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: ValueKey('sync_media_upload_${memory.id}'),
                        onPressed: mediaManifest.uploadStatus ==
                                    AnchorMediaUploadStatus.uploading ||
                                mediaManifest.uploadStatus ==
                                    AnchorMediaUploadStatus.uploaded
                            ? null
                            : () => _uploadMedia(
                                  context,
                                  ref,
                                ),
                        icon: Icon(
                          _mediaUploadButtonIcon(mediaManifest.uploadStatus),
                        ),
                        label: Text(_mediaUploadButtonLabel(mediaManifest)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.memoryDetails,
                      arguments: memory.id,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _markSynced(
                      context,
                      ref,
                      hasMedia: mediaManifest != null,
                    ),
                    icon: Icon(_markSyncedButtonIcon(memory)),
                    label: Text(_markSyncedButtonLabel(memory)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _uploadMedia(
    BuildContext context,
    WidgetRef ref,
  ) {
    _showOutcome(
      context,
      ref.read(anchorSyncCoordinatorProvider).uploadMedia(memory),
    );
  }

  void _markSynced(
    BuildContext context,
    WidgetRef ref, {
    required bool hasMedia,
  }) {
    _showOutcome(
      context,
      ref.read(anchorSyncCoordinatorProvider).markMemorySynced(
            memory,
            includeMedia: hasMedia,
          ),
    );
  }

  void _acceptRecordingQualityReview(BuildContext context, WidgetRef ref) {
    final didUpdate = ref
        .read(nearbyAnchorsProvider.notifier)
        .markRecordingQualityReviewed(memory.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            didUpdate
                ? 'Recording quality review accepted.'
                : 'Recording quality review is already current.',
          ),
        ),
      );
  }

  void _showOutcome(BuildContext context, AnchorSyncOutcome outcome) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(outcome.message)),
      );
  }

  IconData _iconForSync(AnchorMemory memory) {
    if (memory.syncReason == AnchorSyncReason.metadataUpdate &&
        memory.syncStatus != AnchorSyncStatus.synced) {
      return Icons.edit_note;
    }

    return switch (memory.syncStatus) {
      AnchorSyncStatus.queued => Icons.cloud_upload_outlined,
      AnchorSyncStatus.uploading => Icons.sync,
      AnchorSyncStatus.synced => Icons.cloud_done,
      AnchorSyncStatus.failed => Icons.error_outline,
    };
  }

  bool _hasPendingMetadataUpdate(AnchorMemory memory) {
    return memory.syncReason == AnchorSyncReason.metadataUpdate &&
        memory.syncStatus != AnchorSyncStatus.synced;
  }

  IconData _markSyncedButtonIcon(AnchorMemory memory) {
    if (_hasPendingMetadataUpdate(memory)) {
      return Icons.edit_note;
    }
    return Icons.cloud_done;
  }

  String _markSyncedButtonLabel(AnchorMemory memory) {
    if (_hasPendingMetadataUpdate(memory)) {
      return 'Mark Metadata Synced';
    }
    if (memory.syncReason == AnchorSyncReason.newCapture) {
      return 'Mark Upload Synced';
    }
    return 'Mark Synced';
  }

  IconData _cloudAnchorIcon(AnchorCaptureMetadata metadata) {
    if (!metadata.hasCloudAnchor) {
      return Icons.cloud_off;
    }
    if (metadata.isCloudAnchorExpired()) {
      return Icons.warning_amber;
    }
    return Icons.cloud_done;
  }

  IconData _mediaUploadIcon(AnchorMediaUploadStatus status) {
    return switch (status) {
      AnchorMediaUploadStatus.queued => Icons.cloud_queue,
      AnchorMediaUploadStatus.uploading => Icons.sync,
      AnchorMediaUploadStatus.uploaded => Icons.cloud_done,
      AnchorMediaUploadStatus.failed => Icons.error_outline,
    };
  }

  IconData _mediaUploadButtonIcon(AnchorMediaUploadStatus status) {
    return switch (status) {
      AnchorMediaUploadStatus.failed => Icons.refresh,
      AnchorMediaUploadStatus.uploaded => Icons.cloud_done,
      AnchorMediaUploadStatus.queued ||
      AnchorMediaUploadStatus.uploading =>
        Icons.cloud_upload_outlined,
    };
  }

  String _mediaUploadButtonLabel(AnchorMediaSyncManifest manifest) {
    return switch (manifest.uploadStatus) {
      AnchorMediaUploadStatus.failed => 'Retry Media',
      AnchorMediaUploadStatus.uploaded => 'Media Uploaded',
      AnchorMediaUploadStatus.uploading => 'Uploading Media',
      AnchorMediaUploadStatus.queued => 'Upload Media',
    };
  }
}

class _SyncMetadataUpdatePanel extends StatelessWidget {
  const _SyncMetadataUpdatePanel({
    required this.memory,
    required this.onPreviewAr,
    required this.onAdjustCalibration,
  });

  final AnchorMemory memory;
  final VoidCallback onPreviewAr;
  final VoidCallback onAdjustCalibration;

  @override
  Widget build(BuildContext context) {
    final metadata = memory.captureMetadata;
    final colorScheme = Theme.of(context).colorScheme;
    final hasCorrection = metadata.hasManualCorrection;

    return DecoratedBox(
      key: ValueKey('sync_metadata_update_panel_${memory.id}'),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
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
                  hasCorrection ? Icons.tune : Icons.edit_note,
                  color: colorScheme.onSecondaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasCorrection
                        ? 'Calibration metadata pending'
                        : 'Metadata update pending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SyncMetadataPill(
                  icon: Icons.view_in_ar,
                  label: metadata.anchorType,
                ),
                if (hasCorrection) ...[
                  _SyncMetadataPill(
                    icon: Icons.open_with,
                    label: metadata.manualCorrectionOffsetLabel,
                  ),
                  _SyncMetadataPill(
                    icon: Icons.schedule,
                    label: metadata.manualCorrectionSavedLabel,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('sync_metadata_preview_ar_${memory.id}'),
                    onPressed: onPreviewAr,
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('Preview AR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: ValueKey(
                      'sync_metadata_adjust_calibration_${memory.id}',
                    ),
                    onPressed: onAdjustCalibration,
                    icon: const Icon(Icons.tune),
                    label: const Text('Adjust'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncRecordingProfilePanel extends StatelessWidget {
  const _SyncRecordingProfilePanel({required this.attachment});

  final AnchorMediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.video_settings_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AR recording profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (attachment.recordingQualityWarningLabel != null) ...[
              const SizedBox(height: 8),
              _SyncRecordingQualityNotice(attachment: attachment),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in attachment.recordingMetadataLabels)
                  _SyncMetadataPill(
                    icon: _recordingProfileIcon(label),
                    label: label,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncRecordingQualityNotice extends StatelessWidget {
  const _SyncRecordingQualityNotice({required this.attachment});

  final AnchorMediaAttachment attachment;

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
          children: [
            Icon(
              Icons.warning_amber,
              size: 16,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${attachment.recordingQualityWarningLabel} - '
                '${attachment.recordingQualityDetailLabel}',
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

class _SyncMetadataPill extends StatelessWidget {
  const _SyncMetadataPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _recordingProfileIcon(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('fps')) {
    return Icons.speed;
  }
  if (normalized.contains('mbps') || normalized == 'mp4') {
    return Icons.movie_creation_outlined;
  }
  if (normalized.contains('overlay') || normalized.contains('raw ar')) {
    return Icons.view_in_ar;
  }
  if (normalized.contains('audio') || normalized == 'silent') {
    return Icons.mic_none;
  }
  return Icons.data_object_outlined;
}

class _FilteredEmptySyncState extends StatelessWidget {
  const _FilteredEmptySyncState({required this.filter});

  final _SyncQueueFilter filter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_emptyIcon, color: colorScheme.primary, size: 48),
            const SizedBox(height: 12),
            Text(
              _emptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _emptyIcon {
    return switch (filter) {
      _SyncQueueFilter.all => Icons.cloud_done,
      _SyncQueueFilter.uploads => Icons.cloud_upload_outlined,
      _SyncQueueFilter.media => Icons.perm_media_outlined,
      _SyncQueueFilter.metadata => Icons.edit_note,
      _SyncQueueFilter.quality => Icons.warning_amber_rounded,
    };
  }

  String get _emptyTitle {
    return switch (filter) {
      _SyncQueueFilter.all => 'All memories synced',
      _SyncQueueFilter.uploads => 'No uploads pending',
      _SyncQueueFilter.media => 'No media uploads pending',
      _SyncQueueFilter.metadata => 'No metadata updates pending',
      _SyncQueueFilter.quality => 'No quality issues pending',
    };
  }

  String get _emptyMessage {
    return switch (filter) {
      _SyncQueueFilter.all =>
        'Offline captures and metadata changes will appear here until sync completes.',
      _SyncQueueFilter.uploads =>
        'New captures are synced. Metadata changes may still be waiting.',
      _SyncQueueFilter.media =>
        'Photo and AR screen recording payloads are synced.',
      _SyncQueueFilter.metadata =>
        'Local edits are synced. New captures may still be waiting.',
      _SyncQueueFilter.quality =>
        'Low and reduced-FPS recordings will appear here before sync.',
    };
  }
}

class _EmptySyncState extends StatelessWidget {
  const _EmptySyncState({
    required this.deliveryEntries,
    required this.onClearDeliveryLog,
  });

  final List<AnchorSyncDeliveryEntry> deliveryEntries;
  final VoidCallback onClearDeliveryLog;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done, color: colorScheme.primary, size: 56),
          const SizedBox(height: 12),
          Text(
            'All memories synced',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Offline captures and metadata changes will appear here until sync completes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (deliveryEntries.isEmpty) {
      return Center(child: content);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      children: [
        content,
        const SizedBox(height: 16),
        _SyncDeliveryLedgerPanel(
          entries: deliveryEntries,
          onClear: onClearDeliveryLog,
        ),
      ],
    );
  }
}
