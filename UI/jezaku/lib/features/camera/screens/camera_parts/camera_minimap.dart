part of '../camera_screen.dart';

String? _wallRouteLabelFor({
  required List<CaptureMinimapDot> dots,
  required Map<String, List<String>> wallTitlesByMemoryId,
}) {
  if (dots.length < 2) {
    return null;
  }

  final wallStopCounts = <String, int>{};
  for (final dot in dots) {
    final titles = wallTitlesByMemoryId[dot.memoryId] ?? const <String>[];
    for (final title in titles.toSet()) {
      wallStopCounts.update(title, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  if (wallStopCounts.isEmpty) {
    return null;
  }

  final wallsByCoverage = wallStopCounts.entries.toList()
    ..sort((a, b) {
      final countComparison = b.value.compareTo(a.value);
      if (countComparison != 0) {
        return countComparison;
      }
      return a.key.compareTo(b.key);
    });
  final primaryWall = wallsByCoverage.first.key;
  final extraWallCount = wallsByCoverage.length - 1;
  if (extraWallCount == 0) {
    return primaryWall;
  }

  return '$primaryWall + $extraWallCount '
      'wall${extraWallCount == 1 ? '' : 's'}';
}

enum _CaptureMinimapFilter {
  all,
  privateAnchors,
  publicAnchors,
  wallLinked,
  qualityIssues,
}

extension _CaptureMinimapFilterDetails on _CaptureMinimapFilter {
  String get label {
    return switch (this) {
      _CaptureMinimapFilter.all => 'All',
      _CaptureMinimapFilter.publicAnchors => 'Public',
      _CaptureMinimapFilter.privateAnchors => 'Private',
      _CaptureMinimapFilter.wallLinked => 'Walls',
      _CaptureMinimapFilter.qualityIssues => 'Quality',
    };
  }

  bool matches(CaptureMinimapDot dot, Set<String> wallLinkedMemoryIds) {
    return switch (this) {
      _CaptureMinimapFilter.all => true,
      _CaptureMinimapFilter.publicAnchors => !dot.isPrivate,
      _CaptureMinimapFilter.privateAnchors => dot.isPrivate,
      _CaptureMinimapFilter.wallLinked =>
        wallLinkedMemoryIds.contains(dot.memoryId),
      _CaptureMinimapFilter.qualityIssues => dot.hasRecordingQualityIssue,
    };
  }

  String countLabel(int count) {
    return switch (this) {
      _CaptureMinimapFilter.all => '$count in range',
      _CaptureMinimapFilter.publicAnchors => '$count public',
      _CaptureMinimapFilter.privateAnchors => '$count private',
      _CaptureMinimapFilter.wallLinked => '$count with walls',
      _CaptureMinimapFilter.qualityIssues => '$count quality',
    };
  }
}

class _CaptureMinimap extends StatelessWidget {
  const _CaptureMinimap({
    required this.snapshot,
    required this.anchors,
    required this.wallLinkedMemoryIds,
    required this.wallTitlesByMemoryId,
    required this.isExpanded,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onToggle,
    required this.onStartTrail,
  });

  static const _radiusMeters = 100.0;

  final CaptureSensorSnapshot snapshot;
  final List<AnchorMemory> anchors;
  final Set<String> wallLinkedMemoryIds;
  final Map<String, List<String>> wallTitlesByMemoryId;
  final bool isExpanded;
  final _CaptureMinimapFilter selectedFilter;
  final ValueChanged<_CaptureMinimapFilter> onFilterChanged;
  final VoidCallback onToggle;
  final ValueChanged<List<CaptureMinimapDot>> onStartTrail;

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return _RoundCameraButton(
        tooltip: 'Show minimap',
        icon: Icons.radar,
        onPressed: onToggle,
      );
    }

    const minimapService = CaptureMinimapService();
    final allDots = minimapService.dotsFor(
      snapshot: snapshot,
      anchors: anchors,
      radiusMeters: _radiusMeters,
    );
    final dots = [
      for (final dot in allDots)
        if (selectedFilter.matches(dot, wallLinkedMemoryIds)) dot,
    ];
    final filterCounts = {
      for (final filter in _CaptureMinimapFilter.values)
        filter: allDots
            .where((dot) => filter.matches(dot, wallLinkedMemoryIds))
            .length,
    };
    final trailSummary = minimapService.trailSummaryFor(
      dots,
      wallLinkedMemoryIds: wallLinkedMemoryIds,
    );
    final wallRouteLabel = _wallRouteLabelFor(
      dots: dots,
      wallTitlesByMemoryId: wallTitlesByMemoryId,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: SizedBox(
        width: 168,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Nearby media',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize minimap',
                    onPressed: onToggle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    iconSize: 16,
                    color: Colors.white,
                    icon: const Icon(Icons.close_fullscreen),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  const Text(
                    '100 m radius',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    selectedFilter.countLabel(dots.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MinimapFilterChips(
                selectedFilter: selectedFilter,
                counts: filterCounts,
                onSelected: onFilterChanged,
              ),
              const SizedBox(height: 8),
              SizedBox.square(
                dimension: 104,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MinimapPainter(
                          dots: dots,
                          wallLinkedMemoryIds: wallLinkedMemoryIds,
                          headingDegrees: snapshot.headingDegrees,
                          colorScheme: colorScheme,
                          radiusMeters: _radiusMeters,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _MinimapDotHitTargets(
                        dots: dots,
                        radiusMeters: _radiusMeters,
                        onTap: (dot) => _showDotPreview(context, dot),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailSummary != null) ...[
                const SizedBox(height: 8),
                _MinimapTrailSummaryPanel(
                  summary: trailSummary,
                  wallRouteLabel: wallRouteLabel,
                ),
              ],
              if (dots.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Nearest ${dots.first.title} - '
                  '${dots.first.distanceLabel} ${dots.first.directionLabel}',
                  key: const ValueKey('minimap_nearest_dot_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  'No dots match this filter',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                  ),
                ),
              ],
              if (dots.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('minimap_start_ar_trail_button'),
                    onPressed: () => _showTrailPreview(
                      context,
                      dots: dots,
                      summary: trailSummary,
                      wallRouteLabel: wallRouteLabel,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.route_outlined, size: 16),
                    label: Text(
                      '${trailSummary?.stopCount ?? dots.length} stop AR trail',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MinimapLegend(color: Colors.white, label: 'You'),
                  _MinimapLegend(color: Colors.lightBlueAccent, label: 'Media'),
                  _MinimapLegend(
                    color: Colors.deepOrangeAccent,
                    label: 'Quality',
                  ),
                  _MinimapLegend(color: Colors.amberAccent, label: 'Private'),
                  _MinimapLegend(color: Colors.cyanAccent, label: 'Wall'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrailPreview(
    BuildContext context, {
    required List<CaptureMinimapDot> dots,
    required CaptureMinimapTrailSummary? summary,
    required String? wallRouteLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final route = summary?.route ??
            const ARTrailRouteService().routeFor(
              points: _trailRoutePointsForDots(dots),
            );

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.route_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Preview AR trail',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          if (wallRouteLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              wallRouteLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                ),
                                label: Text('${dots.length} stops'),
                              ),
                              if (summary != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.directions_walk,
                                    size: 18,
                                  ),
                                  label: Text(summary.routeEffortLabel),
                                ),
                              if (summary != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.explore_outlined,
                                    size: 18,
                                  ),
                                  label: Text(summary.routeContextLabel),
                                ),
                              if (summary != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.privacy_tip_outlined,
                                    size: 18,
                                  ),
                                  label: Text(summary.advisoryLabel),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          for (var index = 0; index < dots.length; index++) ...[
                            _TrailPreviewStopTile(
                              stopNumber: index + 1,
                              dot: dots[index],
                              wallTitles:
                                  wallTitlesByMemoryId[dots[index].memoryId] ??
                                      const <String>[],
                            ),
                            if (index < dots.length - 1) ...[
                              _TrailPreviewLegTile(
                                leg: route.legs[index],
                              ),
                              const Divider(height: 1),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('minimap_confirm_ar_trail_button'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onStartTrail(dots);
                      },
                      icon: const Icon(Icons.view_in_ar),
                      label: const Text('Start AR trail'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDotPreview(BuildContext context, CaptureMinimapDot dot) {
    final wallTitles = wallTitlesByMemoryId[dot.memoryId] ?? const <String>[];
    final turnLabel = dot.turnLabelFrom(snapshot.headingDegrees);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      dot.hasRecordingQualityIssue
                          ? Icons.warning_amber_rounded
                          : dot.needsCalibrationReview
                              ? Icons.warning_amber
                              : dot.isPrivate
                                  ? Icons.lock_outline
                                  : Icons.photo_outlined,
                      color: dot.hasRecordingQualityIssue ||
                              dot.needsCalibrationReview
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dot.title,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dot.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.near_me_outlined, size: 18),
                      label: Text(dot.distanceLabel),
                    ),
                    Chip(
                      avatar: const Icon(Icons.explore_outlined, size: 18),
                      label: Text(dot.bearingLabel),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.screen_rotation_alt_outlined,
                        size: 18,
                      ),
                      label: Text(turnLabel),
                    ),
                    Chip(
                      avatar: Icon(
                        dot.isPrivate ? Icons.lock_outline : Icons.public,
                        size: 18,
                      ),
                      label: Text(dot.isPrivate ? 'Private' : 'Public'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.gps_fixed, size: 18),
                      label: Text(dot.anchorHealthLabel),
                    ),
                    if (dot.mediaTypeLabel != null)
                      Chip(
                        avatar: const Icon(Icons.perm_media_outlined, size: 18),
                        label: Text(dot.mediaTypeLabel!),
                      ),
                    if (dot.recordingQualitySummaryLabel != null)
                      Chip(
                        avatar: const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                        ),
                        label: Text(dot.recordingQualitySummaryLabel!),
                      ),
                    Chip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      label: Text(dot.locationLabel),
                    ),
                    for (final wallTitle in wallTitles)
                      Chip(
                        avatar: const Icon(Icons.grid_view, size: 18),
                        label: Text(wallTitle),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.pushNamed(
                            context,
                            AppRoutes.memoryDetails,
                            arguments: dot.memoryId,
                          );
                        },
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Open details'),
                      ),
                    ),
                    if (dot.hasArExperience) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.pushNamed(
                              context,
                              AppRoutes.arViewer,
                              arguments: dot.memoryId,
                            );
                          },
                          icon: const Icon(Icons.view_in_ar),
                          label: const Text('View AR'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<ARTrailRoutePoint> _trailRoutePointsForDots(
  List<CaptureMinimapDot> dots,
) {
  return [
    for (final dot in dots)
      ARTrailRoutePoint(
        memoryId: dot.memoryId,
        title: dot.title,
        latitude: dot.latitude,
        longitude: dot.longitude,
        distanceFromOriginMeters: dot.distanceMeters,
        bearingFromOriginDegrees: dot.bearingDegrees,
        isPrivate: dot.isPrivate,
        needsCalibrationReview: dot.needsCalibrationReview,
      ),
  ];
}
