import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/profile/models/user_profile.dart';
import 'package:jejaku/features/profile/states/profile_providers.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

const _profileGeoService = AnchorGeoService();
const _profileRouteService = ARTrailRouteService();

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSyncCount = ref.watch(pendingSyncMemoriesProvider).length;
    final pendingUploadCount = ref.watch(pendingUploadMemoriesProvider).length;
    final pendingMetadataCount =
        ref.watch(pendingMetadataSyncMemoriesProvider).length;
    final moderationCount = ref.watch(moderationQueueProvider).length;
    final calibrationReviewMemories =
        ref.watch(calibrationReviewMemoriesProvider);
    final calibrationCount = calibrationReviewMemories.length;
    final profile = ref.watch(userProfileProvider);
    final completedTrails = ref.watch(completedARTrailHistoryProvider);
    final trailSummary = ref.watch(completedARTrailHistorySummaryProvider);
    final savedTrails = ref.watch(savedARTrailsProvider);
    final trailAchievements = ref.watch(arTrailAchievementsProvider);
    final trailLifetimeStats = ref.watch(arTrailLifetimeStatsProvider);
    final nextTrailAchievement = _nextTrailAchievement(trailAchievements);
    final unlockedTrailAchievementCount =
        trailAchievements.where((achievement) => achievement.isUnlocked).length;
    final trailAchievementCoachAction = nextTrailAchievement == null
        ? null
        : _trailGoalActionForProfileTile(
            context: context,
            ref: ref,
            achievement: nextTrailAchievement,
            lifetimeStats: trailLifetimeStats,
          );
    final memoriesById = {
      for (final memory in ref.watch(nearbyAnchorsProvider)) memory.id: memory,
    };
    final wallLinkedMemoryIds =
        _profileWallLinkedMemoryIds(ref.watch(arWallsProvider));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            profile: profile,
            onEdit: () => _showEditProfileDialog(context, ref, profile),
          ),
          const SizedBox(height: 16),
          const _ProfileStats(),
          const SizedBox(height: 18),
          Text(
            'Feature Modules',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _FeatureTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Sync Queue',
            subtitle: _syncQueueSubtitle(
              syncCount: pendingSyncCount,
              uploadCount: pendingUploadCount,
              metadataCount: pendingMetadataCount,
            ),
            trailing: pendingSyncCount == 0
                ? const Icon(Icons.chevron_right)
                : Badge.count(
                    count: pendingSyncCount,
                    child: const Icon(Icons.chevron_right),
                  ),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.syncQueue);
            },
          ),
          _FeatureTile(
            icon: Icons.tune,
            title: 'Calibration Review',
            subtitle: _calibrationReviewSubtitle(calibrationReviewMemories),
            trailing: calibrationCount == 0
                ? const Icon(Icons.chevron_right)
                : Badge.count(
                    count: calibrationCount,
                    child: const Icon(Icons.chevron_right),
                  ),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.calibrationReview);
            },
          ),
          _FeatureTile(
            icon: Icons.report_outlined,
            title: 'Moderation Queue',
            subtitle: moderationCount == 0
                ? 'No reports pending'
                : '$moderationCount flagged memory${moderationCount == 1 ? '' : 'ies'}',
            trailing: moderationCount == 0
                ? const Icon(Icons.chevron_right)
                : Badge.count(
                    count: moderationCount,
                    child: const Icon(Icons.chevron_right),
                  ),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.moderationQueue);
            },
          ),
          _FeatureTile(
            icon: Icons.grid_view,
            title: 'Virtual Walls',
            subtitle: 'Collaborative AR boards for groups and places',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.virtualWalls);
            },
          ),
          _FeatureTile(
            icon: Icons.route_outlined,
            title: 'Trail History',
            subtitle: _trailHistorySubtitle(trailSummary),
            trailing: completedTrails.isEmpty
                ? const Icon(Icons.chevron_right)
                : Badge.count(
                    count: completedTrails.length,
                    child: const Icon(Icons.chevron_right),
                  ),
            onTap: () => _showTrailHistorySheet(
              context,
              ref,
              completedTrails,
              trailSummary,
              memoriesById,
              wallLinkedMemoryIds,
            ),
          ),
          _FeatureTile(
            icon: Icons.bookmark_border,
            title: 'Saved Trails',
            subtitle: _savedTrailSubtitle(savedTrails),
            trailing: savedTrails.isEmpty
                ? const Icon(Icons.chevron_right)
                : Badge.count(
                    count: savedTrails.length,
                    child: const Icon(Icons.chevron_right),
                  ),
            onTap: () => _showSavedTrailsSheet(context),
          ),
          _FeatureTile(
            icon: Icons.emoji_events_outlined,
            title: 'Trail Achievements',
            subtitle: _trailAchievementSubtitle(trailAchievements),
            progressKey: const ValueKey('trail_achievement_tile_progress'),
            progressLabelKey:
                const ValueKey('trail_achievement_tile_progress_label'),
            progressLabel: _achievementCompletionPercentText(
              unlockedCount: unlockedTrailAchievementCount,
              totalCount: trailAchievements.length,
            ),
            progressCaptionKey:
                const ValueKey('trail_achievement_tile_progress_caption'),
            progressCaption: _trailAchievementProgressCaption(
              trailAchievements,
            ),
            footer: trailAchievementCoachAction == null
                ? null
                : _FeatureTileActionButton(
                    buttonKey: ValueKey(
                      'trail_achievement_tile_goal_action_'
                      '${nextTrailAchievement!.id.name}',
                    ),
                    action: trailAchievementCoachAction,
                  ),
            progressValue: _achievementCompletionRatio(
              unlockedCount: unlockedTrailAchievementCount,
              totalCount: trailAchievements.length,
            ),
            trailing: unlockedTrailAchievementCount == 0
                ? const Icon(Icons.chevron_right)
                : Badge.count(
                    count: unlockedTrailAchievementCount,
                    child: const Icon(Icons.chevron_right),
                  ),
            onTap: () => _showTrailAchievementsSheet(context, ref),
          ),
          _FeatureTile(
            icon: Icons.family_restroom,
            title: 'Parental Controls',
            subtitle: 'Safety, screen time, geofences, and reports',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.parentDashboard);
            },
          ),
          _FeatureTile(
            icon: Icons.verified_user_outlined,
            title: 'Privacy Center',
            subtitle: 'Sharing defaults and location visibility',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.privacySafety);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (_) => _EditProfileDialog(profile: profile),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    ref.read(userProfileProvider.notifier).updateProfile(
          displayName: draft.displayName,
          handle: draft.handle,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

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

  void _showTrailHistorySheet(
    BuildContext context,
    WidgetRef ref,
    List<ARTrailProgress> completedTrails,
    ARTrailHistorySummary summary,
    Map<String, AnchorMemory> memoriesById,
    Set<String> wallLinkedMemoryIds,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trail History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (completedTrails.isNotEmpty)
                      IconButton(
                        key: const ValueKey('trail_history_clear_button'),
                        tooltip: 'Clear trail history',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmClearTrailHistory(context, ref),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (completedTrails.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.route_outlined),
                    title: Text('No completed trails yet'),
                    subtitle: Text('Finished AR routes will appear here.'),
                  )
                else
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TrailHistorySummaryChips(summary: summary),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: completedTrails.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final trail = completedTrails[index];
                              return ListTile(
                                key: ValueKey(
                                  'trail_history_${trail.session.title}_$index',
                                ),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(trail.session.title),
                                onTap: () => _showTrailDetailSheet(
                                  context,
                                  ref,
                                  trail,
                                  memoriesById,
                                  wallLinkedMemoryIds,
                                ),
                                subtitle: Text(
                                  '${trail.session.sourceLabel} - '
                                  '${trail.session.stopCountLabel} - '
                                  '${trail.progressLabel} - '
                                  '${trail.elapsedLabel}',
                                ),
                                trailing: IconButton(
                                  key: ValueKey(
                                    'trail_history_replay_${trail.session.title}_$index',
                                  ),
                                  tooltip: 'Replay trail',
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () => _replayTrailFromHistory(
                                    context,
                                    trail,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  void _replayTrailFromHistory(
    BuildContext sheetContext,
    ARTrailProgress trail, {
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
  ) {
    return _profileRouteService.routeFor(
      points: [
        for (final memoryId in session.memoryIds)
          if (memoriesById[memoryId] != null)
            _routePointForMemory(
              memoriesById[memoryId]!,
              isWallLinked: wallLinkedMemoryIds.contains(memoryId),
            ),
      ],
    );
  }

  ARTrailRoutePoint _routePointForMemory(
    AnchorMemory memory, {
    required bool isWallLinked,
  }) {
    return ARTrailRoutePoint(
      memoryId: memory.id,
      title: memory.title,
      latitude: memory.latitude,
      longitude: memory.longitude,
      distanceFromOriginMeters:
          _profileGeoService.distanceFromLabel(memory.distanceLabel),
      bearingFromOriginDegrees: _profileGeoService.bearingDegrees(
        viewerLatitude,
        viewerLongitude,
        memory.latitude,
        memory.longitude,
      ),
      isPrivate: memory.isPrivate,
      needsCalibrationReview: memory.needsCalibrationReview,
      isWallLinked: isWallLinked,
    );
  }

  Future<void> _confirmClearTrailHistory(
    BuildContext sheetContext,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear trail history?'),
          content: const Text(
            'Completed AR routes will be removed from this profile view.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('trail_history_confirm_clear_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !sheetContext.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(sheetContext);
    final navigator = Navigator.of(sheetContext);
    ref.read(completedARTrailHistoryProvider.notifier).clear();
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Trail history cleared.')),
    );
  }

  Future<void> _confirmRemoveTrailFromHistory(
    BuildContext detailContext,
    WidgetRef ref,
    ARTrailProgress trail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: detailContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove trail?'),
          content: Text(
            '"${trail.session.title}" will be removed from your trail history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('trail_detail_confirm_remove_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !detailContext.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(detailContext);
    final navigator = Navigator.of(detailContext);
    ref.read(completedARTrailHistoryProvider.notifier).remove(trail);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Trail removed from history.')),
    );
  }
}

String _syncQueueSubtitle({
  required int syncCount,
  required int uploadCount,
  required int metadataCount,
}) {
  if (syncCount == 0) {
    return 'All memories synced';
  }

  final otherCount = syncCount - uploadCount - metadataCount;

  return [
    if (uploadCount > 0)
      '$uploadCount pending upload${uploadCount == 1 ? '' : 's'}',
    if (metadataCount > 0)
      '$metadataCount metadata update${metadataCount == 1 ? '' : 's'}',
    if (otherCount > 0) '$otherCount sync item${otherCount == 1 ? '' : 's'}',
  ].join(', ');
}

String _calibrationReviewSubtitle(List<AnchorMemory> memories) {
  if (memories.isEmpty) {
    return 'No anchors need calibration';
  }

  final count = memories.length;
  final issueCount = memories.fold<int>(
    0,
    (total, memory) => total + memory.captureMetadata.calibrationIssueCount,
  );
  final issueLabel = _dominantCalibrationIssue(memories);

  return '$count anchor${count == 1 ? '' : 's'} '
      '${count == 1 ? 'needs' : 'need'} alignment - '
      '$issueCount issue${issueCount == 1 ? '' : 's'} - $issueLabel';
}

String _dominantCalibrationIssue(List<AnchorMemory> memories) {
  final gpsCount =
      memories.where((memory) => memory.captureMetadata.hasGpsDrift).length;
  final compassCount =
      memories.where((memory) => memory.captureMetadata.hasCompassDrift).length;
  final tiltCount =
      memories.where((memory) => memory.captureMetadata.hasTiltDrift).length;

  if (gpsCount >= compassCount && gpsCount >= tiltCount) {
    return 'GPS drift high';
  }
  if (compassCount >= tiltCount) {
    return 'Compass unavailable';
  }
  return 'High tilt';
}

Set<String> _profileWallLinkedMemoryIds(Iterable<ARWall> walls) {
  return {
    for (final wall in walls) ...wall.linkedMemoryIds,
  };
}

String _trailHistorySubtitle(ARTrailHistorySummary summary) {
  if (!summary.hasHistory) {
    return 'No completed trails yet';
  }

  return '${summary.completedTrailLabel} - ${summary.reachedStopLabel}';
}

String _savedTrailSubtitle(List<SavedARTrail> savedTrails) {
  if (savedTrails.isEmpty) {
    return 'No saved trails yet';
  }

  final latestTrail = savedTrails.first;
  final trailLabel = savedTrails.length == 1 ? 'trail' : 'trails';
  return '${savedTrails.length} saved $trailLabel - '
      'latest ${latestTrail.session.title}';
}

String _trailAchievementSubtitle(List<ARTrailAchievement> achievements) {
  if (achievements.isEmpty) {
    return 'No trail achievements yet';
  }

  final unlockedCount =
      achievements.where((achievement) => achievement.isUnlocked).length;
  if (unlockedCount == achievements.length) {
    return 'All ${achievements.length} unlocked';
  }

  final nextAchievement = _nextTrailAchievement(achievements);
  return '$unlockedCount/${achievements.length} unlocked - '
      'next ${nextAchievement?.title ?? 'trail goal'}: '
      '${nextAchievement?.statusLabel ?? 'keep going'}';
}

String? _trailAchievementProgressCaption(
  List<ARTrailAchievement> achievements,
) {
  if (achievements.isEmpty) {
    return null;
  }

  final nextAchievement = _nextTrailAchievement(achievements);
  if (nextAchievement == null) {
    return 'All goals complete';
  }

  return 'Next goal ${nextAchievement.progressLabel}';
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

List<ARTrailAchievement> _inProgressTrailAchievements(
  List<ARTrailAchievement> achievements,
) {
  final inProgressAchievements = [
    for (final achievement in achievements)
      if (!achievement.isUnlocked) achievement,
  ];
  inProgressAchievements.sort((a, b) {
    final progressComparison = b.progressRatio.compareTo(a.progressRatio);
    if (progressComparison != 0) {
      return progressComparison;
    }
    return achievements.indexOf(a).compareTo(achievements.indexOf(b));
  });
  return inProgressAchievements;
}

List<ARTrailAchievement> _unlockedTrailAchievements(
  List<ARTrailAchievement> achievements,
) {
  return [
    for (final achievement in achievements)
      if (achievement.isUnlocked) achievement,
  ];
}

Iterable<Widget> _trailAchievementTiles(
  List<ARTrailAchievement> achievements,
) sync* {
  for (var index = 0; index < achievements.length; index++) {
    yield _TrailAchievementTile(achievement: achievements[index]);
    if (index < achievements.length - 1) {
      yield const Divider(height: 1);
    }
  }
}

String _achievementCompletionPercentLabel({
  required int unlockedCount,
  required int totalCount,
}) {
  return '${_achievementCompletionPercentText(
    unlockedCount: unlockedCount,
    totalCount: totalCount,
  )} complete';
}

String _achievementCompletionPercentText({
  required int unlockedCount,
  required int totalCount,
}) {
  if (totalCount <= 0) {
    return '0%';
  }

  final percent = (unlockedCount / totalCount * 100).round();
  return '$percent%';
}

double _achievementCompletionRatio({
  required int unlockedCount,
  required int totalCount,
}) {
  if (totalCount <= 0) {
    return 0;
  }
  return unlockedCount / totalCount;
}

String _formatTrailTimestamp(DateTime? timestamp) {
  if (timestamp == null) {
    return 'Not finished';
  }

  final local = timestamp.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _TrailNextGoalTile extends StatelessWidget {
  const _TrailNextGoalTile({
    required this.achievement,
    required this.action,
  });

  final ARTrailAchievement achievement;
  final _TrailGoalAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('trail_next_goal_${achievement.id.name}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flag_outlined),
      title: Text('Next: ${achievement.title}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(achievement.description),
          const SizedBox(height: 2),
          Text(achievement.statusLabel),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: achievement.progressRatio),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('trail_next_goal_action_${achievement.id.name}'),
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 18),
              label: Text(action.label),
            ),
          ),
        ],
      ),
      trailing: Text(achievement.progressLabel),
    );
  }
}

class _TrailGoalAction {
  const _TrailGoalAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _TrailAchievementOverviewChips extends StatelessWidget {
  const _TrailAchievementOverviewChips({
    required this.unlockedCount,
    required this.inProgressCount,
    required this.totalCount,
  });

  final int unlockedCount;
  final int inProgressCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        key: const ValueKey('trail_achievement_overview_chips'),
        spacing: 8,
        runSpacing: 8,
        children: [
          _TrailHistoryChip(
            icon: Icons.emoji_events_outlined,
            label: '$unlockedCount unlocked',
          ),
          _TrailHistoryChip(
            icon: Icons.timelapse_outlined,
            label: '$inProgressCount in progress',
          ),
          _TrailHistoryChip(
            icon: Icons.pie_chart_outline,
            label: _achievementCompletionPercentLabel(
              unlockedCount: unlockedCount,
              totalCount: totalCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailSourceMixSection extends StatelessWidget {
  const _TrailSourceMixSection({
    required this.lifetimeStats,
    required this.onSuggestedSourceSelected,
  });

  final ARTrailLifetimeStats lifetimeStats;
  final ValueChanged<ARTrailSource> onSuggestedSourceSelected;

  @override
  Widget build(BuildContext context) {
    final suggestedSources = lifetimeStats.suggestedSources();
    return Column(
      key: const ValueKey('trail_source_mix_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lifetimeStats.sourceMixProgressLabel()),
        const SizedBox(height: 2),
        Text(lifetimeStats.sourceMixSuggestionLabel()),
        if (suggestedSources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final source in suggestedSources)
                _TrailSourceSuggestionChip(
                  source: source,
                  onSelected: onSuggestedSourceSelected,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sourceSummary in lifetimeStats.sourceSummaries)
              _TrailHistoryChip(
                icon: Icons.hub_outlined,
                label: sourceSummary.compactLabel,
              ),
          ],
        ),
      ],
    );
  }
}

class _TrailSourceSuggestionChip extends StatelessWidget {
  const _TrailSourceSuggestionChip({
    required this.source,
    required this.onSelected,
  });

  final ARTrailSource source;
  final ValueChanged<ARTrailSource> onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: ValueKey('trail_source_suggestion_${source.name}'),
      avatar: Icon(_trailSourceIcon(source), size: 16),
      label: Text(source.label),
      onPressed: () => onSelected(source),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TrailRecentUnlockTile extends StatelessWidget {
  const _TrailRecentUnlockTile({
    required this.unlock,
    required this.index,
  });

  final ARTrailAchievementUnlock unlock;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('trail_recent_unlock_${unlock.id.name}_$index'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        Icons.workspace_premium_outlined,
        color: colorScheme.primary,
      ),
      title: Text('${unlock.title} unlocked'),
      subtitle: Text('Unlocked ${_formatTrailTimestamp(unlock.unlockedAt)}'),
    );
  }
}

class _TrailAchievementTile extends StatelessWidget {
  const _TrailAchievementTile({required this.achievement});

  final ARTrailAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        achievement.isUnlocked ? colorScheme.primary : colorScheme.outline;

    return ListTile(
      key: ValueKey('trail_achievement_${achievement.id.name}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        achievement.isUnlocked ? Icons.emoji_events : Icons.lock_outline,
        color: iconColor,
      ),
      title: Text(achievement.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(achievement.description),
          const SizedBox(height: 2),
          Text(achievement.statusLabel),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: achievement.progressRatio),
        ],
      ),
      trailing: Text(achievement.progressLabel),
    );
  }
}

class _TrailAchievementGroupHeader extends StatelessWidget {
  const _TrailAchievementGroupHeader({
    super.key,
    required this.title,
    required this.countLabel,
  });

  final String title;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall,
          ),
        ),
        Text(
          countLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TrailDetailMetric extends StatelessWidget {
  const _TrailDetailMetric({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}

class _TrailDetailStopTile extends StatelessWidget {
  const _TrailDetailStopTile({
    required this.index,
    required this.memoryId,
    required this.memory,
    required this.onTap,
  });

  final int index;
  final String memoryId;
  final AnchorMemory? memory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final memory = this.memory;
    return ListTile(
      key: ValueKey('trail_detail_stop_$memoryId'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text('${index + 1}'),
      ),
      title: Text(memory?.title ?? memoryId),
      subtitle: Text(
        memory == null
            ? 'Anchor not in nearby cache'
            : '${memory.locationLabel} - ${memory.distanceLabel}',
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _TrailDetailLegTile extends StatelessWidget {
  const _TrailDetailLegTile({required this.leg});

  final ARTrailRouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 8, bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.turn_slight_right,
            color: colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              leg.nextStopLabel,
              key: ValueKey(
                'trail_detail_leg_'
                '${leg.from.memoryId}_${leg.to.memoryId}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailHistorySummaryChips extends StatelessWidget {
  const _TrailHistorySummaryChips({required this.summary});

  final ARTrailHistorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _TrailHistoryChip(
            icon: Icons.flag_outlined,
            label: summary.completedTrailLabel,
          ),
          _TrailHistoryChip(
            icon: Icons.pin_drop_outlined,
            label: summary.reachedStopLabel,
          ),
          _TrailHistoryChip(
            icon: Icons.timer_outlined,
            label: summary.fastestTrailLabel,
          ),
          _TrailHistoryChip(
            icon: Icons.schedule_outlined,
            label: summary.totalElapsedLabel,
          ),
          _TrailHistoryChip(
            icon: Icons.hub_outlined,
            label: summary.sourceBreakdownLabel,
          ),
        ],
      ),
    );
  }
}

class _TrailHistoryChip extends StatelessWidget {
  const _TrailHistoryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                profile.initial,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(profile.handle),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.displayName,
    required this.handle,
  });

  final String displayName;
  final String handle;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _nameController = TextEditingController(
    text: widget.profile.displayName,
  );
  late final _handleController = TextEditingController(
    text: widget.profile.handle,
  );
  var _showNameError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('profile_name_field'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display name',
              errorText: _showNameError ? 'Name required' : null,
            ),
            onChanged: (_) {
              if (_showNameError) {
                setState(() => _showNameError = false);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('profile_handle_field'),
            controller: _handleController,
            decoration: const InputDecoration(labelText: 'Handle'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveProfile,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveProfile() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    Navigator.pop(
      context,
      _ProfileDraft(
        displayName: displayName,
        handle: _handleController.text,
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatCard(label: 'Memories', value: '128')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Walls', value: '12')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Friends', value: '430')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTileActionButton extends StatelessWidget {
  const _FeatureTileActionButton({
    required this.buttonKey,
    required this.action,
  });

  final Key buttonKey;
  final _TrailGoalAction action;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: buttonKey,
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progressKey,
    this.progressLabelKey,
    this.progressLabel,
    this.progressCaptionKey,
    this.progressCaption,
    this.footer,
    this.progressValue,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key? progressKey;
  final Key? progressLabelKey;
  final String? progressLabel;
  final Key? progressCaptionKey;
  final String? progressCaption;
  final Widget? footer;
  final double? progressValue;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final progressValue = this.progressValue;
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: progressValue == null
            ? Text(subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          key: progressKey,
                          value: progressValue.clamp(0.0, 1.0).toDouble(),
                        ),
                      ),
                      if (progressLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          progressLabel!,
                          key: progressLabelKey,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                  if (progressCaption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      progressCaption!,
                      key: progressCaptionKey,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 4),
                    footer!,
                  ],
                ],
              ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
