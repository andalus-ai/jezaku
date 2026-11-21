part of '../profile_screen.dart';

extension _ProfileSavedTrailsSheet on ProfileScreen {
  void _showSavedTrailsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final savedTrails = ref.watch(savedARTrailsProvider);
            final memoriesById = {
              for (final memory in ref.watch(nearbyAnchorsProvider))
                memory.id: memory,
            };
            final wallLinkedMemoryIds =
                _profileWallLinkedMemoryIds(ref.watch(arWallsProvider));
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved Trails',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (savedTrails.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bookmark_border),
                        title: Text('No saved trails yet'),
                        subtitle: Text(
                          'Save completed routes from Trail Details.',
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: savedTrails.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final trail = savedTrails[index];
                            final route = _routeForTrailSession(
                              trail.session,
                              memoriesById,
                              wallLinkedMemoryIds,
                              ref.read(viewerLocationProvider),
                            );
                            return ListTile(
                              key: ValueKey(
                                'saved_trail_${trail.session.title}_$index',
                              ),
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bookmark),
                              title: Text(trail.session.title),
                              onTap: () => _showSavedTrailDetailSheet(
                                context,
                                ref,
                                trail,
                                memoriesById,
                                wallLinkedMemoryIds,
                              ),
                              subtitle: Text(
                                '${trail.session.sourceLabel} - '
                                '${trail.session.stopCountLabel} - '
                                '${route.routeEffortLabel} - '
                                'saved ${_formatTrailTimestamp(trail.savedAt)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: ValueKey(
                                      'saved_trail_replay_${trail.session.title}_$index',
                                    ),
                                    tooltip: 'Replay saved trail',
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () =>
                                        _replaySavedTrail(context, trail),
                                  ),
                                  IconButton(
                                    key: ValueKey(
                                      'saved_trail_unsave_${trail.session.title}_$index',
                                    ),
                                    tooltip: 'Unsave trail',
                                    icon: const Icon(Icons.bookmark_remove),
                                    onPressed: () => _unsaveSavedTrail(
                                      context,
                                      ref,
                                      trail.session,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSavedTrailDetailSheet(
    BuildContext context,
    WidgetRef ref,
    SavedARTrail trail,
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
                key: const ValueKey('saved_trail_detail_sheet'),
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Saved Trail Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('saved_trail_detail_replay_button'),
                        tooltip: 'Replay saved trail',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _replaySavedTrail(
                          context,
                          trail,
                          popCount: 2,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('saved_trail_detail_unsave_button'),
                        tooltip: 'Unsave trail',
                        icon: const Icon(Icons.bookmark_remove),
                        onPressed: () => _unsaveSavedTrail(
                          context,
                          ref,
                          trail.session,
                          closeCurrentSheet: true,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('saved_trail_detail_close_button'),
                        tooltip: 'Close saved trail details',
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
                        icon: Icons.route_outlined,
                        label: '${route.routeDistanceLabel} route',
                      ),
                      _TrailHistoryChip(
                        icon: Icons.directions_walk,
                        label: route.walkTimeLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.explore_outlined,
                        label: route.routeContextLabel,
                      ),
                      _TrailHistoryChip(
                        icon: Icons.privacy_tip_outlined,
                        label: route.advisoryLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TrailDetailMetric(
                    icon: Icons.bookmark,
                    title: 'Saved',
                    value: _formatTrailTimestamp(trail.savedAt),
                  ),
                  _TrailDetailMetric(
                    icon: Icons.flag_outlined,
                    title: 'Route start',
                    value: route.startLabel,
                  ),
                  _TrailDetailMetric(
                    icon: Icons.near_me_outlined,
                    title: 'Farthest stop',
                    value: route.farthestLabel,
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

  void _toggleSavedTrail(
    BuildContext context,
    WidgetRef ref,
    ARTrailSession session,
  ) {
    final result = ref.read(savedARTrailsProvider.notifier).toggle(session);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.isSaved ? 'Trail saved.' : 'Trail unsaved.'),
              if (result.unlocks.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(formatARTrailAchievementUnlocks(result.unlocks)),
              ],
            ],
          ),
        ),
      );
  }

  void _unsaveSavedTrail(
    BuildContext context,
    WidgetRef ref,
    ARTrailSession session, {
    bool closeCurrentSheet = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    ref.read(savedARTrailsProvider.notifier).unsave(session);
    if (closeCurrentSheet && navigator.canPop()) {
      navigator.pop();
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Trail unsaved.')),
      );
  }

  void _replaySavedTrail(
    BuildContext sheetContext,
    SavedARTrail trail, {
    int popCount = 1,
  }) {
    final navigator = Navigator.of(sheetContext);
    for (var index = 0; index < popCount && navigator.canPop(); index++) {
      navigator.pop();
    }
    navigator.pushNamed(
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(trail.session),
    );
  }
}
