import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/services/ar_trail_progress_store.dart';

final activeARTrailProgressProvider =
    NotifierProvider<ARTrailProgressController, ARTrailProgress?>(
  ARTrailProgressController.new,
);

final completedARTrailHistoryProvider =
    NotifierProvider<ARTrailHistoryController, List<ARTrailProgress>>(
  ARTrailHistoryController.new,
);

final completedARTrailHistorySummaryProvider =
    Provider<ARTrailHistorySummary>((ref) {
  final completedTrails = ref.watch(completedARTrailHistoryProvider);
  return ARTrailHistorySummary.from(completedTrails);
});

final arTrailLifetimeStatsProvider =
    NotifierProvider<ARTrailLifetimeStatsController, ARTrailLifetimeStats>(
  ARTrailLifetimeStatsController.new,
);

final savedARTrailsProvider =
    NotifierProvider<SavedARTrailsController, List<SavedARTrail>>(
  SavedARTrailsController.new,
);

final arTrailAchievementsProvider = Provider<List<ARTrailAchievement>>((ref) {
  final lifetimeStats = ref.watch(arTrailLifetimeStatsProvider);
  final savedTrails = ref.watch(savedARTrailsProvider);
  return ARTrailAchievement.evaluate(
    lifetimeStats: lifetimeStats,
    savedTrails: savedTrails,
  );
});

final arTrailAchievementUnlocksProvider = NotifierProvider<
    ARTrailAchievementUnlocksController, List<ARTrailAchievementUnlock>>(
  ARTrailAchievementUnlocksController.new,
);

class ARTrailProgressController extends Notifier<ARTrailProgress?> {
  @override
  ARTrailProgress? build() {
    final progress =
        ref.read(arTrailProgressStoreProvider).loadActiveProgress();
    if (progress == null || progress.isFinished) {
      return null;
    }
    return progress;
  }

  void start(
    ARTrailSession session, {
    String? currentMemoryId,
    DateTime? startedAt,
  }) {
    if (!session.canStart) {
      state = null;
      _clearPersistedProgress();
      return;
    }

    final effectiveMemoryId = _effectiveMemoryId(
      session,
      currentMemoryId ?? session.initialMemoryId,
    );
    final progress = ARTrailProgress(
      session: session,
      currentMemoryId: effectiveMemoryId,
      completedMemoryIds: {effectiveMemoryId},
      startedAt: startedAt ?? DateTime.now(),
    );
    state = progress;
    _persistProgress(progress);
  }

  void resume(
    ARTrailSession session, {
    String? currentMemoryId,
    DateTime? startedAt,
  }) {
    final current = state;
    if (current == null ||
        current.isFinished ||
        !current.session.hasSameRouteAs(session)) {
      start(
        session,
        currentMemoryId: currentMemoryId,
        startedAt: startedAt,
      );
      return;
    }

    final effectiveMemoryId = _effectiveMemoryId(
      session,
      currentMemoryId ?? current.currentMemoryId,
    );
    final progress = current.copyWith(
      currentMemoryId: effectiveMemoryId,
      completedMemoryIds: {
        ...current.completedMemoryIds,
        effectiveMemoryId,
      },
    );
    state = progress;
    _persistProgress(progress);
  }

  void focusMemory(String memoryId) {
    final current = state;
    if (current == null || !current.session.memoryIds.contains(memoryId)) {
      return;
    }

    final progress = current.copyWith(
      currentMemoryId: memoryId,
      completedMemoryIds: {
        ...current.completedMemoryIds,
        memoryId,
      },
    );
    state = progress;
    _persistProgress(progress);
  }

  void restore(ARTrailProgress progress) {
    if (progress.isFinished || !progress.session.canStart) {
      return;
    }

    final effectiveMemoryId = _effectiveMemoryId(
      progress.session,
      progress.currentMemoryId,
    );
    final completedMemoryIds = {
      for (final memoryId in progress.completedMemoryIds)
        if (progress.session.memoryIds.contains(memoryId)) memoryId,
      effectiveMemoryId,
    };
    final restoredProgress = ARTrailProgress(
      session: progress.session,
      currentMemoryId: effectiveMemoryId,
      completedMemoryIds: Set.unmodifiable(completedMemoryIds),
      startedAt: progress.startedAt,
    );
    state = restoredProgress;
    _persistProgress(restoredProgress);
  }

  List<ARTrailAchievementUnlock> finish({DateTime? finishedAt}) {
    final current = state;
    if (current == null) {
      return const <ARTrailAchievementUnlock>[];
    }

    final beforeAchievements = ref.read(arTrailAchievementsProvider);
    final finishedProgress = current.copyWith(
      currentMemoryId: current.session.memoryIds.last,
      completedMemoryIds: current.session.memoryIds.toSet(),
      finishedAt: finishedAt ?? DateTime.now(),
    );
    state = finishedProgress;
    _clearPersistedProgress();
    ref.read(completedARTrailHistoryProvider.notifier).record(finishedProgress);
    ref.read(arTrailLifetimeStatsProvider.notifier).record(finishedProgress);
    return ref.read(arTrailAchievementUnlocksProvider.notifier).recordNew(
          before: beforeAchievements,
          after: ref.read(arTrailAchievementsProvider),
          unlockedAt: finishedProgress.finishedAt,
        );
  }

  void clear() {
    state = null;
    _clearPersistedProgress();
  }

  String _effectiveMemoryId(
    ARTrailSession session,
    String? requestedMemoryId,
  ) {
    if (requestedMemoryId != null &&
        session.memoryIds.contains(requestedMemoryId)) {
      return requestedMemoryId;
    }
    return session.memoryIds.first;
  }

  void _persistProgress(ARTrailProgress progress) {
    ref.read(arTrailProgressStoreProvider).saveActiveProgress(progress);
  }

  void _clearPersistedProgress() {
    ref.read(arTrailProgressStoreProvider).clearActiveProgress();
  }
}

class ARTrailHistoryController extends Notifier<List<ARTrailProgress>> {
  @override
  List<ARTrailProgress> build() {
    return ref.read(arTrailProgressStoreProvider).loadCompletedHistory();
  }

  void record(ARTrailProgress progress) {
    if (!progress.isFinished) {
      return;
    }

    final nextState = [
      progress,
      ...state.where(
        (entry) => !_hasSameHistoryEntry(entry, progress),
      ),
    ];
    state = nextState;
    _persistHistory(nextState);
  }

  void remove(ARTrailProgress progress) {
    if (!progress.isFinished) {
      return;
    }

    final nextState = [
      for (final entry in state)
        if (!_hasSameHistoryEntry(entry, progress)) entry,
    ];
    state = nextState;
    _persistHistory(nextState);
  }

  void clear() {
    state = const <ARTrailProgress>[];
    _persistHistory(state);
  }

  bool _hasSameHistoryEntry(
    ARTrailProgress first,
    ARTrailProgress second,
  ) {
    return first.session.hasSameRouteAs(second.session) &&
        first.startedAt == second.startedAt &&
        first.finishedAt == second.finishedAt;
  }

  void _persistHistory(List<ARTrailProgress> history) {
    ref.read(arTrailProgressStoreProvider).saveCompletedHistory(history);
  }
}

class ARTrailLifetimeStatsController extends Notifier<ARTrailLifetimeStats> {
  @override
  ARTrailLifetimeStats build() {
    final store = ref.read(arTrailProgressStoreProvider);
    final persistedStats = store.loadLifetimeStats();
    if (persistedStats.hasProgress) {
      return persistedStats;
    }

    var migratedStats = const ARTrailLifetimeStats.empty();
    for (final progress in store.loadCompletedHistory()) {
      migratedStats = migratedStats.record(progress);
    }
    if (migratedStats.hasProgress) {
      store.saveLifetimeStats(migratedStats);
    }
    return migratedStats;
  }

  void record(ARTrailProgress progress) {
    if (!progress.isFinished) {
      return;
    }

    final nextState = state.record(progress);
    state = nextState;
    ref.read(arTrailProgressStoreProvider).saveLifetimeStats(nextState);
  }
}

class ARTrailAchievementUnlocksController
    extends Notifier<List<ARTrailAchievementUnlock>> {
  @override
  List<ARTrailAchievementUnlock> build() {
    return ref
        .read(arTrailProgressStoreProvider)
        .loadAchievementUnlocks()
        .take(20)
        .toList(growable: false);
  }

  List<ARTrailAchievementUnlock> recordNew({
    required List<ARTrailAchievement> before,
    required List<ARTrailAchievement> after,
    DateTime? unlockedAt,
  }) {
    final previouslyUnlockedIds = {
      for (final achievement in before)
        if (achievement.isUnlocked) achievement.id,
    };
    final newUnlocks = [
      for (final achievement in after)
        if (achievement.isUnlocked &&
            !previouslyUnlockedIds.contains(achievement.id))
          ARTrailAchievementUnlock(
            achievement: achievement,
            unlockedAt: unlockedAt ?? DateTime.now(),
          ),
    ];

    if (newUnlocks.isEmpty) {
      return const <ARTrailAchievementUnlock>[];
    }

    final nextState = [
      ...newUnlocks,
      ...state,
    ].take(20).toList(growable: false);
    state = nextState;
    _persistUnlocks(nextState);
    return List.unmodifiable(newUnlocks);
  }

  void clear() {
    state = const <ARTrailAchievementUnlock>[];
    _persistUnlocks(state);
  }

  void _persistUnlocks(List<ARTrailAchievementUnlock> unlocks) {
    ref.read(arTrailProgressStoreProvider).saveAchievementUnlocks(unlocks);
  }
}

class SavedARTrailsController extends Notifier<List<SavedARTrail>> {
  @override
  List<SavedARTrail> build() {
    return ref.read(arTrailProgressStoreProvider).loadSavedTrails();
  }

  bool isSaved(ARTrailSession session) {
    return state.any((trail) => trail.session.hasSameRouteAs(session));
  }

  List<ARTrailAchievementUnlock> save(
    ARTrailSession session, {
    DateTime? savedAt,
  }) {
    if (!session.canStart || isSaved(session)) {
      return const <ARTrailAchievementUnlock>[];
    }

    final previousState = state;
    final beforeAchievements = _evaluateAchievements(previousState);
    final savedTrail = SavedARTrail(
      session: session,
      savedAt: savedAt ?? DateTime.now(),
    );
    final nextState = [
      savedTrail,
      ...previousState,
    ];
    state = nextState;
    _persistSavedTrails(nextState);
    return ref.read(arTrailAchievementUnlocksProvider.notifier).recordNew(
          before: beforeAchievements,
          after: _evaluateAchievements(nextState),
          unlockedAt: savedTrail.savedAt,
        );
  }

  void unsave(ARTrailSession session) {
    final nextState = [
      for (final trail in state)
        if (!trail.session.hasSameRouteAs(session)) trail,
    ];
    state = nextState;
    _persistSavedTrails(nextState);
  }

  SavedARTrailToggleResult toggle(
    ARTrailSession session, {
    DateTime? savedAt,
  }) {
    if (isSaved(session)) {
      unsave(session);
      return const SavedARTrailToggleResult(
        isSaved: false,
        unlocks: <ARTrailAchievementUnlock>[],
      );
    }

    final unlocks = save(
      session,
      savedAt: savedAt,
    );
    return SavedARTrailToggleResult(
      isSaved: true,
      unlocks: unlocks,
    );
  }

  List<ARTrailAchievement> _evaluateAchievements(
    List<SavedARTrail> savedTrails,
  ) {
    return ARTrailAchievement.evaluate(
      lifetimeStats: ref.read(arTrailLifetimeStatsProvider),
      savedTrails: savedTrails,
    );
  }

  void _persistSavedTrails(List<SavedARTrail> savedTrails) {
    ref.read(arTrailProgressStoreProvider).saveSavedTrails(savedTrails);
  }
}
