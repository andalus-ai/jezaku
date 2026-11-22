part of '../profile_screen.dart';

extension _ProfileTrailAchievementsSheet on ProfileScreen {
  void _showTrailAchievementsSheet(BuildContext profileContext, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: profileContext,
      showDragHandle: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final achievements = sheetRef.watch(arTrailAchievementsProvider);
            final lifetimeStats = sheetRef.watch(arTrailLifetimeStatsProvider);
            final recentUnlocks =
                sheetRef.watch(arTrailAchievementUnlocksProvider);
            final visibleRecentUnlocks =
                recentUnlocks.take(3).toList(growable: false);
            final unlockedCount = achievements
                .where((achievement) => achievement.isUnlocked)
                .length;
            final nextAchievement = _nextTrailAchievement(achievements);
            final inProgressAchievements =
                _inProgressTrailAchievements(achievements);
            final unlockedAchievements =
                _unlockedTrailAchievements(achievements);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trail Achievements',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$unlockedCount/${achievements.length} unlocked',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    _TrailAchievementOverviewChips(
                      unlockedCount: unlockedCount,
                      inProgressCount: inProgressAchievements.length,
                      totalCount: achievements.length,
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (nextAchievement == null)
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.emoji_events),
                              title: Text('All achievements unlocked'),
                              subtitle: Text(
                                'Every current trail milestone is complete.',
                              ),
                            )
                          else ...[
                            Text(
                              'Next Goal',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            _TrailNextGoalTile(
                              achievement: nextAchievement,
                              action: _trailGoalActionFor(
                                profileContext: profileContext,
                                sheetContext: sheetContext,
                                ref: ref,
                                achievement: nextAchievement,
                                lifetimeStats: lifetimeStats,
                              ),
                            ),
                            const Divider(height: 20),
                          ],
                          if (lifetimeStats.hasProgress) ...[
                            Text(
                              'Source Mix',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            _TrailSourceMixSection(
                              lifetimeStats: lifetimeStats,
                              onSuggestedSourceSelected: (source) {
                                _openTrailSourceSuggestion(context, source);
                              },
                            ),
                            const Divider(height: 20),
                          ],
                          if (visibleRecentUnlocks.isNotEmpty) ...[
                            Text(
                              'Recent Unlocks',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            for (var index = 0;
                                index < visibleRecentUnlocks.length;
                                index++)
                              _TrailRecentUnlockTile(
                                unlock: visibleRecentUnlocks[index],
                                index: index,
                              ),
                            const Divider(height: 20),
                          ],
                          Text(
                            'Progress',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          if (inProgressAchievements.isNotEmpty) ...[
                            _TrailAchievementGroupHeader(
                              key: const ValueKey(
                                'trail_achievement_group_in_progress',
                              ),
                              title: 'In Progress',
                              countLabel:
                                  '${inProgressAchievements.length} active',
                            ),
                            const SizedBox(height: 4),
                            ..._trailAchievementTiles(inProgressAchievements),
                          ],
                          if (unlockedAchievements.isNotEmpty) ...[
                            if (inProgressAchievements.isNotEmpty)
                              const Divider(height: 20),
                            _TrailAchievementGroupHeader(
                              key: const ValueKey(
                                'trail_achievement_group_unlocked',
                              ),
                              title: 'Unlocked Milestones',
                              countLabel:
                                  '${unlockedAchievements.length} complete',
                            ),
                            const SizedBox(height: 4),
                            ..._trailAchievementTiles(unlockedAchievements),
                          ],
                        ],
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

  _TrailGoalAction _trailGoalActionFor({
    required BuildContext profileContext,
    required BuildContext sheetContext,
    required WidgetRef ref,
    required ARTrailAchievement achievement,
    required ARTrailLifetimeStats lifetimeStats,
  }) {
    return _trailGoalActionForCallbacks(
      achievement: achievement,
      lifetimeStats: lifetimeStats,
      openRoute: (routeName) => _openRouteFromSheet(sheetContext, routeName),
      openTrailHistory: () => _openTrailHistoryFromAchievements(
        profileContext: profileContext,
        sheetContext: sheetContext,
        ref: ref,
      ),
    );
  }

  _TrailGoalAction _trailGoalActionForProfileTile({
    required BuildContext context,
    required WidgetRef ref,
    required ARTrailAchievement achievement,
    required ARTrailLifetimeStats lifetimeStats,
  }) {
    return _trailGoalActionForCallbacks(
      achievement: achievement,
      lifetimeStats: lifetimeStats,
      openRoute: (routeName) => Navigator.of(context).pushNamed(routeName),
      openTrailHistory: () {
        _showTrailHistorySheet(
          context,
          ref,
          ref.read(completedARTrailHistoryProvider),
          ref.read(completedARTrailHistorySummaryProvider),
          {
            for (final memory in ref.read(nearbyAnchorsProvider))
              memory.id: memory,
          },
          _profileWallLinkedMemoryIds(ref.read(arWallsProvider)),
        );
      },
    );
  }

  _TrailGoalAction _trailGoalActionForCallbacks({
    required ARTrailAchievement achievement,
    required ARTrailLifetimeStats lifetimeStats,
    required ValueChanged<String> openRoute,
    required VoidCallback openTrailHistory,
  }) {
    return switch (achievement.id) {
      ARTrailAchievementId.firstTrail => _routeTrailGoalAction(
          openRoute: openRoute,
          icon: Icons.near_me_outlined,
          label: 'Open Nearby',
          routeName: AppRoutes.root,
        ),
      ARTrailAchievementId.stopCollector => _routeTrailGoalAction(
          openRoute: openRoute,
          icon: Icons.near_me_outlined,
          label: 'Open Nearby',
          routeName: AppRoutes.root,
        ),
      ARTrailAchievementId.cameraExplorer => _routeTrailGoalAction(
          openRoute: openRoute,
          icon: Icons.photo_camera_outlined,
          label: 'Open Camera',
          routeName: AppRoutes.camera,
        ),
      ARTrailAchievementId.wallExplorer => _routeTrailGoalAction(
          openRoute: openRoute,
          icon: Icons.view_in_ar_outlined,
          label: 'Open Virtual Walls',
          routeName: AppRoutes.virtualWalls,
        ),
      ARTrailAchievementId.sourceSampler => _sourceSamplerGoalAction(
          lifetimeStats: lifetimeStats,
          openRoute: openRoute,
        ),
      ARTrailAchievementId.routeKeeper => _TrailGoalAction(
          icon: Icons.route_outlined,
          label: 'Open Trail History',
          onPressed: openTrailHistory,
        ),
    };
  }

  _TrailGoalAction _sourceSamplerGoalAction({
    required ARTrailLifetimeStats lifetimeStats,
    required ValueChanged<String> openRoute,
  }) {
    final suggestedSources = lifetimeStats.suggestedSources();
    final source = suggestedSources.isEmpty
        ? ARTrailSource.nearby
        : suggestedSources.first;
    return _TrailGoalAction(
      icon: _trailSourceIcon(source),
      label: 'Try ${source.label}',
      onPressed: () => openRoute(_routeForTrailSource(source)),
    );
  }

  _TrailGoalAction _routeTrailGoalAction({
    required ValueChanged<String> openRoute,
    required IconData icon,
    required String label,
    required String routeName,
  }) {
    return _TrailGoalAction(
      icon: icon,
      label: label,
      onPressed: () => openRoute(routeName),
    );
  }

  void _openRouteFromSheet(BuildContext sheetContext, String routeName) {
    final navigator = Navigator.of(sheetContext);
    navigator.pop();
    navigator.pushNamed(routeName);
  }

  void _openTrailSourceSuggestion(
    BuildContext sheetContext,
    ARTrailSource source,
  ) {
    _openRouteFromSheet(sheetContext, _routeForTrailSource(source));
  }

  void _openTrailHistoryFromAchievements({
    required BuildContext profileContext,
    required BuildContext sheetContext,
    required WidgetRef ref,
  }) {
    final completedTrails = ref.read(completedARTrailHistoryProvider);
    final trailSummary = ref.read(completedARTrailHistorySummaryProvider);
    final memoriesById = {
      for (final memory in ref.read(nearbyAnchorsProvider)) memory.id: memory,
    };
    final wallLinkedMemoryIds =
        _profileWallLinkedMemoryIds(ref.read(arWallsProvider));

    Navigator.of(sheetContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!profileContext.mounted) {
        return;
      }
      _showTrailHistorySheet(
        profileContext,
        ref,
        completedTrails,
        trailSummary,
        memoriesById,
        wallLinkedMemoryIds,
      );
    });
  }
}
