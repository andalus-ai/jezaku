import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_media_detail_sheet.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

class MemoryDetailScreen extends ConsumerWidget {
  const MemoryDetailScreen({
    super.key,
    required this.memoryId,
  });

  final String memoryId;
  static const _geoService = AnchorGeoService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(nearbyAnchorsProvider);
    final memory = _findMemory(memories);

    if (memory == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memory Details')),
        body: const Center(child: Text('Memory not found')),
      );
    }
    final journeyStep = ref.watch(spatialJourneyStepProvider(memory.id));
    final linkedWalls = ref.watch(memoryLinkedWallsProvider(memory.id));
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Details'),
        actions: [
          IconButton(
            tooltip: 'Calibrate anchor',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryCalibration,
              arguments: memory.id,
            ),
          ),
          IconButton(
            tooltip: 'Report memory',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _showReportDialog(context, ref, memory),
          ),
          IconButton(
            tooltip: 'Delete memory',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, memory),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MemoryPreview(memory: memory, resolvedMedia: resolvedMedia),
          const SizedBox(height: 16),
          Text(
            memory.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(memory.caption),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  memory.isPrivate ? Icons.lock_outline : Icons.public,
                  size: 18,
                ),
                label: Text(memory.isPrivate ? 'Private' : 'Public'),
              ),
              if (memory.hasArExperience)
                const Chip(
                  avatar: Icon(Icons.view_in_ar, size: 18),
                  label: Text('AR anchor'),
                ),
              Chip(
                avatar: const Icon(Icons.favorite_border, size: 18),
                label: Text('${memory.reactions} reactions'),
              ),
              Chip(
                avatar: Icon(
                  memory.allowComments
                      ? Icons.mode_comment_outlined
                      : Icons.comments_disabled_outlined,
                  size: 18,
                ),
                label:
                    Text(memory.allowComments ? 'Comments on' : 'Comments off'),
              ),
              Chip(
                avatar: Icon(_syncIconFor(memory), size: 18),
                label: Text(memory.syncStatusLabel),
              ),
              if (memory.mediaAttachment != null)
                Chip(
                  avatar: Icon(
                    anchorMediaIconFor(memory.mediaAttachment!.type),
                    size: 18,
                  ),
                  label: Text(memory.mediaAttachment!.typeLabel),
                ),
              Chip(
                avatar: Icon(
                  memory.moderationStatus == AnchorModerationStatus.approved
                      ? Icons.verified_outlined
                      : Icons.report_outlined,
                  size: 18,
                ),
                label: Text(memory.moderationStatus.label),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MemoryAuditTimelineCard(
            memory: memory,
            onAcceptRecordingQualityReview:
                memory.mediaAttachment?.needsRecordingQualityReview == true
                    ? () => _acceptRecordingQualityReview(
                          context,
                          ref,
                          memory,
                        )
                    : null,
          ),
          const SizedBox(height: 16),
          if (memory.mediaAttachment != null) ...[
            _MediaAttachmentCard(
              memory: memory,
              attachment: memory.mediaAttachment!,
              resolvedMedia: resolvedMedia,
            ),
            const SizedBox(height: 16),
          ],
          _SpatialJourneyCard(
            step: journeyStep,
            onOpenMemory: (journeyMemory) => Navigator.pushReplacementNamed(
              context,
              AppRoutes.memoryDetails,
              arguments: journeyMemory.id,
            ),
          ),
          const SizedBox(height: 16),
          if (linkedWalls.isNotEmpty) ...[
            _LinkedVirtualWallsCard(
              walls: linkedWalls,
              onOpenWall: (wall) => Navigator.pushNamed(
                context,
                AppRoutes.virtualWallDetails,
                arguments: wall.id,
              ),
              onStartWallTrail: (wall) {
                final linkedMemories = linkedWallMemories(wall, memories);
                final trailPreview = wallTrailPreviewFor(
                  linkedMemories,
                  originLatitude: viewerLatitude,
                  originLongitude: viewerLongitude,
                  optimizeFromOrigin: true,
                );
                final trailMemoryIds =
                    trailPreview?.orderedMemoryIds ?? wall.linkedMemoryIds;

                Navigator.pushNamed(
                  context,
                  AppRoutes.arViewer,
                  arguments: ARViewerArgs.trail(
                    ARTrailSession.fromMemoryIds(
                      title: '${wall.title} trail',
                      memoryIds: trailMemoryIds,
                      source: ARTrailSource.memoryDetails,
                      focusedMemoryId:
                          trailMemoryIds.contains(memory.id) ? memory.id : null,
                      sourceWallId: wall.id,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          _PrecisionCard(memory: memory),
          const SizedBox(height: 20),
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: memory.locationLabel,
          ),
          _InfoRow(
            icon: Icons.near_me_outlined,
            label: 'Range',
            value: memory.distanceLabel,
          ),
          _InfoRow(
            icon: Icons.schedule,
            label: 'Captured',
            value: memory.capturedTimelineLabel,
          ),
          const SizedBox(height: 6),
          _NearbyAnchorsCard(
            nearbyAnchors: _nearbyAnchorsFor(memory, memories),
            onOpenDetails: (nearbyMemory) => Navigator.pushNamed(
              context,
              AppRoutes.memoryDetails,
              arguments: nearbyMemory.id,
            ),
            onOpenAr: (nearbyMemory) => Navigator.pushNamed(
              context,
              AppRoutes.arViewer,
              arguments: nearbyMemory.id,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.arViewer,
                  arguments: memory.id,
                ),
                icon: const Icon(Icons.view_in_ar),
                label: const Text('View in AR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ref
                      .read(nearbyAnchorsProvider.notifier)
                      .togglePrivacy(memory.id);
                },
                icon:
                    Icon(memory.isPrivate ? Icons.public : Icons.lock_outline),
                label: Text(memory.isPrivate ? 'Make Public' : 'Make Private'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnchorMemory? _findMemory(List<AnchorMemory> memories) {
    for (final memory in memories) {
      if (memory.id == memoryId) {
        return memory;
      }
    }
    return null;
  }

  List<_NearbyAnchorContext> _nearbyAnchorsFor(
    AnchorMemory currentMemory,
    List<AnchorMemory> memories,
  ) {
    final candidates = [
      for (final memory in memories)
        if (memory.id != currentMemory.id)
          _nearbyAnchorFor(currentMemory, memory),
    ];

    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return candidates.take(3).toList();
  }

  _NearbyAnchorContext _nearbyAnchorFor(
    AnchorMemory currentMemory,
    AnchorMemory memory,
  ) {
    final bearingDegrees = _geoService.bearingDegrees(
      currentMemory.latitude,
      currentMemory.longitude,
      memory.latitude,
      memory.longitude,
    );

    return _NearbyAnchorContext(
      memory: memory,
      distanceMeters: _geoService.distanceBetweenMeters(
        currentMemory.latitude,
        currentMemory.longitude,
        memory.latitude,
        memory.longitude,
      ),
      bearingDegrees: bearingDegrees,
      directionLabel: _geoService.directionFromBearing(bearingDegrees),
    );
  }

  IconData _syncIconFor(AnchorMemory memory) {
    if (memory.syncStatus == AnchorSyncStatus.synced) {
      return Icons.cloud_done;
    }
    if (memory.syncReason == AnchorSyncReason.metadataUpdate) {
      return Icons.edit_note;
    }
    return Icons.cloud_upload_outlined;
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AnchorMemory memory,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete memory?'),
          content:
              Text('"${memory.title}" will be removed from nearby memories.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(nearbyAnchorsProvider.notifier)
                    .deleteMemory(memory.id);
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog(
    BuildContext context,
    WidgetRef ref,
    AnchorMemory memory,
  ) {
    const reasons = [
      'Unsafe or inappropriate',
      'Privacy concern',
      'Spam or misleading',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report memory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(reason),
                  onTap: () {
                    ref.read(nearbyAnchorsProvider.notifier).reportMemory(
                          memoryId: memory.id,
                          reason: reason,
                        );
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Memory reported for review.'),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _acceptRecordingQualityReview(
    BuildContext context,
    WidgetRef ref,
    AnchorMemory memory,
  ) {
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
}

class _SpatialJourneyCard extends StatelessWidget {
  const _SpatialJourneyCard({
    required this.step,
    required this.onOpenMemory,
  });

  final AnchorJourneyStep? step;
  final ValueChanged<AnchorMemory> onOpenMemory;

  @override
  Widget build(BuildContext context) {
    final journeyStep = step;
    if (journeyStep == null || journeyStep.total <= 1) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const ValueKey('spatial_journey_card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Spatial journey',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.route_outlined, size: 16),
                  label: Text(journeyStep.progressLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${journeyStep.spatialLabel} from your position',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _JourneyStopTile(
              label: 'Previous',
              emptyLabel: 'This is the first stop',
              memory: journeyStep.previousMemory,
              icon: Icons.chevron_left,
              actionKeyPrefix: 'journey_previous',
              onOpenMemory: onOpenMemory,
            ),
            _JourneyStopTile(
              label: 'Next',
              emptyLabel: 'Trail complete',
              memory: journeyStep.nextMemory,
              icon: Icons.chevron_right,
              actionKeyPrefix: 'journey_next',
              onOpenMemory: onOpenMemory,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStopTile extends StatelessWidget {
  const _JourneyStopTile({
    required this.label,
    required this.emptyLabel,
    required this.memory,
    required this.icon,
    required this.actionKeyPrefix,
    required this.onOpenMemory,
  });

  final String label;
  final String emptyLabel;
  final AnchorMemory? memory;
  final IconData icon;
  final String actionKeyPrefix;
  final ValueChanged<AnchorMemory> onOpenMemory;

  @override
  Widget build(BuildContext context) {
    final journeyMemory = memory;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(journeyMemory?.title ?? emptyLabel),
      trailing: journeyMemory == null
          ? null
          : IconButton(
              key: ValueKey('${actionKeyPrefix}_${journeyMemory.id}'),
              tooltip: 'Open ${journeyMemory.title}',
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => onOpenMemory(journeyMemory),
            ),
      onTap: journeyMemory == null ? null : () => onOpenMemory(journeyMemory),
    );
  }
}

class _MemoryAuditTimelineCard extends StatelessWidget {
  const _MemoryAuditTimelineCard({
    required this.memory,
    this.onAcceptRecordingQualityReview,
  });

  final AnchorMemory memory;
  final VoidCallback? onAcceptRecordingQualityReview;

  @override
  Widget build(BuildContext context) {
    final attachment = memory.mediaAttachment;
    final recordingQualityEvent = _recordingQualityEvent(attachment);

    return Card(
      key: const ValueKey('memory_audit_timeline_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Memory timeline',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TimelineEventTile(
              icon: Icons.schedule,
              label: 'Capture',
              value: memory.capturedTimelineLabel,
            ),
            if (attachment != null)
              _TimelineEventTile(
                icon: anchorMediaIconFor(attachment.type),
                label: 'Media',
                value: attachment.summaryLabel,
              ),
            if (recordingQualityEvent != null)
              _TimelineEventTile(
                icon: recordingQualityEvent.needsAttention
                    ? Icons.warning_amber_rounded
                    : Icons.fact_check_outlined,
                label: 'Quality review',
                value: recordingQualityEvent.label,
                highlight: recordingQualityEvent.needsAttention,
              ),
            if (recordingQualityEvent?.needsAttention == true &&
                onAcceptRecordingQualityReview != null) ...[
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: ValueKey('memory_quality_review_accept_${memory.id}'),
                  onPressed: onAcceptRecordingQualityReview,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Accept quality review'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _TimelineEventTile(
              icon: _syncIconForMemory(memory),
              label: 'Sync',
              value: '${memory.syncStatusLabel} - ${memory.syncReason.label}',
            ),
            _TimelineEventTile(
              icon: memory.moderationStatus == AnchorModerationStatus.approved
                  ? Icons.verified_outlined
                  : Icons.report_outlined,
              label: 'Moderation',
              value: _moderationTimelineLabel(memory),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  _RecordingQualityTimelineEvent? _recordingQualityEvent(
    AnchorMediaAttachment? attachment,
  ) {
    if (attachment?.type != AnchorMediaType.arRecording) {
      return null;
    }
    final qualityReviewLabel = attachment!.recordingQualityReviewLabel;
    final reviewedAtLabel = attachment.recordingQualityReviewedAtLabel;
    if (qualityReviewLabel != null) {
      return _RecordingQualityTimelineEvent(
        label: [
          qualityReviewLabel,
          if (reviewedAtLabel != null) reviewedAtLabel,
        ].join(' - '),
        needsAttention: attachment.recordingQualityReviewedAt == null,
      );
    }
    return _RecordingQualityTimelineEvent(
      label: 'Ready to publish - '
          '${attachment.recordingQualityDetailLabel ?? 'Profile captured'}',
      needsAttention: false,
    );
  }
}

class _RecordingQualityTimelineEvent {
  const _RecordingQualityTimelineEvent({
    required this.label,
    required this.needsAttention,
  });

  final String label;
  final bool needsAttention;
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = highlight ? colorScheme.error : colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _syncIconForMemory(AnchorMemory memory) {
  if (memory.syncStatus == AnchorSyncStatus.synced) {
    return Icons.cloud_done;
  }
  if (memory.syncReason == AnchorSyncReason.metadataUpdate) {
    return Icons.edit_note;
  }
  if (memory.syncStatus == AnchorSyncStatus.failed) {
    return Icons.cloud_off_outlined;
  }
  return Icons.cloud_upload_outlined;
}

String _moderationTimelineLabel(AnchorMemory memory) {
  final reportLabel = memory.reportCountLabel;
  final reason = memory.reportReason?.trim();
  if (memory.reportCount > 0 && reason != null && reason.isNotEmpty) {
    return '${memory.moderationStatus.label} - $reportLabel - $reason';
  }
  if (memory.reportCount > 0) {
    return '${memory.moderationStatus.label} - $reportLabel';
  }
  return memory.moderationStatus.label;
}

class _LinkedVirtualWallsCard extends StatelessWidget {
  const _LinkedVirtualWallsCard({
    required this.walls,
    required this.onOpenWall,
    required this.onStartWallTrail,
  });

  final List<ARWall> walls;
  final ValueChanged<ARWall> onOpenWall;
  final ValueChanged<ARWall> onStartWallTrail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wallCountLabel =
        '${walls.length} linked wall${walls.length == 1 ? '' : 's'}';

    return Card(
      key: const ValueKey('memory_linked_walls_card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Virtual walls',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.grid_view, size: 16),
                  label: Text(wallCountLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Collaborative walls using this anchor',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final wall in walls)
              ListTile(
                key: ValueKey('memory_wall_${wall.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(wall.isPublic ? Icons.public : Icons.group),
                title: Text(wall.title),
                subtitle: Text(
                  '${wall.distanceLabel} - ${wall.memberCountLabel} - '
                  '${wall.itemCountLabel}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('memory_wall_trail_${wall.id}'),
                      tooltip: 'Start ${wall.title} trail',
                      icon: const Icon(Icons.route_outlined),
                      onPressed: () => onStartWallTrail(wall),
                    ),
                    IconButton(
                      key: ValueKey('memory_wall_open_${wall.id}'),
                      tooltip: 'Open ${wall.title}',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => onOpenWall(wall),
                    ),
                  ],
                ),
                onTap: () => onOpenWall(wall),
              ),
          ],
        ),
      ),
    );
  }
}

class _NearbyAnchorsCard extends StatelessWidget {
  const _NearbyAnchorsCard({
    required this.nearbyAnchors,
    required this.onOpenDetails,
    required this.onOpenAr,
  });

  final List<_NearbyAnchorContext> nearbyAnchors;
  final ValueChanged<AnchorMemory> onOpenDetails;
  final ValueChanged<AnchorMemory> onOpenAr;

  @override
  Widget build(BuildContext context) {
    if (nearbyAnchors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nearby anchors',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Spatial neighbors around this memory',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final nearbyAnchor in nearbyAnchors)
              ListTile(
                key: ValueKey('nearby_anchor_${nearbyAnchor.memory.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  nearbyAnchor.memory.isPrivate
                      ? Icons.lock_outline
                      : Icons.place_outlined,
                ),
                title: Text(nearbyAnchor.memory.title),
                subtitle: Text(
                  '${nearbyAnchor.distanceLabel} ${nearbyAnchor.directionLabel} '
                  '- ${nearbyAnchor.memory.anchorHealthLabel}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey(
                        'nearby_anchor_details_${nearbyAnchor.memory.id}',
                      ),
                      tooltip: 'Open ${nearbyAnchor.memory.title} details',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => onOpenDetails(nearbyAnchor.memory),
                    ),
                    if (nearbyAnchor.memory.hasArExperience)
                      IconButton(
                        key: ValueKey(
                          'nearby_anchor_ar_${nearbyAnchor.memory.id}',
                        ),
                        tooltip: 'View ${nearbyAnchor.memory.title} in AR',
                        icon: const Icon(Icons.view_in_ar),
                        onPressed: () => onOpenAr(nearbyAnchor.memory),
                      ),
                  ],
                ),
                onTap: () => onOpenDetails(nearbyAnchor.memory),
              ),
          ],
        ),
      ),
    );
  }
}

class _NearbyAnchorContext {
  const _NearbyAnchorContext({
    required this.memory,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.directionLabel,
  });

  final AnchorMemory memory;
  final double distanceMeters;
  final double bearingDegrees;
  final String directionLabel;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

class _PrecisionCard extends StatelessWidget {
  const _PrecisionCard({required this.memory});

  final AnchorMemory memory;

  @override
  Widget build(BuildContext context) {
    final metadata = memory.captureMetadata;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Anchor Precision',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(memory.anchorHealthLabel),
                ),
              ],
            ),
            if (memory.needsCalibrationReview) ...[
              const SizedBox(height: 12),
              _PrecisionReviewBanner(metadata: metadata),
            ],
            const SizedBox(height: 12),
            _PrecisionRow(
              icon: Icons.gps_fixed,
              label: 'GPS accuracy',
              value: metadata.accuracyLabel,
            ),
            _PrecisionRow(
              icon: Icons.height,
              label: 'Altitude',
              value: '${metadata.altitudeMeters.toStringAsFixed(1)} m',
            ),
            _PrecisionRow(
              icon: Icons.navigation,
              label: 'Heading',
              value: metadata.headingLabel,
            ),
            _PrecisionRow(
              icon: Icons.screen_rotation_alt,
              label: 'Pitch / Roll',
              value: metadata.attitudeLabel,
            ),
            _PrecisionRow(
              icon:
                  metadata.hasCloudAnchor ? Icons.cloud_done : Icons.cloud_off,
              label: 'Cloud anchor',
              value: metadata.cloudAnchorStatusLabel(),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.hub_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(metadata.anchorType)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.sensors_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(metadata.captureSource)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.open_with, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(metadata.manualCorrectionOffsetLabel),
                ),
              ],
            ),
            if (metadata.hasManualCorrection) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(metadata.manualCorrectionSavedLabel)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrecisionReviewBanner extends StatelessWidget {
  const _PrecisionReviewBanner({required this.metadata});

  final AnchorCaptureMetadata metadata;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Placement needs calibration',
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${metadata.calibrationReasonLabel}. '
                    '${metadata.calibrationGuidanceLabel}',
                    style: TextStyle(color: colorScheme.onErrorContainer),
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

class _MediaAttachmentCard extends StatelessWidget {
  const _MediaAttachmentCard({
    required this.memory,
    required this.attachment,
    this.resolvedMedia,
  });

  final AnchorMemory memory;
  final AnchorMediaAttachment attachment;
  final AnchorResolvedMedia? resolvedMedia;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filePath = attachment.filePath;
    final mediaId = resolvedMedia?.mediaId ?? attachment.mediaId;
    final storagePath = resolvedMedia?.storagePath ?? attachment.storagePath;
    final byteLength = resolvedMedia?.storedByteLength;
    final availabilityLabel =
        resolvedMedia?.availabilityLabel ?? _attachmentAvailabilityLabel;

    return Card(
      key: const ValueKey('memory_media_attachment_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  anchorMediaIconFor(attachment.type),
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    attachment.typeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(attachment.detailLabel),
            const SizedBox(height: 8),
            _MediaAttachmentMetadataRow(
              icon: _availabilityIcon(resolvedMedia),
              text: availabilityLabel,
            ),
            if (mediaId != null && mediaId.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MediaAttachmentMetadataRow(
                icon: Icons.tag_outlined,
                text: mediaId,
              ),
            ],
            if (storagePath != null && storagePath.isNotEmpty) ...[
              const SizedBox(height: 6),
              _MediaAttachmentMetadataRow(
                icon: Icons.storage_outlined,
                text: storagePath,
              ),
            ],
            if (byteLength != null && byteLength > 0) ...[
              const SizedBox(height: 6),
              _MediaAttachmentMetadataRow(
                icon: Icons.data_object_outlined,
                text: _formatMediaByteLength(byteLength),
              ),
            ],
            if (filePath != null && filePath.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                filePath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('memory_media_inspect_${memory.id}'),
                onPressed: () => showAnchorMediaDetailSheet(
                  context,
                  memory: memory,
                ),
                icon: const Icon(Icons.info_outline),
                label: const Text('Inspect Media'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _attachmentAvailabilityLabel {
    if (attachment.hasBytes) {
      return 'Preview attached';
    }
    if (attachment.isStored) {
      return 'Preview cache missing';
    }
    return 'Media pending';
  }

  IconData _availabilityIcon(AnchorResolvedMedia? resolvedMedia) {
    if (resolvedMedia?.hasCachedPreview == true) {
      return Icons.cloud_done_outlined;
    }
    if (resolvedMedia?.isPreviewCacheMissing == true) {
      return Icons.cloud_off_outlined;
    }
    return Icons.info_outline;
  }
}

class _MediaAttachmentMetadataRow extends StatelessWidget {
  const _MediaAttachmentMetadataRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

String _formatMediaByteLength(int byteLength) {
  if (byteLength < 1024) {
    return '$byteLength B stored';
  }
  final kib = byteLength / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB stored';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB stored';
}

class _PrecisionRow extends StatelessWidget {
  const _PrecisionRow({
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

class _MemoryPreview extends StatelessWidget {
  const _MemoryPreview({
    required this.memory,
    this.resolvedMedia,
  });

  final AnchorMemory memory;
  final AnchorResolvedMedia? resolvedMedia;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaAttachment = memory.mediaAttachment;

    final imageBytes = resolvedMedia?.previewBytes;
    if (imageBytes != null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageBytes,
            key: ValueKey('memory_media_image_${memory.id}'),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _MemoryPreviewFallback(
                memory: memory,
                colorScheme: colorScheme,
                mediaAttachment: mediaAttachment,
              );
            },
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: _MemoryPreviewFallback(
        memory: memory,
        colorScheme: colorScheme,
        mediaAttachment: mediaAttachment,
      ),
    );
  }
}

class _MemoryPreviewFallback extends StatelessWidget {
  const _MemoryPreviewFallback({
    required this.memory,
    required this.colorScheme,
    required this.mediaAttachment,
  });

  final AnchorMemory memory;
  final ColorScheme colorScheme;
  final AnchorMediaAttachment? mediaAttachment;

  @override
  Widget build(BuildContext context) {
    final attachment = mediaAttachment;
    final icon = attachment == null
        ? memory.hasArExperience
            ? Icons.view_in_ar
            : Icons.photo
        : anchorMediaIconFor(attachment.type);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: memory.isPrivate
            ? colorScheme.tertiaryContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: colorScheme.onPrimaryContainer,
              size: 72,
            ),
            if (attachment != null) ...[
              const SizedBox(height: 8),
              Text(
                attachment.detailLabel,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
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
