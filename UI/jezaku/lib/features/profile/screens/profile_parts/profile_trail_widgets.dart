part of '../profile_screen.dart';

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
