import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_map_point.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_list_tile.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenTrailProfile,
  });

  final VoidCallback? onOpenTrailProfile;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _mapRadiusMeters = 100.0;

  String _filter = 'Nearby';

  List<AnchorMemory> _visibleAnchors(
    List<AnchorMemory> anchors,
    Set<String> wallLinkedMemoryIds,
  ) {
    return switch (_filter) {
      'Private' => anchors.where((anchor) => anchor.isPrivate).toList(),
      'AR' => anchors.where((anchor) => anchor.hasArExperience).toList(),
      'Media' => anchors.where((anchor) => anchor.hasMediaAttachment).toList(),
      'Walls' => anchors
          .where((anchor) => wallLinkedMemoryIds.contains(anchor.id))
          .toList(),
      'Needs Calibration' =>
        anchors.where((anchor) => anchor.needsCalibrationReview).toList(),
      _ => anchors,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final anchors = ref.watch(nearbyAnchorsProvider);
    final activeTrailProgress = ref.watch(activeARTrailProgressProvider);
    final trailSummary = ref.watch(completedARTrailHistorySummaryProvider);
    final savedTrails = ref.watch(savedARTrailsProvider);
    final trailAchievements = ref.watch(arTrailAchievementsProvider);
    final trailLifetimeStats = ref.watch(arTrailLifetimeStatsProvider);
    final recentUnlocks = ref.watch(arTrailAchievementUnlocksProvider);
    final walls = ref.watch(arWallsProvider);
    final wallLinkedMemoryIds = _wallLinkedMemoryIds(walls);
    final visibleAnchors = _visibleAnchors(anchors, wallLinkedMemoryIds);
    final journeySteps = ref.watch(spatialJourneyProvider);
    final visibleAnchorIds = visibleAnchors.map((anchor) => anchor.id).toSet();
    final visibleJourneySteps = journeySteps
        .where((step) => visibleAnchorIds.contains(step.memory.id))
        .toList();
    final mapPoints =
        visibleJourneySteps.map((step) => step.point).toList(growable: false);
    final nearestPoint = mapPoints.isEmpty ? null : mapPoints.first;
    final firstTrailStep =
        visibleJourneySteps.isEmpty ? null : visibleJourneySteps.first;
    final wallLinkedVisibleCount = visibleAnchors
        .where((anchor) => wallLinkedMemoryIds.contains(anchor.id))
        .length;
    final hasActiveTrail =
        activeTrailProgress != null && !activeTrailProgress.isFinished;
    final shouldShowTrailPulse = !hasActiveTrail &&
        _hasTrailPulse(
          trailSummary: trailSummary,
          savedTrails: savedTrails,
          recentUnlocks: recentUnlocks,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jejaku',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.memorySearch,
            ),
          ),
          IconButton(
            tooltip: 'Virtual walls',
            icon: const Icon(Icons.grid_view),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.virtualWalls);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MapGridPainter(
                        lineColor: colorScheme.outlineVariant,
                        primaryColor: colorScheme.primary,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            ..._buildMapPins(
                              mapPoints,
                              constraints.biggest,
                            ),
                            _ViewerPositionDot(size: constraints.biggest),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _StatusPill(
                      icon: Icons.gps_fixed,
                      label: 'GPS +/- 3.2 m',
                      color: Colors.green.shade600,
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _MapContextPanel(
                      anchorCount: mapPoints.length,
                      radiusMeters: _mapRadiusMeters,
                      nearestPoint: nearestPoint,
                      wallLinkedCount: wallLinkedVisibleCount,
                      trailStopCount: visibleJourneySteps.length,
                      trailSummaryLabel: firstTrailStep?.remainingRouteLabel,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _MapActionBar(
                      canStartTrail: journeySteps.isNotEmpty,
                      canStartArTrail: visibleJourneySteps.isNotEmpty,
                      onStartTrail: journeySteps.isEmpty
                          ? null
                          : () => _openMemoryDetails(journeySteps.first.memory),
                      onStartArTrail: visibleJourneySteps.isEmpty
                          ? null
                          : () => _openArTrail(visibleJourneySteps),
                      onOpenArView: () {
                        Navigator.pushNamed(context, AppRoutes.arViewer);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Nearby Memories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _CountBadge(count: visibleAnchors.length),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'Nearby',
                          selected: _filter == 'Nearby',
                          onSelected: () => setState(() => _filter = 'Nearby'),
                        ),
                        _FilterChip(
                          label: 'AR',
                          selected: _filter == 'AR',
                          onSelected: () => setState(() => _filter = 'AR'),
                        ),
                        _FilterChip(
                          label: 'Media',
                          selected: _filter == 'Media',
                          onSelected: () => setState(() => _filter = 'Media'),
                        ),
                        _FilterChip(
                          label: 'Private',
                          selected: _filter == 'Private',
                          onSelected: () => setState(() => _filter = 'Private'),
                        ),
                        _FilterChip(
                          label: 'Walls',
                          selected: _filter == 'Walls',
                          onSelected: () => setState(() => _filter = 'Walls'),
                        ),
                        _FilterChip(
                          label: 'Needs Calibration',
                          selected: _filter == 'Needs Calibration',
                          onSelected: () =>
                              setState(() => _filter = 'Needs Calibration'),
                        ),
                      ],
                    ),
                  ),
                  if (hasActiveTrail) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: _ContinueARTrailCard(
                        progress: activeTrailProgress,
                        currentStopTitle:
                            _anchorTitleFor(anchors, activeTrailProgress),
                        onResume: () => _resumeArTrail(activeTrailProgress),
                      ),
                    ),
                  ],
                  if (shouldShowTrailPulse) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: _TrailPulseCard(
                        summary: trailSummary,
                        savedTrails: savedTrails,
                        achievements: trailAchievements,
                        lifetimeStats: trailLifetimeStats,
                        recentUnlocks: recentUnlocks,
                        onOpenProfile: widget.onOpenTrailProfile,
                        onReplayTrail: _replayTrail,
                        onStartNearbyTrail: visibleJourneySteps.isEmpty
                            ? null
                            : () => _openArTrail(visibleJourneySteps),
                        onOpenRoute: _openTrailPulseRoute,
                      ),
                    ),
                  ],
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: visibleAnchors.length,
                      itemBuilder: (context, index) {
                        final anchor = visibleAnchors[index];
                        final linkedWalls = wallsLinkedToMemory(
                          anchor.id,
                          walls,
                        );
                        return AnchorListTile(
                          anchor: anchor,
                          linkedWallLabel: _linkedWallLabel(linkedWalls),
                          onTap: () => _openMemoryDetails(anchor),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _wallLinkedMemoryIds(List<ARWall> walls) {
    return {
      for (final wall in walls) ...wall.linkedMemoryIds,
    };
  }

  String? _linkedWallLabel(List<ARWall> walls) {
    if (walls.isEmpty) {
      return null;
    }
    if (walls.length == 1) {
      return walls.single.title;
    }
    return '${walls.length} virtual walls';
  }

  String? _anchorTitleFor(
    List<AnchorMemory> anchors,
    ARTrailProgress progress,
  ) {
    for (final anchor in anchors) {
      if (anchor.id == progress.currentMemoryId) {
        return anchor.title;
      }
    }
    return null;
  }

  List<Widget> _buildMapPins(List<AnchorMapPoint> points, Size size) {
    const pinWidth = 84.0;
    const pinHeight = 64.0;
    const edgePadding = 10.0;
    final mapRadius = _mapRadiusFor(size);
    final center = Offset(size.width / 2, size.height / 2);

    return [
      for (final point in points)
        Positioned(
          left: (center.dx + point.eastFraction * mapRadius - pinWidth / 2)
              .clamp(edgePadding, size.width - pinWidth - edgePadding)
              .toDouble(),
          top: (center.dy - point.northFraction * mapRadius - pinHeight / 2)
              .clamp(edgePadding, size.height - pinHeight - edgePadding)
              .toDouble(),
          child: _MapPin(
            point: point,
            onTap: () => _openMemoryDetails(point.memory),
          ),
        ),
    ];
  }

  void _openMemoryDetails(AnchorMemory anchor) {
    Navigator.pushNamed(
      context,
      AppRoutes.memoryDetails,
      arguments: anchor.id,
    );
  }

  void _openArTrail(List<AnchorJourneyStep> steps) {
    if (steps.isEmpty) {
      return;
    }

    final memoryIds = [for (final step in steps) step.memory.id];
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(
        ARTrailSession.fromMemoryIds(
          title: 'Nearby memory trail',
          memoryIds: memoryIds,
          source: ARTrailSource.nearby,
        ),
      ),
    );
  }

  void _resumeArTrail(ARTrailProgress progress) {
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.resume(progress),
    );
  }

  void _replayTrail(ARTrailSession session) {
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(session),
    );
  }

  void _openTrailPulseRoute(String routeName) {
    if (routeName == AppRoutes.root) {
      return;
    }
    Navigator.pushNamed(context, routeName);
  }
}

class _ContinueARTrailCard extends StatelessWidget {
  const _ContinueARTrailCard({
    required this.progress,
    required this.currentStopTitle,
    required this.onResume,
  });

  final ARTrailProgress progress;
  final String? currentStopTitle;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTitle = currentStopTitle?.trim();

    return DecoratedBox(
      key: const ValueKey('home_continue_ar_trail_card'),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              child: const Icon(Icons.route_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Continue AR trail',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progress.session.title,
                    key: const ValueKey('home_continue_ar_trail_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${progress.currentStopLabel} - ${progress.progressLabel}',
                      if (currentTitle != null && currentTitle.isNotEmpty)
                        currentTitle,
                      _remainingStopCountLabel(progress),
                    ].join(' - '),
                    key: const ValueKey('home_continue_ar_trail_progress'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer
                          .withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('home_continue_ar_trail_resume_button'),
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}

String _remainingStopCountLabel(ARTrailProgress progress) {
  final remainingStopCount = progress.totalStops - progress.completedStopCount;
  if (remainingStopCount <= 0) {
    return 'ready to finish';
  }
  final stopLabel = remainingStopCount == 1 ? 'stop' : 'stops';
  return '$remainingStopCount $stopLabel left';
}

class _TrailPulseCard extends StatelessWidget {
  const _TrailPulseCard({
    required this.summary,
    required this.savedTrails,
    required this.achievements,
    required this.lifetimeStats,
    required this.recentUnlocks,
    required this.onOpenProfile,
    required this.onReplayTrail,
    required this.onStartNearbyTrail,
    required this.onOpenRoute,
  });

  final ARTrailHistorySummary summary;
  final List<SavedARTrail> savedTrails;
  final List<ARTrailAchievement> achievements;
  final ARTrailLifetimeStats lifetimeStats;
  final List<ARTrailAchievementUnlock> recentUnlocks;
  final VoidCallback? onOpenProfile;
  final ValueChanged<ARTrailSession>? onReplayTrail;
  final VoidCallback? onStartNearbyTrail;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final latestUnlock = recentUnlocks.isEmpty ? null : recentUnlocks.first;
    final latestSavedTrail = savedTrails.isEmpty ? null : savedTrails.first;
    final replaySession =
        latestSavedTrail?.session ?? summary.latestTrail?.session;
    final replayTooltip = latestSavedTrail == null
        ? 'Replay latest completed trail'
        : 'Replay latest saved trail';
    final nextAchievement = _nextTrailAchievement(achievements);
    final goalAction = _trailPulseGoalAction(
      achievements: achievements,
      lifetimeStats: lifetimeStats,
      onStartNearbyTrail: onStartNearbyTrail,
      onOpenRoute: onOpenRoute,
      onOpenProfile: onOpenProfile,
    );

    return DecoratedBox(
      key: const ValueKey('home_trail_pulse_card'),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.insights_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Trail Pulse',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _trailPulseStatsLabel(
                      summary: summary,
                      savedTrails: savedTrails,
                    ),
                    key: const ValueKey('home_trail_pulse_stats'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _trailPulseGoalLabel(
                      nextAchievement: nextAchievement,
                      latestUnlock: latestUnlock,
                    ),
                    key: const ValueKey('home_trail_pulse_goal'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (nextAchievement != null) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      key: const ValueKey('home_trail_pulse_goal_progress'),
                      minHeight: 4,
                      value: nextAchievement.progressRatio.clamp(0.0, 1.0),
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.42,
                      ),
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ],
                ],
              ),
            ),
            if (goalAction != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('home_trail_pulse_goal_button'),
                tooltip: goalAction.tooltip,
                onPressed: goalAction.onPressed,
                icon: Icon(goalAction.icon),
              ),
            ],
            if (replaySession != null && onReplayTrail != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('home_trail_pulse_replay_button'),
                tooltip: replayTooltip,
                onPressed: () => onReplayTrail!(replaySession),
                icon: const Icon(Icons.play_arrow),
              ),
            ],
            if (onOpenProfile != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('home_trail_pulse_profile_button'),
                tooltip: 'Open trail library',
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrailPulseAction {
  const _TrailPulseAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

bool _hasTrailPulse({
  required ARTrailHistorySummary trailSummary,
  required List<SavedARTrail> savedTrails,
  required List<ARTrailAchievementUnlock> recentUnlocks,
}) {
  return trailSummary.hasHistory ||
      savedTrails.isNotEmpty ||
      recentUnlocks.isNotEmpty;
}

_TrailPulseAction? _trailPulseGoalAction({
  required List<ARTrailAchievement> achievements,
  required ARTrailLifetimeStats lifetimeStats,
  required VoidCallback? onStartNearbyTrail,
  required ValueChanged<String> onOpenRoute,
  required VoidCallback? onOpenProfile,
}) {
  final nextAchievement = _nextTrailAchievement(achievements);
  if (nextAchievement == null) {
    return null;
  }

  switch (nextAchievement.id) {
    case ARTrailAchievementId.firstTrail:
    case ARTrailAchievementId.stopCollector:
      final startNearbyTrail = onStartNearbyTrail;
      if (startNearbyTrail == null) {
        return null;
      }
      return _TrailPulseAction(
        icon: Icons.near_me_outlined,
        tooltip: 'Start nearby AR trail for ${nextAchievement.title}',
        onPressed: startNearbyTrail,
      );
    case ARTrailAchievementId.cameraExplorer:
      return _routeTrailPulseAction(
        source: ARTrailSource.camera,
        tooltip: 'Open camera for ${nextAchievement.title}',
        onOpenRoute: onOpenRoute,
      );
    case ARTrailAchievementId.wallExplorer:
      return _routeTrailPulseAction(
        source: ARTrailSource.virtualWall,
        tooltip: 'Open virtual walls for ${nextAchievement.title}',
        onOpenRoute: onOpenRoute,
      );
    case ARTrailAchievementId.sourceSampler:
      final suggestedSources = lifetimeStats.suggestedSources();
      final source = suggestedSources.isEmpty
          ? ARTrailSource.nearby
          : suggestedSources.first;
      if (source == ARTrailSource.nearby && onStartNearbyTrail != null) {
        return _TrailPulseAction(
          icon: _trailSourceIcon(source),
          tooltip: 'Start nearby AR trail for ${nextAchievement.title}',
          onPressed: onStartNearbyTrail,
        );
      }
      return _routeTrailPulseAction(
        source: source,
        tooltip: 'Try ${source.label} for ${nextAchievement.title}',
        onOpenRoute: onOpenRoute,
      );
    case ARTrailAchievementId.routeKeeper:
      final openProfile = onOpenProfile;
      if (openProfile == null) {
        return null;
      }
      return _TrailPulseAction(
        icon: Icons.route_outlined,
        tooltip: 'Open trail library for ${nextAchievement.title}',
        onPressed: openProfile,
      );
  }
}

_TrailPulseAction _routeTrailPulseAction({
  required ARTrailSource source,
  required String tooltip,
  required ValueChanged<String> onOpenRoute,
}) {
  return _TrailPulseAction(
    icon: _trailSourceIcon(source),
    tooltip: tooltip,
    onPressed: () => onOpenRoute(_routeForTrailSource(source)),
  );
}

String _trailPulseStatsLabel({
  required ARTrailHistorySummary summary,
  required List<SavedARTrail> savedTrails,
}) {
  final savedTrailLabel =
      savedTrails.length == 1 ? 'saved trail' : 'saved trails';
  if (summary.hasHistory) {
    return '${summary.completedTrailLabel} - '
        '${summary.reachedStopLabel} - '
        '${savedTrails.length} $savedTrailLabel';
  }

  return '${savedTrails.length} $savedTrailLabel';
}

String _trailPulseGoalLabel({
  required ARTrailAchievement? nextAchievement,
  required ARTrailAchievementUnlock? latestUnlock,
}) {
  if (nextAchievement != null) {
    return 'Next ${nextAchievement.title} - ${nextAchievement.progressLabel}';
  }

  if (latestUnlock != null) {
    return 'Latest ${latestUnlock.title} unlocked';
  }

  return 'All trail goals complete';
}

ARTrailAchievement? _nextTrailAchievement(
  List<ARTrailAchievement> achievements,
) {
  ARTrailAchievement? nextAchievement;
  for (final achievement in achievements) {
    if (achievement.isUnlocked) {
      continue;
    }
    if (nextAchievement == null ||
        achievement.progressRatio > nextAchievement.progressRatio) {
      nextAchievement = achievement;
    }
  }
  return nextAchievement;
}

IconData _trailSourceIcon(ARTrailSource source) {
  return switch (source) {
    ARTrailSource.nearby => Icons.near_me_outlined,
    ARTrailSource.camera => Icons.photo_camera_outlined,
    ARTrailSource.discover => Icons.explore_outlined,
    ARTrailSource.gallery => Icons.photo_library_outlined,
    ARTrailSource.search => Icons.search,
    ARTrailSource.virtualWall => Icons.view_in_ar_outlined,
    ARTrailSource.memoryDetails => Icons.place_outlined,
    ARTrailSource.custom => Icons.route_outlined,
  };
}

String _routeForTrailSource(ARTrailSource source) {
  return switch (source) {
    ARTrailSource.nearby => AppRoutes.root,
    ARTrailSource.camera => AppRoutes.camera,
    ARTrailSource.discover => AppRoutes.memorySearch,
    ARTrailSource.gallery => AppRoutes.gallery,
    ARTrailSource.search => AppRoutes.memorySearch,
    ARTrailSource.virtualWall => AppRoutes.virtualWalls,
    ARTrailSource.memoryDetails => AppRoutes.memorySearch,
    ARTrailSource.custom => AppRoutes.arViewer,
  };
}

class _MapContextPanel extends StatelessWidget {
  const _MapContextPanel({
    required this.anchorCount,
    required this.radiusMeters,
    required this.nearestPoint,
    required this.wallLinkedCount,
    required this.trailStopCount,
    required this.trailSummaryLabel,
  });

  final int anchorCount;
  final double radiusMeters;
  final AnchorMapPoint? nearestPoint;
  final int wallLinkedCount;
  final int trailStopCount;
  final String? trailSummaryLabel;

  @override
  Widget build(BuildContext context) {
    final nearest = nearestPoint;
    final anchorLabel = anchorCount == 1 ? 'anchor' : 'anchors';

    return DecoratedBox(
      key: const ValueKey('home_map_context_panel'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${radiusMeters.round()} m perimeter',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$anchorCount $anchorLabel mapped',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 11,
              ),
            ),
            if (wallLinkedCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$wallLinkedCount with walls',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 11,
                ),
              ),
            ],
            if (nearest != null) ...[
              const SizedBox(height: 2),
              Text(
                'Nearest ${nearest.distanceLabel} ${nearest.directionLabel}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 11,
                ),
              ),
            ],
            if (trailStopCount > 1) ...[
              const SizedBox(height: 2),
              Text(
                'Trail $trailStopCount stops',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 11,
                ),
              ),
              if (trailSummaryLabel != null)
                Text(
                  trailSummaryLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 11,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapActionBar extends StatelessWidget {
  const _MapActionBar({
    required this.canStartTrail,
    required this.canStartArTrail,
    required this.onStartTrail,
    required this.onStartArTrail,
    required this.onOpenArView,
  });

  final bool canStartTrail;
  final bool canStartArTrail;
  final VoidCallback? onStartTrail;
  final VoidCallback? onStartArTrail;
  final VoidCallback onOpenArView;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('home_map_action_bar'),
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const ValueKey('home_start_trail_button'),
          onPressed: canStartTrail ? onStartTrail : null,
          icon: const Icon(Icons.route_outlined),
          label: const Text('Start trail'),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('home_start_ar_trail_button'),
          onPressed: canStartArTrail ? onStartArTrail : null,
          icon: const Icon(Icons.explore_outlined),
          label: const Text('AR trail'),
        ),
        FilledButton.icon(
          onPressed: onOpenArView,
          icon: const Icon(Icons.view_in_ar),
          label: const Text('AR View'),
        ),
      ],
    );
  }
}

class _ViewerPositionDot extends StatelessWidget {
  const _ViewerPositionDot({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    const dotSize = 20.0;
    final center = Offset(size.width / 2, size.height / 2);

    return Positioned(
      left: center.dx - dotSize / 2,
      top: center.dy - dotSize / 2,
      child: Tooltip(
        message: 'Your position',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withValues(alpha: 0.24),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.my_location, color: Colors.blue, size: 12),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.point,
    required this.onTap,
  });

  final AnchorMapPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final anchor = point.memory;

    return Tooltip(
      message: anchor.title,
      child: Semantics(
        button: true,
        label:
            'Open ${anchor.title}, ${point.distanceLabel} ${point.directionLabel}',
        child: GestureDetector(
          key: ValueKey('home_map_pin_${anchor.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 84,
            height: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: anchor.needsCalibrationReview
                        ? colorScheme.error
                        : anchor.isPrivate
                            ? colorScheme.tertiary
                            : colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black.withValues(alpha: 0.24),
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child:
                        Icon(Icons.photo_camera, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(height: 3),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      '${point.distanceLabel} ${point.directionLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({
    required this.lineColor,
    required this.primaryColor,
  });

  final Color lineColor;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.24)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final axisPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = 0.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = _mapRadiusFor(size);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      axisPaint,
    );
    canvas.drawCircle(center, radius / 3, ringPaint);
    canvas.drawCircle(center, radius * 2 / 3, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.primaryColor != primaryColor;
  }
}

double _mapRadiusFor(Size size) => math.min(size.width, size.height) * 0.42;
