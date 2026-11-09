enum ARTrailSource {
  nearby,
  camera,
  discover,
  gallery,
  search,
  virtualWall,
  memoryDetails,
  custom,
}

extension ARTrailSourceLabel on ARTrailSource {
  String get label {
    return switch (this) {
      ARTrailSource.nearby => 'Nearby',
      ARTrailSource.camera => 'Camera',
      ARTrailSource.discover => 'Discover',
      ARTrailSource.gallery => 'Gallery',
      ARTrailSource.search => 'Search',
      ARTrailSource.virtualWall => 'Virtual Wall',
      ARTrailSource.memoryDetails => 'Memory Details',
      ARTrailSource.custom => 'Custom',
    };
  }
}

class ARTrailSession {
  const ARTrailSession._({
    required this.title,
    required this.memoryIds,
    required this.source,
    this.focusedMemoryId,
    this.sourceWallId,
  });

  factory ARTrailSession.fromMemoryIds({
    required String title,
    required Iterable<String> memoryIds,
    ARTrailSource source = ARTrailSource.custom,
    String? focusedMemoryId,
    String? sourceWallId,
  }) {
    final seenMemoryIds = <String>{};
    final normalizedIds = [
      for (final memoryId in memoryIds) memoryId.trim(),
    ].where((memoryId) {
      return memoryId.isNotEmpty && seenMemoryIds.add(memoryId);
    }).toList(growable: false);
    final normalizedFocusedMemoryId = focusedMemoryId?.trim();
    final normalizedSourceWallId = sourceWallId?.trim();
    final effectiveFocus = normalizedFocusedMemoryId != null &&
            normalizedIds.contains(normalizedFocusedMemoryId)
        ? normalizedFocusedMemoryId
        : normalizedIds.isEmpty
            ? null
            : normalizedIds.first;

    return ARTrailSession._(
      title: title.trim().isEmpty ? 'AR trail' : title.trim(),
      memoryIds: List.unmodifiable(normalizedIds),
      source: source,
      focusedMemoryId: effectiveFocus,
      sourceWallId:
          normalizedSourceWallId == null || normalizedSourceWallId.isEmpty
              ? null
              : normalizedSourceWallId,
    );
  }

  final String title;
  final List<String> memoryIds;
  final ARTrailSource source;
  final String? focusedMemoryId;
  final String? sourceWallId;

  String? get initialMemoryId {
    return focusedMemoryId ?? (memoryIds.isEmpty ? null : memoryIds.first);
  }

  bool get canStart => memoryIds.length > 1;

  String get sourceLabel {
    return source.label;
  }

  String get stopCountLabel {
    final stopLabel = memoryIds.length == 1 ? 'stop' : 'stops';
    return '${memoryIds.length} $stopLabel';
  }

  bool hasSameRouteAs(ARTrailSession other) {
    if (title != other.title ||
        source != other.source ||
        sourceWallId != other.sourceWallId ||
        memoryIds.length != other.memoryIds.length) {
      return false;
    }

    for (var index = 0; index < memoryIds.length; index++) {
      if (memoryIds[index] != other.memoryIds[index]) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'memoryIds': memoryIds,
      'source': source.name,
      'focusedMemoryId': focusedMemoryId,
      'sourceWallId': sourceWallId,
    };
  }

  static ARTrailSession? fromJson(Map<String, Object?> json) {
    final title = json['title'];
    final memoryIds = json['memoryIds'];
    if (title is! String || memoryIds is! List) {
      return null;
    }

    return ARTrailSession.fromMemoryIds(
      title: title,
      memoryIds: [
        for (final memoryId in memoryIds)
          if (memoryId is String) memoryId,
      ],
      source: _parseARTrailSource(json['source']),
      focusedMemoryId: json['focusedMemoryId'] is String
          ? json['focusedMemoryId'] as String
          : null,
      sourceWallId: json['sourceWallId'] is String
          ? json['sourceWallId'] as String
          : null,
    );
  }
}

class ARTrailProgress {
  const ARTrailProgress({
    required this.session,
    required this.currentMemoryId,
    required this.completedMemoryIds,
    required this.startedAt,
    this.finishedAt,
  });

  final ARTrailSession session;
  final String currentMemoryId;
  final Set<String> completedMemoryIds;
  final DateTime startedAt;
  final DateTime? finishedAt;

  int get currentStopIndex {
    final index = session.memoryIds.indexOf(currentMemoryId);
    return index < 0 ? 0 : index;
  }

  int get totalStops => session.memoryIds.length;

  int get completedStopCount {
    return completedMemoryIds
        .where((memoryId) => session.memoryIds.contains(memoryId))
        .length;
  }

  bool get isFinished => finishedAt != null;

  Duration? get elapsed {
    final finishedAt = this.finishedAt;
    if (finishedAt == null) {
      return null;
    }
    return finishedAt.difference(startedAt);
  }

  String get progressLabel => '$completedStopCount/$totalStops reached';

  String get currentStopLabel => 'Stop ${currentStopIndex + 1} of $totalStops';

  String get elapsedLabel {
    final elapsed = this.elapsed;
    if (elapsed == null) {
      return 'In progress';
    }
    return _formatTrailDuration(elapsed);
  }

  ARTrailProgress copyWith({
    String? currentMemoryId,
    Set<String>? completedMemoryIds,
    DateTime? finishedAt,
  }) {
    return ARTrailProgress(
      session: session,
      currentMemoryId: currentMemoryId ?? this.currentMemoryId,
      completedMemoryIds:
          Set.unmodifiable(completedMemoryIds ?? this.completedMemoryIds),
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'session': session.toJson(),
      'currentMemoryId': currentMemoryId,
      'completedMemoryIds': completedMemoryIds.toList(growable: false),
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  static ARTrailProgress? fromJson(Map<String, Object?> json) {
    final sessionJson = json['session'];
    final currentMemoryId = json['currentMemoryId'];
    final completedMemoryIds = json['completedMemoryIds'];
    final startedAt = DateTime.tryParse('${json['startedAt'] ?? ''}');
    final finishedAtValue = json['finishedAt'];
    final finishedAt = finishedAtValue == null
        ? null
        : DateTime.tryParse(finishedAtValue.toString());

    if (sessionJson is! Map ||
        currentMemoryId is! String ||
        completedMemoryIds is! List ||
        startedAt == null) {
      return null;
    }

    final session = ARTrailSession.fromJson(
      Map<String, Object?>.from(sessionJson),
    );
    if (session == null || !session.canStart) {
      return null;
    }

    final effectiveMemoryId = session.memoryIds.contains(currentMemoryId)
        ? currentMemoryId
        : session.initialMemoryId;
    if (effectiveMemoryId == null) {
      return null;
    }

    final reachedMemoryIds = {
      for (final memoryId in completedMemoryIds)
        if (memoryId is String && session.memoryIds.contains(memoryId))
          memoryId,
      effectiveMemoryId,
    };

    return ARTrailProgress(
      session: session,
      currentMemoryId: effectiveMemoryId,
      completedMemoryIds: Set.unmodifiable(reachedMemoryIds),
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

class SavedARTrail {
  const SavedARTrail({
    required this.session,
    required this.savedAt,
  });

  final ARTrailSession session;
  final DateTime savedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'session': session.toJson(),
      'savedAt': savedAt.toIso8601String(),
    };
  }

  static SavedARTrail? fromJson(Map<String, Object?> json) {
    final sessionJson = json['session'];
    final savedAt = DateTime.tryParse('${json['savedAt'] ?? ''}');
    if (sessionJson is! Map || savedAt == null) {
      return null;
    }

    final session = ARTrailSession.fromJson(
      Map<String, Object?>.from(sessionJson),
    );
    if (session == null || !session.canStart) {
      return null;
    }

    return SavedARTrail(
      session: session,
      savedAt: savedAt,
    );
  }
}

enum ARTrailAchievementId {
  firstTrail,
  stopCollector,
  cameraExplorer,
  wallExplorer,
  sourceSampler,
  routeKeeper,
}

class ARTrailAchievement {
  const ARTrailAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.currentValue,
    required this.targetValue,
    required this.unitSingular,
    required this.unitPlural,
  });

  final ARTrailAchievementId id;
  final String title;
  final String description;
  final int currentValue;
  final int targetValue;
  final String unitSingular;
  final String unitPlural;

  bool get isUnlocked => currentValue >= targetValue;

  int get visibleValue {
    if (currentValue < 0) {
      return 0;
    }
    if (currentValue > targetValue) {
      return targetValue;
    }
    return currentValue;
  }

  double get progressRatio {
    if (targetValue <= 0) {
      return 1;
    }
    return visibleValue / targetValue;
  }

  String get progressLabel => '$visibleValue/$targetValue';

  int get remainingValue {
    final remaining = targetValue - visibleValue;
    return remaining < 0 ? 0 : remaining;
  }

  String get statusLabel {
    if (isUnlocked) {
      return 'Unlocked';
    }

    final unit = remainingValue == 1 ? unitSingular : unitPlural;
    return '$remainingValue more $unit to unlock';
  }

  static List<ARTrailAchievement> evaluate({
    required ARTrailLifetimeStats lifetimeStats,
    required List<SavedARTrail> savedTrails,
  }) {
    final cameraTrailCount =
        lifetimeStats.completedTrailCountForSource(ARTrailSource.camera);
    final wallTrailCount =
        lifetimeStats.completedTrailCountForSource(ARTrailSource.virtualWall);

    return [
      ARTrailAchievement(
        id: ARTrailAchievementId.firstTrail,
        title: 'First Trail',
        description: 'Complete your first AR route.',
        currentValue: lifetimeStats.completedTrailCount,
        targetValue: 1,
        unitSingular: 'trail',
        unitPlural: 'trails',
      ),
      ARTrailAchievement(
        id: ARTrailAchievementId.stopCollector,
        title: 'Stop Collector',
        description: 'Reach 10 stops across completed trails.',
        currentValue: lifetimeStats.reachedStopCount,
        targetValue: 10,
        unitSingular: 'stop',
        unitPlural: 'stops',
      ),
      ARTrailAchievement(
        id: ARTrailAchievementId.cameraExplorer,
        title: 'Camera Explorer',
        description: 'Finish a trail started from the camera.',
        currentValue: cameraTrailCount,
        targetValue: 1,
        unitSingular: 'camera trail',
        unitPlural: 'camera trails',
      ),
      ARTrailAchievement(
        id: ARTrailAchievementId.wallExplorer,
        title: 'Wall Explorer',
        description: 'Complete a trail from a virtual wall.',
        currentValue: wallTrailCount,
        targetValue: 1,
        unitSingular: 'wall trail',
        unitPlural: 'wall trails',
      ),
      ARTrailAchievement(
        id: ARTrailAchievementId.sourceSampler,
        title: 'Source Sampler',
        description: 'Complete trails from 3 different sources.',
        currentValue: lifetimeStats.completedSourceCount,
        targetValue: 3,
        unitSingular: 'source',
        unitPlural: 'sources',
      ),
      ARTrailAchievement(
        id: ARTrailAchievementId.routeKeeper,
        title: 'Route Keeper',
        description: 'Save a completed route for replay.',
        currentValue: savedTrails.length,
        targetValue: 1,
        unitSingular: 'saved trail',
        unitPlural: 'saved trails',
      ),
    ];
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id.name,
      'title': title,
      'description': description,
      'currentValue': currentValue,
      'targetValue': targetValue,
      'unitSingular': unitSingular,
      'unitPlural': unitPlural,
    };
  }

  static ARTrailAchievement? fromJson(Map<String, Object?> json) {
    final id = _parseARTrailAchievementId(json['id']);
    final title = json['title'];
    final description = json['description'];
    final currentValue = json['currentValue'];
    final targetValue = json['targetValue'];
    final unitSingular = json['unitSingular'];
    final unitPlural = json['unitPlural'];

    if (id == null ||
        title is! String ||
        description is! String ||
        currentValue is! int ||
        targetValue is! int ||
        unitSingular is! String ||
        unitPlural is! String) {
      return null;
    }

    return ARTrailAchievement(
      id: id,
      title: title,
      description: description,
      currentValue: currentValue,
      targetValue: targetValue,
      unitSingular: unitSingular,
      unitPlural: unitPlural,
    );
  }
}

class ARTrailAchievementUnlock {
  const ARTrailAchievementUnlock({
    required this.achievement,
    required this.unlockedAt,
  });

  final ARTrailAchievement achievement;
  final DateTime unlockedAt;

  ARTrailAchievementId get id => achievement.id;

  String get title => achievement.title;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'achievement': achievement.toJson(),
      'unlockedAt': unlockedAt.toIso8601String(),
    };
  }

  static ARTrailAchievementUnlock? fromJson(Map<String, Object?> json) {
    final achievementJson = json['achievement'];
    final unlockedAt = DateTime.tryParse('${json['unlockedAt'] ?? ''}');
    if (achievementJson is! Map || unlockedAt == null) {
      return null;
    }

    final achievement = ARTrailAchievement.fromJson(
      Map<String, Object?>.from(achievementJson),
    );
    if (achievement == null) {
      return null;
    }

    return ARTrailAchievementUnlock(
      achievement: achievement,
      unlockedAt: unlockedAt,
    );
  }
}

class SavedARTrailToggleResult {
  const SavedARTrailToggleResult({
    required this.isSaved,
    required this.unlocks,
  });

  final bool isSaved;
  final List<ARTrailAchievementUnlock> unlocks;
}

String formatARTrailAchievementUnlocks(
  Iterable<ARTrailAchievementUnlock> unlocks,
) {
  final visibleUnlocks = unlocks.toList(growable: false);
  if (visibleUnlocks.isEmpty) {
    return 'No achievements unlocked';
  }

  final prefix = visibleUnlocks.length == 1
      ? 'Achievement unlocked'
      : 'Achievements unlocked';
  final titles = visibleUnlocks.map((unlock) => unlock.title).join(', ');
  return '$prefix: $titles';
}

class ARTrailLifetimeStats {
  const ARTrailLifetimeStats({
    required this.completedTrailCount,
    required this.reachedStopCount,
    required this.sourceSummaries,
  });

  const ARTrailLifetimeStats.empty()
      : completedTrailCount = 0,
        reachedStopCount = 0,
        sourceSummaries = const <ARTrailSourceSummary>[];

  final int completedTrailCount;
  final int reachedStopCount;
  final List<ARTrailSourceSummary> sourceSummaries;

  bool get hasProgress => completedTrailCount > 0 || reachedStopCount > 0;

  int get completedSourceCount => sourceSummaries.length;

  Set<ARTrailSource> get completedSources {
    return Set.unmodifiable(
      sourceSummaries.map((summary) => summary.source),
    );
  }

  String sourceMixProgressLabel({int targetSourceCount = 3}) {
    final visibleSourceCount = completedSourceCount > targetSourceCount
        ? targetSourceCount
        : completedSourceCount;
    return '$visibleSourceCount/$targetSourceCount sources completed';
  }

  List<ARTrailSource> suggestedSources({int targetSourceCount = 3}) {
    final remainingSourceCount = targetSourceCount - completedSourceCount;
    if (remainingSourceCount <= 0) {
      return const <ARTrailSource>[];
    }

    final completed = completedSources;
    return [
      for (final source in _sourceSamplerSuggestionOrder)
        if (!completed.contains(source)) source,
    ].take(remainingSourceCount).toList(growable: false);
  }

  String sourceMixSuggestionLabel({int targetSourceCount = 3}) {
    final suggestions = suggestedSources(targetSourceCount: targetSourceCount);
    if (suggestions.isEmpty) {
      return 'Source variety complete';
    }

    final labels =
        suggestions.map((source) => source.label).toList(growable: false);
    return 'Try ${_joinHumanList(labels)} next';
  }

  ARTrailLifetimeStats record(ARTrailProgress progress) {
    if (!progress.isFinished) {
      return this;
    }

    final sourceCounts = {
      for (final summary in sourceSummaries)
        summary.source: summary.completedTrailCount,
    };
    sourceCounts.update(
      progress.session.source,
      (count) => count + 1,
      ifAbsent: () => 1,
    );

    return ARTrailLifetimeStats(
      completedTrailCount: completedTrailCount + 1,
      reachedStopCount: reachedStopCount + progress.completedStopCount,
      sourceSummaries: _sortedSourceSummaries(sourceCounts),
    );
  }

  int completedTrailCountForSource(ARTrailSource source) {
    for (final summary in sourceSummaries) {
      if (summary.source == source) {
        return summary.completedTrailCount;
      }
    }
    return 0;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'completedTrailCount': completedTrailCount,
      'reachedStopCount': reachedStopCount,
      'sourceSummaries': [
        for (final summary in sourceSummaries) summary.toJson(),
      ],
    };
  }

  static ARTrailLifetimeStats? fromJson(Map<String, Object?> json) {
    final completedTrailCount = json['completedTrailCount'];
    final reachedStopCount = json['reachedStopCount'];
    final sourceSummaries = json['sourceSummaries'];
    if (completedTrailCount is! int ||
        reachedStopCount is! int ||
        sourceSummaries is! List) {
      return null;
    }

    final sourceCounts = <ARTrailSource, int>{};
    for (final summaryJson in sourceSummaries) {
      if (summaryJson is! Map) {
        continue;
      }
      final summary = ARTrailSourceSummary.fromJson(
        Map<String, Object?>.from(summaryJson),
      );
      if (summary == null) {
        continue;
      }
      sourceCounts.update(
        summary.source,
        (count) => count + summary.completedTrailCount,
        ifAbsent: () => summary.completedTrailCount,
      );
    }

    return ARTrailLifetimeStats(
      completedTrailCount: completedTrailCount < 0 ? 0 : completedTrailCount,
      reachedStopCount: reachedStopCount < 0 ? 0 : reachedStopCount,
      sourceSummaries: _sortedSourceSummaries(sourceCounts),
    );
  }
}

const _sourceSamplerSuggestionOrder = <ARTrailSource>[
  ARTrailSource.nearby,
  ARTrailSource.gallery,
  ARTrailSource.virtualWall,
  ARTrailSource.camera,
  ARTrailSource.discover,
  ARTrailSource.search,
  ARTrailSource.memoryDetails,
  ARTrailSource.custom,
];

class ARTrailHistorySummary {
  const ARTrailHistorySummary({
    required this.completedTrailCount,
    required this.reachedStopCount,
    required this.totalElapsed,
    required this.sourceSummaries,
    this.fastestTrail,
    this.latestTrail,
  });

  factory ARTrailHistorySummary.from(Iterable<ARTrailProgress> trails) {
    var completedTrailCount = 0;
    var reachedStopCount = 0;
    var totalElapsed = Duration.zero;
    final sourceCounts = <ARTrailSource, int>{};
    Duration? fastestElapsed;
    ARTrailProgress? fastestTrail;
    ARTrailProgress? latestTrail;

    for (final trail in trails) {
      if (!trail.isFinished) {
        continue;
      }

      completedTrailCount++;
      reachedStopCount += trail.completedStopCount;
      sourceCounts.update(
        trail.session.source,
        (count) => count + 1,
        ifAbsent: () => 1,
      );

      final finishedAt = trail.finishedAt;
      if (finishedAt != null &&
          (latestTrail == null ||
              finishedAt.isAfter(latestTrail.finishedAt!))) {
        latestTrail = trail;
      }

      final elapsed = trail.elapsed;
      if (elapsed == null) {
        continue;
      }

      final normalizedElapsed = elapsed.isNegative ? Duration.zero : elapsed;
      totalElapsed += normalizedElapsed;
      if (fastestElapsed == null || normalizedElapsed < fastestElapsed) {
        fastestElapsed = normalizedElapsed;
        fastestTrail = trail;
      }
    }

    return ARTrailHistorySummary(
      completedTrailCount: completedTrailCount,
      reachedStopCount: reachedStopCount,
      totalElapsed: totalElapsed,
      sourceSummaries: _sortedSourceSummaries(sourceCounts),
      fastestTrail: fastestTrail,
      latestTrail: latestTrail,
    );
  }

  final int completedTrailCount;
  final int reachedStopCount;
  final Duration totalElapsed;
  final List<ARTrailSourceSummary> sourceSummaries;
  final ARTrailProgress? fastestTrail;
  final ARTrailProgress? latestTrail;

  bool get hasHistory => completedTrailCount > 0;

  String get completedTrailLabel {
    final trailLabel = completedTrailCount == 1 ? 'trail' : 'trails';
    return '$completedTrailCount completed $trailLabel';
  }

  String get reachedStopLabel {
    final stopLabel = reachedStopCount == 1 ? 'stop' : 'stops';
    return '$reachedStopCount $stopLabel reached';
  }

  String get fastestTrailLabel {
    final fastestTrail = this.fastestTrail;
    if (fastestTrail == null) {
      return 'No timing yet';
    }
    return 'Fastest ${fastestTrail.elapsedLabel}';
  }

  String get totalElapsedLabel {
    return '${_formatTrailDuration(totalElapsed)} total';
  }

  String get sourceBreakdownLabel {
    if (sourceSummaries.isEmpty) {
      return 'No sources yet';
    }

    final visibleSummaries = sourceSummaries.take(3).toList(growable: false);
    final remainingCount = sourceSummaries.length - visibleSummaries.length;
    return [
      for (final summary in visibleSummaries) summary.compactLabel,
      if (remainingCount > 0) '+$remainingCount',
    ].join(', ');
  }

  int completedTrailCountForSource(ARTrailSource source) {
    for (final summary in sourceSummaries) {
      if (summary.source == source) {
        return summary.completedTrailCount;
      }
    }
    return 0;
  }
}

class ARTrailSourceSummary {
  const ARTrailSourceSummary({
    required this.source,
    required this.completedTrailCount,
  });

  final ARTrailSource source;
  final int completedTrailCount;

  String get compactLabel => '${source.label} $completedTrailCount';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source': source.name,
      'completedTrailCount': completedTrailCount,
    };
  }

  static ARTrailSourceSummary? fromJson(Map<String, Object?> json) {
    final completedTrailCount = json['completedTrailCount'];
    if (completedTrailCount is! int || completedTrailCount <= 0) {
      return null;
    }

    return ARTrailSourceSummary(
      source: _parseARTrailSource(json['source']),
      completedTrailCount: completedTrailCount,
    );
  }
}

String _formatTrailDuration(Duration duration) {
  final normalizedDuration = duration.isNegative ? Duration.zero : duration;
  if (normalizedDuration.inMinutes < 1) {
    return '<1 min';
  }
  if (normalizedDuration.inHours < 1) {
    return '${normalizedDuration.inMinutes} min';
  }
  final hours = normalizedDuration.inHours;
  final minutes = normalizedDuration.inMinutes.remainder(60);
  if (minutes == 0) {
    return '$hours hr';
  }
  return '$hours hr $minutes min';
}

List<ARTrailSourceSummary> _sortedSourceSummaries(
  Map<ARTrailSource, int> sourceCounts,
) {
  final summaries = [
    for (final entry in sourceCounts.entries)
      ARTrailSourceSummary(
        source: entry.key,
        completedTrailCount: entry.value,
      ),
  ];
  summaries.sort((a, b) {
    final countComparison =
        b.completedTrailCount.compareTo(a.completedTrailCount);
    if (countComparison != 0) {
      return countComparison;
    }
    return a.source.index.compareTo(b.source.index);
  });
  return List.unmodifiable(summaries);
}

String _joinHumanList(List<String> labels) {
  if (labels.isEmpty) {
    return '';
  }
  if (labels.length == 1) {
    return labels.single;
  }
  if (labels.length == 2) {
    return '${labels.first} and ${labels.last}';
  }

  final leadingLabels = labels.take(labels.length - 1).join(', ');
  return '$leadingLabels, and ${labels.last}';
}

ARTrailSource _parseARTrailSource(Object? value) {
  if (value is String) {
    for (final source in ARTrailSource.values) {
      if (source.name == value) {
        return source;
      }
    }
  }
  return ARTrailSource.custom;
}

ARTrailAchievementId? _parseARTrailAchievementId(Object? value) {
  if (value is String) {
    for (final id in ARTrailAchievementId.values) {
      if (id.name == value) {
        return id;
      }
    }
  }
  return null;
}
