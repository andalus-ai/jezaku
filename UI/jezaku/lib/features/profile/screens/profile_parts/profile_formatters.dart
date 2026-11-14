part of '../profile_screen.dart';

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
