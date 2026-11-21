part of '../profile_screen.dart';

extension _ProfileTrailDetailSheet on ProfileScreen {
  void _showTrailDetailSheet(
    BuildContext context,
    WidgetRef ref,
    ARTrailProgress trail,
    Map<String, AnchorMemory> memoriesById,
    Set<String> wallLinkedMemoryIds,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final route = _routeForTrailSession(
          trail.session,
          memoriesById,
          wallLinkedMemoryIds,
          ref.read(viewerLocationProvider),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: ListView(
                key: const ValueKey('trail_detail_sheet'),
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Trail Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Consumer(
                        builder: (context, detailRef, _) {
                          final isSaved = detailRef
                              .watch(savedARTrailsProvider)
                              .any((savedTrail) => savedTrail.session
                                  .hasSameRouteAs(trail.session));
                          return IconButton(
                            key: const ValueKey('trail_detail_save_button'),
                            tooltip: isSaved ? 'Unsave trail' : 'Save trail',
                            icon: Icon(isSaved
                                ? Icons.bookmark
                                : Icons.bookmark_border),
                            onPressed: () => _toggleSavedTrail(
                              context,
                              detailRef,
                              trail.session,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        key: const ValueKey('trail_detail_replay_button'),
                        tooltip: 'Replay trail',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _replayTrailFromHistory(
                          context,
                          trail,
                          popCount: 2,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('trail_detail_remove_button'),
                        tooltip: 'Remove trail',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmRemoveTrailFromHistory(
                          context,
                          ref,
                          trail,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close trail details',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trail.session.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TrailHistoryChip(
                        icon: Icons.hub_outlined,
                        label: trail.session.sourceLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.pin_drop_outlined,
                        label: trail.session.stopCountLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.check_circle_outline,
                        label: trail.progressLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.timer_outlined,
                        label: trail.elapsedLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.route_outlined,
                        label: '${route.routeDistanceLabel} route',
                      ),
                      _TrailHistoryChip(
                        icon: Icons.directions_walk,
                        label: route.walkTimeLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.privacy_tip_outlined,
                        label: route.advisoryLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TrailDetailMetric(
                    icon: Icons.play_circle_outline,
                    title: 'Started',
                    value: _formatTrailTimestamp(trail.startedAt),
                  ),
                  _TrailDetailMetric(
                    icon: Icons.event_available_outlined,
                    title: 'Finished',
                    value: _formatTrailTimestamp(trail.finishedAt),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Stops',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  for (var index = 0;
                      index < trail.session.memoryIds.length;
                      index++) ...[
                    _TrailDetailStopTile(
                      index: index,
                      memoryId: trail.session.memoryIds[index],
                      memory: memoriesById[trail.session.memoryIds[index]],
                      onTap:
                          memoriesById[trail.session.memoryIds[index]] == null
                              ? null
                              : () => _openTrailStopDetails(
                                    context,
                                    trail.session.memoryIds[index],
                                  ),
                    ),
                    if (index < route.legs.length)
                      _TrailDetailLegTile(leg: route.legs[index]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openTrailStopDetails(
    BuildContext sheetContext,
    String memoryId, {
    int popCount = 2,
  }) {
    final navigator = Navigator.of(sheetContext);
    for (var index = 0; index < popCount && navigator.canPop(); index++) {
      navigator.pop();
    }
    navigator.pushNamed(
      AppRoutes.memoryDetails,
      arguments: memoryId,
    );
  }

  ARTrailRoute _routeForTrailSession(
    ARTrailSession session,
    Map<String, AnchorMemory> memoriesById,
    Set<String> wallLinkedMemoryIds,
    ViewerLocation origin,
  ) {
    return _profileRouteService.routeFor(
      points: [
        for (final memoryId in session.memoryIds)
          if (memoriesById[memoryId] != null)
            _routePointForMemory(
              memoriesById[memoryId]!,
              origin: origin,
              isWallLinked: wallLinkedMemoryIds.contains(memoryId),
            ),
      ],
    );
  }

  ARTrailRoutePoint _routePointForMemory(
    AnchorMemory memory, {
    required ViewerLocation origin,
    required bool isWallLinked,
  }) {
    return ARTrailRoutePoint(
      memoryId: memory.id,
      title: memory.title,
      latitude: memory.latitude,
      longitude: memory.longitude,
      distanceFromOriginMeters: origin.distanceToMemoryMeters(memory),
      bearingFromOriginDegrees: _profileGeoService.bearingDegrees(
        origin.latitude,
        origin.longitude,
        memory.latitude,
        memory.longitude,
      ),
      isPrivate: memory.isPrivate,
      needsCalibrationReview: memory.needsCalibrationReview,
      isWallLinked: isWallLinked,
    );
  }
}
