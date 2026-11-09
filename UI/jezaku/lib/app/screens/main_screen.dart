import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/screens/ar_viewer_screen.dart';
import 'package:jejaku/features/gallery/screens/gallery_screen.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/screens/home_screen.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/profile/screens/profile_screen.dart';
import 'package:jejaku/features/social/screens/social_hub_screen.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/features/trails/widgets/active_ar_trail_banner.dart';
import 'package:jejaku/features/trails/widgets/ar_trail_snackbars.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

enum _ActiveTrailEndDecision {
  cancel,
  end,
  finish,
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const _routeService = ARTrailRouteService();
  static const _geoService = AnchorGeoService();

  int _currentIndex = 0;
  ARTrailProgress? _openRouteSheetProgress;

  @override
  Widget build(BuildContext context) {
    ref.listen<ARTrailProgress?>(activeARTrailProgressProvider, (_, next) {
      _closeRouteSheetIfActiveTrailChanged(next);
    });

    final trailProgress = ref.watch(activeARTrailProgressProvider);
    final activeProgress = trailProgress == null || trailProgress.isFinished
        ? null
        : trailProgress;
    final anchorsById = {
      for (final anchor in ref.watch(nearbyAnchorsProvider)) anchor.id: anchor,
    };
    final wallLinkedMemoryIds = {
      for (final wall in ref.watch(arWallsProvider)) ...wall.linkedMemoryIds,
    };
    final activeRoute = activeProgress == null
        ? null
        : _routeForProgress(
            activeProgress,
            anchorsById,
            wallLinkedMemoryIds,
          );
    final activeLeg = activeRoute?.legAfterPoint(
      activeProgress?.currentMemoryId ?? '',
    );
    final activeMissingStopPoint = activeProgress == null || activeRoute == null
        ? null
        : _activeTrailMissingStopPoint(activeProgress, activeRoute);
    final activeMissingStopLabel = activeMissingStopPoint == null
        ? null
        : _missingRoutePointLabel(activeMissingStopPoint);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                HomeScreen(
                  onOpenTrailProfile: () {
                    setState(() => _currentIndex = 4);
                  },
                ),
                _currentIndex == 1
                    ? const ARViewerScreen()
                    : const SizedBox.shrink(),
                const SocialHubScreen(),
                const GalleryScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
          if (activeProgress != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: _currentIndex == 0 || _currentIndex == 1 ? 92 : 16,
              child: ActiveARTrailBanner(
                progress: activeProgress,
                onResume: () => _resumeTrail(activeProgress),
                onDismiss: () {
                  unawaited(_confirmEndTrail(activeProgress));
                },
                currentStopTitle:
                    anchorsById[activeProgress.currentMemoryId]?.title,
                nextStopTitle: activeLeg?.to.title,
                nextLegLabel: activeLeg == null
                    ? null
                    : '${activeLeg.distanceLabel} ${activeLeg.directionLabel}',
                remainingEffortLabel: activeRoute == null
                    ? null
                    : _trailProgressRemainingLabel(
                        activeProgress,
                        activeRoute,
                      ),
                missingStopLabel: activeMissingStopLabel,
                onOpenMissingStop: activeMissingStopPoint == null
                    ? null
                    : () => _jumpToTrailStop(
                          activeProgress,
                          activeMissingStopPoint.memoryId,
                        ),
                onOpenRoute: activeRoute == null
                    ? null
                    : () => _showActiveTrailRouteSheet(
                          activeProgress,
                          activeRoute,
                        ),
                onFinish: _canFinishTrail(activeProgress)
                    ? () => _finishTrail(expectedProgress: activeProgress)
                    : null,
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_in_ar_outlined),
            activeIcon: Icon(Icons.view_in_ar),
            label: 'AR View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openCamera(),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Capture'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _openCamera() {
    Navigator.pushNamed(context, AppRoutes.camera);
  }

  void _resumeTrail(ARTrailProgress activeProgress) {
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.resume(activeProgress),
    );
  }

  bool _canFinishTrail(ARTrailProgress progress) {
    return progress.completedStopCount >= progress.totalStops;
  }

  void _finishTrail({ARTrailProgress? expectedProgress}) {
    final messenger = ScaffoldMessenger.of(context);
    final progress = expectedProgress == null
        ? ref.read(activeARTrailProgressProvider)
        : _matchingActiveTrailOrNotify(expectedProgress);
    if (progress == null) {
      return;
    }
    if (!_canFinishTrail(progress)) {
      _showActiveTrailNotReadySnackBar(progress);
      return;
    }
    final session = progress.session;
    final unlocks = ref.read(activeARTrailProgressProvider.notifier).finish();

    showARTrailCompletionSnackBar(
      messenger: messenger,
      unlocks: unlocks,
      isSaved: ref.read(savedARTrailsProvider.notifier).isSaved(session),
      onSave: () => _saveTrail(session),
    );
  }

  void _saveTrail(ARTrailSession session) {
    final messenger = ScaffoldMessenger.of(context);
    final unlocks = ref.read(savedARTrailsProvider.notifier).save(session);

    showARTrailSavedSnackBar(
      messenger: messenger,
      unlocks: unlocks,
      onReplay: () => _replayTrail(session),
    );
  }

  void _replayTrail(ARTrailSession session) {
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(session),
    );
  }

  void _showActiveTrailRouteSheet(
    ARTrailProgress progress,
    ARTrailRoute route,
  ) {
    _openRouteSheetProgress = progress;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, sheetRef, child) {
            final activeProgress =
                sheetRef.watch(activeARTrailProgressProvider);
            final sheetProgress = _isSameActiveTrail(progress, activeProgress)
                ? activeProgress!
                : progress;

            return _ActiveTrailRouteSheet(
              progress: sheetProgress,
              route: route,
              onResume: () {
                _closeActiveRouteSheet(sheetContext);
                _resumeActiveTrailFrom(sheetProgress);
              },
              onSelectStop: (memoryId) {
                _closeActiveRouteSheet(sheetContext);
                _jumpToTrailStop(sheetProgress, memoryId);
              },
              onOpenStopDetails: (memoryId) {
                _closeActiveRouteSheet(sheetContext);
                _openTrailStopDetailsFrom(sheetProgress, memoryId);
              },
              onDismiss: () {
                unawaited(
                  _confirmEndTrail(sheetProgress).then((didEnd) {
                    if (didEnd && sheetContext.mounted) {
                      _closeActiveRouteSheet(sheetContext);
                    }
                  }),
                );
              },
              onFinish: _canFinishTrail(sheetProgress)
                  ? () {
                      _closeActiveRouteSheet(sheetContext);
                      _finishTrail(expectedProgress: sheetProgress);
                    }
                  : null,
            );
          },
        );
      },
    ).whenComplete(() {
      _openRouteSheetProgress = null;
    });
  }

  void _closeActiveRouteSheet(BuildContext sheetContext) {
    _openRouteSheetProgress = null;
    Navigator.of(sheetContext).pop();
  }

  void _closeRouteSheetIfActiveTrailChanged(
    ARTrailProgress? currentProgress,
  ) {
    final routeSheetProgress = _openRouteSheetProgress;
    if (routeSheetProgress == null ||
        _isSameActiveTrail(routeSheetProgress, currentProgress)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final latestRouteSheetProgress = _openRouteSheetProgress;
      if (!mounted || latestRouteSheetProgress == null) {
        return;
      }

      final latestProgress = ref.read(activeARTrailProgressProvider);
      if (_isSameActiveTrail(latestRouteSheetProgress, latestProgress)) {
        return;
      }

      _openRouteSheetProgress = null;
      unawaited(
        Navigator.of(context).maybePop().then((_) {
          if (mounted) {
            _showActiveTrailChangedSnackBar(latestProgress);
          }
        }),
      );
    });
  }

  void _resumeActiveTrailFrom(ARTrailProgress progress) {
    final currentProgress = _matchingActiveTrailOrNotify(progress);
    if (currentProgress == null) {
      return;
    }

    _resumeTrail(currentProgress);
  }

  void _jumpToTrailStop(ARTrailProgress progress, String memoryId) {
    final currentProgress = _matchingActiveTrailOrNotify(progress);
    if (currentProgress == null) {
      return;
    }

    ref.read(activeARTrailProgressProvider.notifier).focusMemory(memoryId);
    final focusedProgress = ref.read(activeARTrailProgressProvider);
    if (focusedProgress == null || focusedProgress.isFinished) {
      _showActiveTrailChangedSnackBar(focusedProgress);
      return;
    }
    _resumeTrail(focusedProgress);
  }

  void _openTrailStopDetailsFrom(ARTrailProgress progress, String memoryId) {
    final currentProgress = _matchingActiveTrailOrNotify(progress);
    if (currentProgress == null) {
      return;
    }

    _openTrailStopDetails(memoryId);
  }

  void _openTrailStopDetails(String memoryId) {
    Navigator.pushNamed(
      context,
      AppRoutes.memoryDetails,
      arguments: memoryId,
    );
  }

  Future<bool> _confirmEndTrail(ARTrailProgress progress) async {
    final liveProgress = _matchingActiveTrailOrNotify(progress);
    if (liveProgress == null) {
      return true;
    }

    final canFinish = _canFinishTrail(liveProgress);
    final decision = await showDialog<_ActiveTrailEndDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          key: const ValueKey('active_ar_trail_end_dialog'),
          title: const Text('End active trail?'),
          content: Text(
            canFinish
                ? '"${liveProgress.session.title}" is complete. Finish it to add '
                    'the route to your completed trail library, or end it '
                    'without saving completion credit.'
                : 'This will remove progress for '
                    '"${liveProgress.session.title}" at '
                    '${liveProgress.currentStopLabel} '
                    '(${liveProgress.progressLabel}). Completed and saved '
                    'trails stay in your library.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('active_ar_trail_end_cancel_button'),
              onPressed: () => Navigator.of(dialogContext).pop(
                _ActiveTrailEndDecision.cancel,
              ),
              child: const Text('Cancel'),
            ),
            if (canFinish)
              TextButton(
                key: const ValueKey('active_ar_trail_end_confirm_button'),
                onPressed: () => Navigator.of(dialogContext).pop(
                  _ActiveTrailEndDecision.end,
                ),
                child: const Text('End without credit'),
              )
            else
              FilledButton(
                key: const ValueKey('active_ar_trail_end_confirm_button'),
                onPressed: () => Navigator.of(dialogContext).pop(
                  _ActiveTrailEndDecision.end,
                ),
                child: const Text('End trail'),
              ),
            if (canFinish)
              FilledButton(
                key: const ValueKey(
                  'active_ar_trail_finish_instead_button',
                ),
                onPressed: () => Navigator.of(dialogContext).pop(
                  _ActiveTrailEndDecision.finish,
                ),
                child: const Text('Finish trail'),
              ),
          ],
        );
      },
    );

    if (!mounted ||
        decision == null ||
        decision == _ActiveTrailEndDecision.cancel) {
      return false;
    }

    final currentProgress = _matchingActiveTrailOrNotify(liveProgress);
    if (currentProgress == null) {
      return true;
    }

    if (decision == _ActiveTrailEndDecision.finish) {
      _finishTrail(expectedProgress: liveProgress);
      return true;
    }

    ref.read(activeARTrailProgressProvider.notifier).clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Active trail ended.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _restoreEndedTrail(currentProgress);
          },
        ),
      ),
    );
    return true;
  }

  ARTrailProgress? _matchingActiveTrailOrNotify(ARTrailProgress expected) {
    final currentProgress = ref.read(activeARTrailProgressProvider);
    if (!_isSameActiveTrail(expected, currentProgress)) {
      _showActiveTrailChangedSnackBar(currentProgress);
      return null;
    }
    return currentProgress;
  }

  bool _isSameActiveTrail(
    ARTrailProgress expected,
    ARTrailProgress? current,
  ) {
    return current != null &&
        !current.isFinished &&
        current.startedAt == expected.startedAt &&
        current.session.hasSameRouteAs(expected.session);
  }

  void _showActiveTrailChangedSnackBar(ARTrailProgress? currentProgress) {
    final messenger = ScaffoldMessenger.of(context);
    final currentActiveProgress =
        currentProgress == null || currentProgress.isFinished
            ? null
            : currentProgress;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            currentActiveProgress == null
                ? 'Active trail already changed.'
                : 'Another AR trail is already active.',
          ),
          action: currentActiveProgress == null
              ? null
              : SnackBarAction(
                  label: 'Resume',
                  onPressed: () => _resumeTrail(currentActiveProgress),
                ),
        ),
      );
  }

  void _showActiveTrailNotReadySnackBar(ARTrailProgress progress) {
    final remainingStopCount =
        progress.totalStops - progress.completedStopCount;
    final stopLabel = remainingStopCount == 1 ? 'stop' : 'stops';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$remainingStopCount $stopLabel left before this trail can be '
            'finished.',
          ),
          action: SnackBarAction(
            label: 'Resume',
            onPressed: () => _resumeTrail(progress),
          ),
        ),
      );
  }

  void _restoreEndedTrail(ARTrailProgress progress) {
    final currentProgress = ref.read(activeARTrailProgressProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (currentProgress != null && !currentProgress.isFinished) {
      _showActiveTrailChangedSnackBar(currentProgress);
      return;
    }

    ref.read(activeARTrailProgressProvider.notifier).restore(progress);
    final restoredProgress = ref.read(activeARTrailProgressProvider);
    if (!mounted || restoredProgress == null || restoredProgress.isFinished) {
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Active trail restored.'),
          action: SnackBarAction(
            label: 'Resume',
            onPressed: () => _resumeTrail(restoredProgress),
          ),
        ),
      );
  }

  ARTrailRoute _routeForProgress(
    ARTrailProgress progress,
    Map<String, AnchorMemory> anchorsById,
    Set<String> wallLinkedMemoryIds,
  ) {
    return _routeService.routeFor(
      points: [
        for (final memoryId in progress.session.memoryIds)
          if (anchorsById[memoryId] != null)
            ARTrailRoutePoint(
              memoryId: memoryId,
              title: anchorsById[memoryId]!.title,
              latitude: anchorsById[memoryId]!.latitude,
              longitude: anchorsById[memoryId]!.longitude,
              distanceFromOriginMeters: _geoService
                  .distanceFromLabel(anchorsById[memoryId]!.distanceLabel),
              bearingFromOriginDegrees: _geoService.bearingDegrees(
                viewerLatitude,
                viewerLongitude,
                anchorsById[memoryId]!.latitude,
                anchorsById[memoryId]!.longitude,
              ),
              isPrivate: anchorsById[memoryId]!.isPrivate,
              needsCalibrationReview:
                  anchorsById[memoryId]!.needsCalibrationReview,
              isWallLinked: wallLinkedMemoryIds.contains(memoryId),
            ),
      ],
    );
  }
}

String _trailProgressRemainingLabel(
  ARTrailProgress progress,
  ARTrailRoute route,
) {
  if (progress.completedStopCount < progress.totalStops &&
      progress.currentStopIndex >= progress.totalStops - 1) {
    return _remainingStopCountLabel(progress);
  }
  return route.remainingEffortLabelFrom(progress.currentMemoryId);
}

String _remainingStopCountLabel(ARTrailProgress progress) {
  final remainingStopCount = progress.totalStops - progress.completedStopCount;
  if (remainingStopCount <= 0) {
    return 'Route complete';
  }
  final stopLabel = remainingStopCount == 1 ? 'stop' : 'stops';
  return '$remainingStopCount $stopLabel left';
}

class _ActiveTrailRouteSheet extends StatelessWidget {
  const _ActiveTrailRouteSheet({
    required this.progress,
    required this.route,
    required this.onResume,
    required this.onSelectStop,
    required this.onOpenStopDetails,
    required this.onDismiss,
    required this.onFinish,
  });

  final ARTrailProgress progress;
  final ARTrailRoute route;
  final VoidCallback onResume;
  final ValueChanged<String> onSelectStop;
  final ValueChanged<String> onOpenStopDetails;
  final VoidCallback onDismiss;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final activeLeg = route.legAfterPoint(progress.currentMemoryId);
    final isRouteComplete = progress.completedStopCount >= progress.totalStops;
    final firstMissingPoint = _firstMissingRoutePoint(progress, route);
    final isAtRouteEnd = progress.currentStopIndex >= progress.totalStops - 1;
    final hasMissingStopsAtRouteEnd =
        !isRouteComplete && isAtRouteEnd && firstMissingPoint != null;
    final remainingLabel = _trailProgressRemainingLabel(progress, route);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          key: const ValueKey('active_trail_route_sheet'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.alt_route,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Active trail route',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                progress.session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.directions_walk, size: 18),
                    label: Text(route.routeEffortLabel),
                  ),
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(progress.progressLabel),
                  ),
                  Chip(
                    avatar: const Icon(Icons.flag_outlined, size: 18),
                    label: Text(remainingLabel),
                  ),
                  Chip(
                    avatar: const Icon(Icons.explore_outlined, size: 18),
                    label: Text(route.routeContextLabel),
                  ),
                  Chip(
                    avatar: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: Text(route.advisoryLabel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _currentStopLabel(progress, route),
                key: const ValueKey('active_trail_route_current_stop'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (activeLeg != null) ...[
                const SizedBox(height: 4),
                Text(
                  activeLeg.nextStopLabel,
                  key: const ValueKey('active_trail_route_next_leg'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (isRouteComplete) ...[
                const SizedBox(height: 10),
                _ActiveTrailCompletionCue(stopCount: progress.totalStops),
              ] else if (hasMissingStopsAtRouteEnd) ...[
                const SizedBox(height: 10),
                _ActiveTrailIncompleteCue(
                  point: firstMissingPoint,
                  remainingStopCount:
                      progress.totalStops - progress.completedStopCount,
                  onSelectStop: () => onSelectStop(firstMissingPoint.memoryId),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var index = 0;
                        index < route.points.length;
                        index++) ...[
                      _ActiveTrailRouteStopTile(
                        point: route.points[index],
                        stopNumber: index + 1,
                        status: _stopStatusFor(
                          route.points[index],
                          index,
                          progress,
                        ),
                        onTap: () => onSelectStop(route.points[index].memoryId),
                        onOpenDetails: () =>
                            onOpenStopDetails(route.points[index].memoryId),
                      ),
                      if (index < route.legs.length)
                        _ActiveTrailRouteLegTile(
                          leg: route.legs[index],
                          status: _legStatusFor(route.legs[index], progress),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    key: const ValueKey('active_trail_route_dismiss_button'),
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                  ),
                  const Spacer(),
                  if (onFinish != null) ...[
                    FilledButton.tonalIcon(
                      key: const ValueKey('active_trail_route_finish_button'),
                      onPressed: onFinish,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Finish'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    key: const ValueKey('active_trail_route_resume_button'),
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currentStopLabel(ARTrailProgress progress, ARTrailRoute route) {
    for (final point in route.points) {
      if (point.memoryId == progress.currentMemoryId) {
        return 'Current ${point.title}';
      }
    }
    return 'Current ${progress.currentMemoryId}';
  }

  _ActiveTrailStopStatus _stopStatusFor(
    ARTrailRoutePoint point,
    int stopIndex,
    ARTrailProgress progress,
  ) {
    if (point.memoryId == progress.currentMemoryId) {
      return _ActiveTrailStopStatus.current;
    }
    if (progress.completedMemoryIds.contains(point.memoryId)) {
      return _ActiveTrailStopStatus.completed;
    }
    if (stopIndex < progress.currentStopIndex) {
      return _ActiveTrailStopStatus.missing;
    }
    return _ActiveTrailStopStatus.upcoming;
  }

  _ActiveTrailLegStatus _legStatusFor(
    ARTrailRouteLeg leg,
    ARTrailProgress progress,
  ) {
    final fromReached = progress.completedMemoryIds.contains(leg.from.memoryId);
    final toReached = progress.completedMemoryIds.contains(leg.to.memoryId);

    if (leg.from.memoryId == progress.currentMemoryId) {
      return _ActiveTrailLegStatus.current;
    }
    if (!fromReached && toReached) {
      return _ActiveTrailLegStatus.gap;
    }
    if (fromReached && toReached) {
      return _ActiveTrailLegStatus.completed;
    }
    return _ActiveTrailLegStatus.upcoming;
  }
}

ARTrailRoutePoint? _activeTrailMissingStopPoint(
  ARTrailProgress progress,
  ARTrailRoute route,
) {
  if (progress.completedStopCount >= progress.totalStops ||
      progress.currentStopIndex < progress.totalStops - 1) {
    return null;
  }
  return _firstMissingRoutePoint(progress, route);
}

String _missingRoutePointLabel(ARTrailRoutePoint point) {
  final spatialLabel = _routePointSpatialLabel(point);
  if (spatialLabel == null) {
    return 'Missing ${point.title}';
  }
  return 'Missing ${point.title} - $spatialLabel';
}

ARTrailRoutePoint? _firstMissingRoutePoint(
  ARTrailProgress progress,
  ARTrailRoute route,
) {
  for (final point in route.points) {
    if (!progress.completedMemoryIds.contains(point.memoryId)) {
      return point;
    }
  }
  return null;
}

class _ActiveTrailIncompleteCue extends StatelessWidget {
  const _ActiveTrailIncompleteCue({
    required this.point,
    required this.remainingStopCount,
    required this.onSelectStop,
  });

  final ARTrailRoutePoint point;
  final int remainingStopCount;
  final VoidCallback onSelectStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stopLabel = remainingStopCount == 1 ? 'stop' : 'stops';

    return DecoratedBox(
      key: const ValueKey('active_trail_route_incomplete_cue'),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.pending_actions_outlined,
              color: colorScheme.tertiary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$remainingStopCount $stopLabel left before finish',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onTertiaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _nextMissingStopLabel(point),
                    key: const ValueKey('active_trail_route_next_missing_stop'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onTertiaryContainer
                          .withValues(alpha: 0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              key:
                  const ValueKey('active_trail_route_next_missing_stop_button'),
              onPressed: onSelectStop,
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Go'),
            ),
          ],
        ),
      ),
    );
  }
}

String _nextMissingStopLabel(ARTrailRoutePoint point) {
  final spatialLabel = _routePointSpatialLabel(point);
  if (spatialLabel == null) {
    return 'Next missing ${point.title}';
  }
  return 'Next missing ${point.title} - $spatialLabel';
}

String? _routePointSpatialLabel(ARTrailRoutePoint point) {
  final distanceMeters = point.distanceFromOriginMeters;
  if (distanceMeters == null) {
    return null;
  }
  final directionLabel = point.bearingFromOriginDegrees == null
      ? null
      : formatARTrailDirection(point.bearingFromOriginDegrees!);
  if (directionLabel == null) {
    return formatARTrailPointDistance(distanceMeters);
  }
  return '${formatARTrailPointDistance(distanceMeters)} $directionLabel';
}

class _ActiveTrailCompletionCue extends StatelessWidget {
  const _ActiveTrailCompletionCue({required this.stopCount});

  final int stopCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: const ValueKey('active_trail_route_completion_cue'),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All $stopCount stops reached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Route complete - ready to finish',
                    key: const ValueKey('active_trail_route_complete'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

class _ActiveTrailRouteStopTile extends StatelessWidget {
  const _ActiveTrailRouteStopTile({
    required this.point,
    required this.stopNumber,
    required this.status,
    required this.onTap,
    required this.onOpenDetails,
  });

  final ARTrailRoutePoint point;
  final int stopNumber;
  final _ActiveTrailStopStatus status;
  final VoidCallback onTap;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final statusLabel = 'Stop $stopNumber ${point.title} - '
        '${status.actionLabel}';

    return Tooltip(
      message: statusLabel,
      child: Semantics(
        label: statusLabel,
        child: ListTile(
          key: ValueKey('active_trail_route_stop_${point.memoryId}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            child: Text('$stopNumber'),
          ),
          title: Text('Stop $stopNumber ${point.title}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(status.actionLabel),
              Text(
                _stopContextLabel(point),
                key: ValueKey(
                    'active_trail_route_stop_context_${point.memoryId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == _ActiveTrailStopStatus.missing &&
                  status.icon != null)
                Icon(status.icon, size: 18)
              else if (point.isPrivate)
                const Icon(Icons.lock_outline, size: 18)
              else if (status.icon != null)
                Icon(status.icon, size: 18),
              IconButton(
                key: ValueKey(
                    'active_trail_route_stop_details_${point.memoryId}'),
                tooltip: 'Open stop details',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: onOpenDetails,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ActiveTrailRouteLegTile extends StatelessWidget {
  const _ActiveTrailRouteLegTile({
    required this.leg,
    required this.status,
  });

  final ARTrailRouteLeg leg;
  final _ActiveTrailLegStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = switch (status) {
      _ActiveTrailLegStatus.current => colorScheme.primary,
      _ActiveTrailLegStatus.gap => colorScheme.tertiary,
      _ => colorScheme.onSurfaceVariant,
    };
    final statusLabel = 'Leg ${leg.from.title} to ${leg.to.title} - '
        '${status.label}';

    return Tooltip(
      message: statusLabel,
      child: Semantics(
        label: statusLabel,
        child: Padding(
          key: ValueKey(
            'active_trail_route_leg_${leg.from.memoryId}_${leg.to.memoryId}',
          ),
          padding: const EdgeInsets.only(left: 40, right: 8, bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.turn_slight_right,
                color: foregroundColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'To ${leg.to.title} - ${leg.distanceLabel} '
                      '${leg.directionLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      status.label,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _stopContextLabel(ARTrailRoutePoint point) {
  final labels = <String>[];
  final distanceMeters = point.distanceFromOriginMeters;
  if (distanceMeters != null) {
    final directionLabel = point.bearingFromOriginDegrees == null
        ? null
        : formatARTrailDirection(point.bearingFromOriginDegrees!);
    labels.add(
      directionLabel == null
          ? formatARTrailPointDistance(distanceMeters)
          : '${formatARTrailPointDistance(distanceMeters)} $directionLabel',
    );
  }
  if (point.isWallLinked) {
    labels.add('Wall stop');
  }
  if (point.isPrivate) {
    labels.add('Private');
  }
  if (point.needsCalibrationReview) {
    labels.add('Needs review');
  }

  return labels.isEmpty ? 'Route stop' : labels.join(' - ');
}

enum _ActiveTrailStopStatus {
  completed,
  current,
  missing,
  upcoming;

  String get label {
    return switch (this) {
      _ActiveTrailStopStatus.completed => 'Completed',
      _ActiveTrailStopStatus.current => 'Current stop',
      _ActiveTrailStopStatus.missing => 'Missing stop',
      _ActiveTrailStopStatus.upcoming => 'Upcoming',
    };
  }

  String get actionLabel {
    return switch (this) {
      _ActiveTrailStopStatus.completed => 'Completed - jump back',
      _ActiveTrailStopStatus.current => 'Current stop - resume here',
      _ActiveTrailStopStatus.missing => 'Missing before finish - go back',
      _ActiveTrailStopStatus.upcoming => 'Upcoming - jump ahead',
    };
  }

  IconData? get icon {
    return switch (this) {
      _ActiveTrailStopStatus.completed => Icons.check_circle_outline,
      _ActiveTrailStopStatus.current => Icons.my_location,
      _ActiveTrailStopStatus.missing => Icons.pending_actions_outlined,
      _ActiveTrailStopStatus.upcoming => null,
    };
  }
}

enum _ActiveTrailLegStatus {
  completed,
  current,
  gap,
  upcoming;

  String get label {
    return switch (this) {
      _ActiveTrailLegStatus.completed => 'Completed leg',
      _ActiveTrailLegStatus.current => 'Current leg',
      _ActiveTrailLegStatus.gap => 'Missing stop gap',
      _ActiveTrailLegStatus.upcoming => 'Upcoming leg',
    };
  }
}
