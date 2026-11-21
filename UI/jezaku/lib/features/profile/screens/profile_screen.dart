import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/profile/models/profile_rules.dart';
import 'package:jejaku/features/profile/models/user_profile.dart';
import 'package:jejaku/features/profile/states/profile_providers.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

part 'profile_parts/profile_formatters.dart';
part 'profile_parts/profile_saved_trails_sheet.dart';
part 'profile_parts/profile_trail_achievements_sheet.dart';
part 'profile_parts/profile_trail_detail_sheet.dart';
part 'profile_parts/profile_trail_history_sheet.dart';
part 'profile_parts/profile_trail_widgets.dart';
part 'profile_parts/profile_widgets.dart';

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
          _FeatureTile(
            icon: Icons.gavel_outlined,
            title: 'Terms and policies',
            subtitle: 'Terms of use, privacy policy, community guidelines',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.legal);
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
}
