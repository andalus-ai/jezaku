import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';

class CalibrationReviewScreen extends ConsumerStatefulWidget {
  const CalibrationReviewScreen({super.key});

  @override
  ConsumerState<CalibrationReviewScreen> createState() =>
      _CalibrationReviewScreenState();
}

class _CalibrationReviewScreenState
    extends ConsumerState<CalibrationReviewScreen> {
  _CalibrationReviewFilter _filter = _CalibrationReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(calibrationReviewMemoriesProvider);
    final filteredMemories =
        memories.where((memory) => _filter.matches(memory)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calibration Review')),
      body: memories.isEmpty
          ? const _EmptyCalibrationState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CalibrationQueueSummary(
                  memories: memories,
                  actionMemories: filteredMemories,
                  selectedFilter: _filter,
                  onApplyAllSuggestions: () => _applyAllSuggestions(
                    context,
                    filteredMemories,
                  ),
                ),
                const SizedBox(height: 12),
                _CalibrationFilterBar(
                  memories: memories,
                  selectedFilter: _filter,
                  onSelected: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: 12),
                if (filteredMemories.isEmpty)
                  _FilteredCalibrationEmptyState(filter: _filter)
                else
                  for (final memory in filteredMemories) ...[
                    _CalibrationReviewCard(memory: memory),
                    if (memory != filteredMemories.last)
                      const SizedBox(height: 12),
                  ],
              ],
            ),
    );
  }

  void _applyAllSuggestions(
    BuildContext context,
    List<AnchorMemory> memories,
  ) {
    if (memories.isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(nearbyAnchorsProvider.notifier);
    final previousMetadataById = <String, AnchorCaptureMetadata>{
      for (final memory in memories) memory.id: memory.captureMetadata,
    };

    for (final memory in memories) {
      final suggestion = memory.captureMetadata.suggestedCorrection;
      controller.updateManualCorrection(
        memoryId: memory.id,
        eastMeters: suggestion.eastMeters,
        northMeters: suggestion.northMeters,
        upMeters: suggestion.upMeters,
      );
    }

    final correctionLabel = memories.length == 1 ? 'correction' : 'corrections';
    final anchorLabel = memories.length == 1 ? 'anchor' : 'anchors';
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Applied ${memories.length} suggested $correctionLabel.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              for (final memory in memories) {
                final previousMetadata = previousMetadataById[memory.id]!;
                controller.updateManualCorrection(
                  memoryId: memory.id,
                  eastMeters: previousMetadata.correctionEastMeters,
                  northMeters: previousMetadata.correctionNorthMeters,
                  upMeters: previousMetadata.correctionUpMeters,
                  correctedAt: previousMetadata.manualCorrectionSavedAt,
                  anchorType: previousMetadata.anchorType,
                );
              }
              messenger
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Restored ${memories.length} calibration $anchorLabel.',
                    ),
                  ),
                );
            },
          ),
        ),
      );
  }
}

enum _CalibrationReviewFilter {
  all,
  gps,
  compass,
  tilt;

  String label(int count) {
    return switch (this) {
      all => 'All $count',
      gps => 'GPS $count',
      compass => 'Compass $count',
      tilt => 'Tilt $count',
    };
  }

  String applyLabel(int count) {
    if (count == 0) {
      return switch (this) {
        all => 'No suggestions',
        gps => 'No GPS suggestions',
        compass => 'No compass suggestions',
        tilt => 'No tilt suggestions',
      };
    }
    final suggestionLabel = count == 1 ? 'suggestion' : 'suggestions';
    return switch (this) {
      all => 'Apply $count $suggestionLabel',
      gps => 'Apply $count GPS $suggestionLabel',
      compass => 'Apply $count compass $suggestionLabel',
      tilt => 'Apply $count tilt $suggestionLabel',
    };
  }

  String get emptyTitle {
    return switch (this) {
      all => 'No anchors need calibration',
      gps => 'No GPS issues',
      compass => 'No compass issues',
      tilt => 'No tilt issues',
    };
  }

  String get emptyDescription {
    return switch (this) {
      all =>
        'GPS, compass, and tilt issues will appear here until a manual correction is saved.',
      gps => 'Anchors with high GPS drift will appear here.',
      compass => 'Anchors captured without a compass lock will appear here.',
      tilt => 'Anchors captured with high device tilt will appear here.',
    };
  }

  IconData get icon {
    return switch (this) {
      all => Icons.tune,
      gps => Icons.gps_fixed,
      compass => Icons.navigation,
      tilt => Icons.screen_rotation_alt,
    };
  }

  bool matches(AnchorMemory memory) {
    final metadata = memory.captureMetadata;
    return switch (this) {
      all => true,
      gps => metadata.hasGpsDrift,
      compass => metadata.hasCompassDrift,
      tilt => metadata.hasTiltDrift,
    };
  }
}

class _CalibrationQueueSummary extends StatelessWidget {
  const _CalibrationQueueSummary({
    required this.memories,
    required this.actionMemories,
    required this.selectedFilter,
    required this.onApplyAllSuggestions,
  });

  final List<AnchorMemory> memories;
  final List<AnchorMemory> actionMemories;
  final _CalibrationReviewFilter selectedFilter;
  final VoidCallback onApplyAllSuggestions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topMemory = memories.first;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
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
                  Icons.priority_high,
                  color: colorScheme.onPrimaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review priority',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  icon: Icons.tune,
                  label:
                      '${memories.length} anchor${memories.length == 1 ? '' : 's'} waiting',
                ),
                _SummaryChip(
                  icon: Icons.warning_amber,
                  label:
                      '$_totalIssueCount total placement issue${_totalIssueCount == 1 ? '' : 's'}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Most common: $_mostCommonIssueLabel',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              'Highest priority: ${topMemory.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey(
                  'calibration_review_apply_all_suggestions',
                ),
                onPressed:
                    actionMemories.isEmpty ? null : onApplyAllSuggestions,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(selectedFilter.applyLabel(actionMemories.length)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _totalIssueCount {
    return memories.fold<int>(
      0,
      (total, memory) => total + memory.captureMetadata.calibrationIssueCount,
    );
  }

  String get _mostCommonIssueLabel {
    final gpsCount = _countFor(_CalibrationReviewFilter.gps);
    final compassCount = _countFor(_CalibrationReviewFilter.compass);
    final tiltCount = _countFor(_CalibrationReviewFilter.tilt);
    if (gpsCount >= compassCount && gpsCount >= tiltCount) {
      return 'GPS drift high';
    }
    if (compassCount >= tiltCount) {
      return 'Compass unavailable';
    }
    return 'High tilt';
  }

  int _countFor(_CalibrationReviewFilter filter) {
    return memories.where(filter.matches).length;
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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

class _CalibrationFilterBar extends StatelessWidget {
  const _CalibrationFilterBar({
    required this.memories,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<AnchorMemory> memories;
  final _CalibrationReviewFilter selectedFilter;
  final ValueChanged<_CalibrationReviewFilter> onSelected;

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
            Text(
              'Review by issue',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in _CalibrationReviewFilter.values)
                  FilterChip(
                    avatar: Icon(filter.icon, size: 16),
                    label: Text(filter.label(_countFor(filter))),
                    selected: selectedFilter == filter,
                    onSelected: (_) => onSelected(filter),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _countFor(_CalibrationReviewFilter filter) {
    return memories.where(filter.matches).length;
  }
}

class _CalibrationReviewCard extends ConsumerWidget {
  const _CalibrationReviewCard({required this.memory});

  final AnchorMemory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = memory.captureMetadata;
    final colorScheme = Theme.of(context).colorScheme;
    final suggestion = metadata.suggestedCorrection;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
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
                  avatar: const Icon(Icons.warning_amber, size: 18),
                  label: Text(metadata.calibrationIssueCountLabel),
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
            const SizedBox(height: 12),
            _CalibrationReasonPanel(metadata: metadata),
            const SizedBox(height: 12),
            _SuggestedCorrectionPanel(suggestion: suggestion),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _ReviewMetric(
                  icon: Icons.gps_fixed,
                  label: metadata.accuracyLabel,
                ),
                _ReviewMetric(
                  icon: Icons.navigation,
                  label: metadata.headingLabel,
                ),
                _ReviewMetric(
                  icon: Icons.screen_rotation_alt,
                  label: metadata.attitudeLabel,
                ),
                _ReviewMetric(
                  icon: Icons.schedule,
                  label: memory.capturedTimelineLabel,
                ),
                _ReviewMetric(
                  icon: Icons.place_outlined,
                  label: memory.locationLabel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memoryDetails,
                    arguments: memory.id,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Details'),
                ),
                OutlinedButton.icon(
                  key: ValueKey('calibration_review_preview_ar_${memory.id}'),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.arViewer,
                    arguments: memory.id,
                  ),
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Preview AR'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memoryCalibration,
                    arguments: memory.id,
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('Calibrate'),
                ),
                FilledButton.icon(
                  key: ValueKey(
                    'calibration_review_apply_suggestion_${memory.id}',
                  ),
                  onPressed: () => _applySuggestedCorrection(
                    context,
                    ref,
                    memory,
                    suggestion,
                  ),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Apply suggestion'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applySuggestedCorrection(
    BuildContext context,
    WidgetRef ref,
    AnchorMemory memory,
    AnchorCalibrationSuggestion suggestion,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(nearbyAnchorsProvider.notifier);
    final previousMetadata = memory.captureMetadata;

    controller.updateManualCorrection(
      memoryId: memory.id,
      eastMeters: suggestion.eastMeters,
      northMeters: suggestion.northMeters,
      upMeters: suggestion.upMeters,
    );

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Suggested correction applied to ${memory.title}.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              controller.updateManualCorrection(
                memoryId: memory.id,
                eastMeters: previousMetadata.correctionEastMeters,
                northMeters: previousMetadata.correctionNorthMeters,
                upMeters: previousMetadata.correctionUpMeters,
                correctedAt: previousMetadata.manualCorrectionSavedAt,
                anchorType: previousMetadata.anchorType,
              );
              messenger
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Correction restored for ${memory.title}.'),
                  ),
                );
            },
          ),
        ),
      );
  }
}

class _CalibrationReasonPanel extends StatelessWidget {
  const _CalibrationReasonPanel({required this.metadata});

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
              color: colorScheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.calibrationReasonLabel,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadata.calibrationGuidanceLabel,
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

class _SuggestedCorrectionPanel extends StatelessWidget {
  const _SuggestedCorrectionPanel({required this.suggestion});

  final AnchorCalibrationSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_fix_high,
              color: colorScheme.onSecondaryContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.offsetLabel,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.description,
                    style: TextStyle(color: colorScheme.onSecondaryContainer),
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

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
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
            Icon(icon, color: colorScheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCalibrationState extends StatelessWidget {
  const _EmptyCalibrationState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, color: colorScheme.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              'No anchors need calibration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'GPS, compass, and tilt issues will appear here until a manual correction is saved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredCalibrationEmptyState extends StatelessWidget {
  const _FilteredCalibrationEmptyState({required this.filter});

  final _CalibrationReviewFilter filter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(filter.icon, color: colorScheme.primary, size: 44),
          const SizedBox(height: 10),
          Text(
            filter.emptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            filter.emptyDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
