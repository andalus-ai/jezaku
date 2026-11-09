import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/services/ar_trail_progress_store.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('progress controller starts and advances a trail session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Capture perimeter trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.camera,
    );

    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 29, 9),
    );

    final initialProgress = container.read(activeARTrailProgressProvider);
    expect(initialProgress, isNotNull);
    expect(initialProgress!.currentMemoryId, 'anchor_courtyard');
    expect(initialProgress.startedAt, DateTime(2026, 5, 29, 9));
    expect(initialProgress.completedMemoryIds, {'anchor_courtyard'});
    expect(initialProgress.progressLabel, '1/3 reached');
    expect(initialProgress.currentStopLabel, 'Stop 1 of 3');
    expect(initialProgress.isFinished, isFalse);

    controller.focusMemory('anchor_private');
    final advancedProgress = container.read(activeARTrailProgressProvider);

    expect(advancedProgress, isNotNull);
    expect(advancedProgress!.currentMemoryId, 'anchor_private');
    expect(advancedProgress.completedMemoryIds, {
      'anchor_courtyard',
      'anchor_private',
    });
    expect(advancedProgress.progressLabel, '2/3 reached');
  });

  test('progress controller ignores invalid focus and finishes all stops', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Wall trail',
      memoryIds: const ['anchor_courtyard', 'anchor_private'],
      source: ARTrailSource.virtualWall,
    );

    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(session);
    controller.focusMemory('missing_anchor');

    final initialProgress = container.read(activeARTrailProgressProvider);
    expect(initialProgress, isNotNull);
    expect(initialProgress!.currentMemoryId, 'anchor_courtyard');
    expect(initialProgress.progressLabel, '1/2 reached');

    controller.finish(finishedAt: DateTime(2026, 5, 29, 10));
    final finishedProgress = container.read(activeARTrailProgressProvider);
    final history = container.read(completedARTrailHistoryProvider);

    expect(finishedProgress, isNotNull);
    expect(finishedProgress!.currentMemoryId, 'anchor_private');
    expect(finishedProgress.completedMemoryIds, {
      'anchor_courtyard',
      'anchor_private',
    });
    expect(finishedProgress.progressLabel, '2/2 reached');
    expect(finishedProgress.finishedAt, DateTime(2026, 5, 29, 10));
    expect(finishedProgress.isFinished, isTrue);
    expect(history, hasLength(1));
    expect(history.single.session.title, 'Wall trail');
    expect(history.single.elapsedLabel, '<1 min');
  });

  test('progress controller resumes matching route without resetting progress',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Nearby memory trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );

    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(session);
    controller.focusMemory('anchor_rooftop');
    controller.resume(
      session,
      currentMemoryId: 'anchor_private',
    );

    final progress = container.read(activeARTrailProgressProvider);
    expect(progress, isNotNull);
    expect(progress!.currentMemoryId, 'anchor_private');
    expect(progress.completedMemoryIds, {
      'anchor_courtyard',
      'anchor_rooftop',
      'anchor_private',
    });
    expect(progress.progressLabel, '3/3 reached');
  });

  test('progress controller restores a cleared active progress snapshot', () {
    final store = InMemoryARTrailProgressStore();
    final container = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Undo trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );

    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12),
    );
    controller.focusMemory('anchor_rooftop');
    final snapshot = container.read(activeARTrailProgressProvider);

    controller.clear();
    expect(container.read(activeARTrailProgressProvider), isNull);

    controller.restore(snapshot!);
    final restored = container.read(activeARTrailProgressProvider);

    expect(restored, isNotNull);
    expect(restored!.session.title, 'Undo trail');
    expect(restored.startedAt, DateTime(2026, 5, 30, 12));
    expect(restored.currentMemoryId, 'anchor_rooftop');
    expect(restored.completedMemoryIds, {
      'anchor_courtyard',
      'anchor_rooftop',
    });

    final restoredContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(restoredContainer.dispose);

    expect(
      restoredContainer.read(activeARTrailProgressProvider)?.currentMemoryId,
      'anchor_rooftop',
    );
  });

  test('progress controller restores unfinished active trail from store', () {
    final store = InMemoryARTrailProgressStore();
    final session = ARTrailSession.fromMemoryIds(
      title: 'Persistent nearby trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final firstContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );

    firstContainer.read(activeARTrailProgressProvider.notifier).start(
          session,
          startedAt: DateTime(2026, 5, 29, 20),
        );
    firstContainer
        .read(activeARTrailProgressProvider.notifier)
        .focusMemory('anchor_rooftop');
    firstContainer.dispose();

    final restoredContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(restoredContainer.dispose);

    final restoredProgress =
        restoredContainer.read(activeARTrailProgressProvider);

    expect(restoredProgress, isNotNull);
    expect(restoredProgress!.session.title, 'Persistent nearby trail');
    expect(restoredProgress.currentMemoryId, 'anchor_rooftop');
    expect(restoredProgress.completedMemoryIds, {
      'anchor_courtyard',
      'anchor_rooftop',
    });
    expect(restoredProgress.startedAt, DateTime(2026, 5, 29, 20));

    restoredContainer.read(activeARTrailProgressProvider.notifier).clear();

    expect(store.loadActiveProgress(), isNull);
  });

  test('finishing a trail clears persisted active progress', () {
    final store = InMemoryARTrailProgressStore();
    final container = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Finished persistent trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.gallery,
    );

    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 29, 21),
    );

    expect(store.loadActiveProgress(), isNotNull);

    controller.finish(finishedAt: DateTime(2026, 5, 29, 21, 5));

    expect(store.loadActiveProgress(), isNull);
    expect(container.read(completedARTrailHistoryProvider), hasLength(1));
  });

  test('shared preferences trail store round-trips active progress', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARTrailProgressStore(
      preferences: preferences,
    );
    final session = ARTrailSession.fromMemoryIds(
      title: 'Restored from preferences',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.search,
    );
    final progress = ARTrailProgress(
      session: session,
      currentMemoryId: 'anchor_rooftop',
      completedMemoryIds: const {
        'anchor_courtyard',
        'anchor_rooftop',
      },
      startedAt: DateTime(2026, 5, 29, 22),
    );

    store.saveActiveProgress(progress);
    await Future<void>.delayed(Duration.zero);

    final restoredProgress = store.loadActiveProgress();

    expect(restoredProgress, isNotNull);
    expect(restoredProgress!.session.title, 'Restored from preferences');
    expect(restoredProgress.session.source, ARTrailSource.search);
    expect(restoredProgress.currentMemoryId, 'anchor_rooftop');
    expect(restoredProgress.completedMemoryIds, {
      'anchor_courtyard',
      'anchor_rooftop',
    });
    expect(restoredProgress.startedAt, DateTime(2026, 5, 29, 22));

    store.clearActiveProgress();
    await Future<void>.delayed(Duration.zero);

    expect(store.loadActiveProgress(), isNull);
  });

  test(
      'trail library controllers restore history saved routes and lifetime stats',
      () {
    final store = InMemoryARTrailProgressStore();
    final firstContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    final restoredContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    final afterClearContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(firstContainer.dispose);
    addTearDown(restoredContainer.dispose);
    addTearDown(afterClearContainer.dispose);

    final session = ARTrailSession.fromMemoryIds(
      title: 'Persistent library trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.camera,
    );
    final progressController =
        firstContainer.read(activeARTrailProgressProvider.notifier);

    progressController.start(
      session,
      startedAt: DateTime(2026, 5, 29, 23),
    );
    progressController.finish(finishedAt: DateTime(2026, 5, 29, 23, 8));
    firstContainer.read(savedARTrailsProvider.notifier).save(
          session,
          savedAt: DateTime(2026, 5, 29, 23, 9),
        );

    final restoredHistory =
        restoredContainer.read(completedARTrailHistoryProvider);
    final restoredSavedTrails = restoredContainer.read(savedARTrailsProvider);
    final restoredStats = restoredContainer.read(arTrailLifetimeStatsProvider);
    final restoredAchievements = {
      for (final achievement
          in restoredContainer.read(arTrailAchievementsProvider))
        achievement.id: achievement,
    };

    expect(restoredHistory, hasLength(1));
    expect(restoredHistory.single.session.title, 'Persistent library trail');
    expect(restoredHistory.single.elapsedLabel, '8 min');
    expect(restoredSavedTrails, hasLength(1));
    expect(restoredSavedTrails.single.savedAt, DateTime(2026, 5, 29, 23, 9));
    expect(restoredStats.completedTrailCount, 1);
    expect(restoredStats.reachedStopCount, 3);
    expect(restoredStats.completedTrailCountForSource(ARTrailSource.camera), 1);
    expect(
      restoredAchievements[ARTrailAchievementId.firstTrail]?.isUnlocked,
      isTrue,
    );
    expect(
      restoredAchievements[ARTrailAchievementId.routeKeeper]?.isUnlocked,
      isTrue,
    );

    restoredContainer.read(completedARTrailHistoryProvider.notifier).clear();

    expect(afterClearContainer.read(completedARTrailHistoryProvider), isEmpty);
    expect(afterClearContainer.read(savedARTrailsProvider), hasLength(1));
    expect(
      afterClearContainer
          .read(arTrailLifetimeStatsProvider)
          .completedTrailCount,
      1,
    );
  });

  test('achievement unlock controller restores recent unlock feed', () {
    final store = InMemoryARTrailProgressStore();
    final firstContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    final restoredContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    final afterClearContainer = ProviderContainer(
      overrides: [
        arTrailProgressStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(firstContainer.dispose);
    addTearDown(restoredContainer.dispose);
    addTearDown(afterClearContainer.dispose);

    final session = ARTrailSession.fromMemoryIds(
      title: 'Persistent unlock trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.camera,
    );
    final progressController =
        firstContainer.read(activeARTrailProgressProvider.notifier);

    progressController.start(
      session,
      startedAt: DateTime(2026, 5, 30, 7),
    );
    progressController.finish(finishedAt: DateTime(2026, 5, 30, 7, 4));
    firstContainer.read(savedARTrailsProvider.notifier).save(
          session,
          savedAt: DateTime(2026, 5, 30, 7, 5),
        );

    final restoredUnlocks =
        restoredContainer.read(arTrailAchievementUnlocksProvider);

    expect(restoredUnlocks.map((unlock) => unlock.title), [
      'Route Keeper',
      'First Trail',
      'Camera Explorer',
    ]);
    expect(restoredUnlocks.first.unlockedAt, DateTime(2026, 5, 30, 7, 5));
    expect(
      restoredUnlocks.last.unlockedAt,
      DateTime(2026, 5, 30, 7, 4),
    );

    restoredContainer.read(arTrailAchievementUnlocksProvider.notifier).clear();

    expect(
      afterClearContainer.read(arTrailAchievementUnlocksProvider),
      isEmpty,
    );
  });

  test('shared preferences trail store round-trips trail library state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARTrailProgressStore(
      preferences: preferences,
    );
    final session = ARTrailSession.fromMemoryIds(
      title: 'Preference library trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.virtualWall,
      sourceWallId: 'wall_class_reunion',
    );
    final progress = ARTrailProgress(
      session: session,
      currentMemoryId: 'anchor_private',
      completedMemoryIds: const {
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      },
      startedAt: DateTime(2026, 5, 30, 8),
      finishedAt: DateTime(2026, 5, 30, 8, 6),
    );
    final savedTrail = SavedARTrail(
      session: session,
      savedAt: DateTime(2026, 5, 30, 8, 7),
    );
    final lifetimeStats = const ARTrailLifetimeStats.empty().record(progress);
    final unlockAchievement = ARTrailAchievement.evaluate(
      lifetimeStats: lifetimeStats,
      savedTrails: [savedTrail],
    ).firstWhere(
      (achievement) => achievement.id == ARTrailAchievementId.wallExplorer,
    );
    final unlock = ARTrailAchievementUnlock(
      achievement: unlockAchievement,
      unlockedAt: DateTime(2026, 5, 30, 8, 6),
    );

    store.saveCompletedHistory([progress]);
    store.saveSavedTrails([savedTrail]);
    store.saveLifetimeStats(lifetimeStats);
    store.saveAchievementUnlocks([unlock]);
    await Future<void>.delayed(Duration.zero);

    final restoredStore = SharedPreferencesARTrailProgressStore(
      preferences: preferences,
    );
    final restoredHistory = restoredStore.loadCompletedHistory();
    final restoredSavedTrails = restoredStore.loadSavedTrails();
    final restoredStats = restoredStore.loadLifetimeStats();
    final restoredUnlocks = restoredStore.loadAchievementUnlocks();

    expect(restoredHistory, hasLength(1));
    expect(restoredHistory.single.session.source, ARTrailSource.virtualWall);
    expect(restoredHistory.single.finishedAt, DateTime(2026, 5, 30, 8, 6));
    expect(restoredSavedTrails, hasLength(1));
    expect(
        restoredSavedTrails.single.session.sourceWallId, 'wall_class_reunion');
    expect(restoredSavedTrails.single.savedAt, DateTime(2026, 5, 30, 8, 7));
    expect(restoredStats.completedTrailCount, 1);
    expect(restoredStats.reachedStopCount, 3);
    expect(
      restoredStats.completedTrailCountForSource(ARTrailSource.virtualWall),
      1,
    );
    expect(restoredUnlocks, hasLength(1));
    expect(restoredUnlocks.single.id, ARTrailAchievementId.wallExplorer);
    expect(restoredUnlocks.single.title, 'Wall Explorer');
    expect(restoredUnlocks.single.unlockedAt, DateTime(2026, 5, 30, 8, 6));

    store.saveCompletedHistory(const <ARTrailProgress>[]);
    store.saveSavedTrails(const <SavedARTrail>[]);
    store.saveLifetimeStats(const ARTrailLifetimeStats.empty());
    store.saveAchievementUnlocks(const <ARTrailAchievementUnlock>[]);
    await Future<void>.delayed(Duration.zero);

    expect(restoredStore.loadCompletedHistory(), isEmpty);
    expect(restoredStore.loadSavedTrails(), isEmpty);
    expect(restoredStore.loadLifetimeStats().hasProgress, isFalse);
    expect(restoredStore.loadAchievementUnlocks(), isEmpty);
  });

  test('progress controller clears invalid single-stop sessions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Single stop',
      memoryIds: const ['anchor_courtyard'],
    );

    container.read(activeARTrailProgressProvider.notifier).start(session);

    expect(container.read(activeARTrailProgressProvider), isNull);
  });

  test('history controller keeps newest completed trails first', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final firstSession = ARTrailSession.fromMemoryIds(
      title: 'First trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
    );
    final secondSession = ARTrailSession.fromMemoryIds(
      title: 'Second trail',
      memoryIds: const ['anchor_private', 'anchor_mural'],
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);

    controller.start(
      firstSession,
      startedAt: DateTime(2026, 5, 29, 9),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 9, 8));
    controller.start(
      secondSession,
      startedAt: DateTime(2026, 5, 29, 10),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 10, 12));

    final history = container.read(completedARTrailHistoryProvider);
    expect(history.map((entry) => entry.session.title), [
      'Second trail',
      'First trail',
    ]);
    expect(history.first.elapsedLabel, '12 min');
    expect(history.last.elapsedLabel, '8 min');
  });

  test('history summary aggregates stops, duration, and fastest trail', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final firstSession = ARTrailSession.fromMemoryIds(
      title: 'First trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.camera,
    );
    final secondSession = ARTrailSession.fromMemoryIds(
      title: 'Second trail',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);

    controller.start(
      firstSession,
      startedAt: DateTime(2026, 5, 29, 9),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 9, 8));
    controller.start(
      secondSession,
      startedAt: DateTime(2026, 5, 29, 10),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 10, 12));

    final summary = container.read(completedARTrailHistorySummaryProvider);

    expect(summary.completedTrailCount, 2);
    expect(summary.completedTrailLabel, '2 completed trails');
    expect(summary.reachedStopCount, 4);
    expect(summary.reachedStopLabel, '4 stops reached');
    expect(summary.totalElapsedLabel, '20 min total');
    expect(
      summary.sourceSummaries.map((source) => source.compactLabel),
      ['Camera 1', 'Gallery 1'],
    );
    expect(summary.sourceBreakdownLabel, 'Camera 1, Gallery 1');
    expect(summary.fastestTrail?.session.title, 'First trail');
    expect(summary.fastestTrailLabel, 'Fastest 8 min');
    expect(summary.latestTrail?.session.title, 'Second trail');
  });

  test('clearing history resets completed summary', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Clearable trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.camera,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);

    controller.start(
      session,
      startedAt: DateTime(2026, 5, 29, 13),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 13, 4));
    container.read(completedARTrailHistoryProvider.notifier).clear();

    final history = container.read(completedARTrailHistoryProvider);
    final summary = container.read(completedARTrailHistorySummaryProvider);

    expect(history, isEmpty);
    expect(summary.hasHistory, isFalse);
    expect(summary.completedTrailCount, 0);
    expect(summary.reachedStopCount, 0);
    expect(summary.sourceSummaries, isEmpty);
    expect(summary.sourceBreakdownLabel, 'No sources yet');
    expect(summary.fastestTrailLabel, 'No timing yet');
  });

  test('removing one history entry preserves the remaining summary', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final firstSession = ARTrailSession.fromMemoryIds(
      title: 'Camera trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.camera,
    );
    final secondSession = ARTrailSession.fromMemoryIds(
      title: 'Gallery trail',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);

    controller.start(
      firstSession,
      startedAt: DateTime(2026, 5, 29, 14),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 14, 5));
    controller.start(
      secondSession,
      startedAt: DateTime(2026, 5, 29, 15),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 15, 6));

    final history = container.read(completedARTrailHistoryProvider);
    final entryToRemove = history.firstWhere(
      (entry) => entry.session.title == 'Camera trail',
    );
    container
        .read(completedARTrailHistoryProvider.notifier)
        .remove(entryToRemove);

    final remainingHistory = container.read(completedARTrailHistoryProvider);
    final summary = container.read(completedARTrailHistorySummaryProvider);

    expect(remainingHistory.map((entry) => entry.session.title), [
      'Gallery trail',
    ]);
    expect(summary.completedTrailLabel, '1 completed trail');
    expect(summary.reachedStopLabel, '2 stops reached');
    expect(summary.sourceBreakdownLabel, 'Gallery 1');
  });

  test('saved trails stay separate from completed history', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Saved route',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.camera,
    );
    final progressController =
        container.read(activeARTrailProgressProvider.notifier);
    final savedController = container.read(savedARTrailsProvider.notifier);

    progressController.start(
      session,
      startedAt: DateTime(2026, 5, 29, 16),
    );
    progressController.finish(finishedAt: DateTime(2026, 5, 29, 16, 7));
    savedController.save(
      session,
      savedAt: DateTime(2026, 5, 29, 16, 8),
    );
    savedController.save(
      session,
      savedAt: DateTime(2026, 5, 29, 16, 9),
    );
    container.read(completedARTrailHistoryProvider.notifier).clear();

    final savedTrails = container.read(savedARTrailsProvider);

    expect(container.read(completedARTrailHistoryProvider), isEmpty);
    expect(savedTrails, hasLength(1));
    expect(savedTrails.single.session.title, 'Saved route');
    expect(savedTrails.single.savedAt, DateTime(2026, 5, 29, 16, 8));
    expect(savedController.isSaved(session), isTrue);

    final toggleResult = savedController.toggle(session);

    expect(toggleResult.isSaved, isFalse);
    expect(toggleResult.unlocks, isEmpty);
    expect(container.read(savedARTrailsProvider), isEmpty);
  });

  test('trail achievements reflect completed and saved routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Camera achievement route',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.camera,
    );
    final progressController =
        container.read(activeARTrailProgressProvider.notifier);
    final savedController = container.read(savedARTrailsProvider.notifier);

    final initialAchievements = {
      for (final achievement in container.read(arTrailAchievementsProvider))
        achievement.id: achievement,
    };

    expect(initialAchievements[ARTrailAchievementId.firstTrail]?.isUnlocked,
        isFalse);
    expect(initialAchievements[ARTrailAchievementId.stopCollector]?.isUnlocked,
        isFalse);
    expect(initialAchievements[ARTrailAchievementId.routeKeeper]?.progressLabel,
        '0/1');

    progressController.start(
      session,
      startedAt: DateTime(2026, 5, 29, 17),
    );
    final finishUnlocks = progressController.finish(
      finishedAt: DateTime(2026, 5, 29, 17, 4),
    );
    final saveUnlocks = savedController.save(
      session,
      savedAt: DateTime(2026, 5, 29, 17, 5),
    );

    final achievements = {
      for (final achievement in container.read(arTrailAchievementsProvider))
        achievement.id: achievement,
    };

    expect(achievements[ARTrailAchievementId.firstTrail]?.isUnlocked, isTrue);
    expect(
        achievements[ARTrailAchievementId.cameraExplorer]?.isUnlocked, isTrue);
    expect(achievements[ARTrailAchievementId.routeKeeper]?.isUnlocked, isTrue);
    expect(
        achievements[ARTrailAchievementId.wallExplorer]?.isUnlocked, isFalse);
    expect(
      achievements[ARTrailAchievementId.wallExplorer]?.statusLabel,
      '1 more wall trail to unlock',
    );
    expect(
      achievements[ARTrailAchievementId.stopCollector]?.isUnlocked,
      isFalse,
    );
    expect(
      achievements[ARTrailAchievementId.stopCollector]?.progressLabel,
      '4/10',
    );
    expect(
      achievements[ARTrailAchievementId.stopCollector]?.statusLabel,
      '6 more stops to unlock',
    );
    expect(
      achievements[ARTrailAchievementId.sourceSampler]?.progressLabel,
      '1/3',
    );
    expect(
      achievements[ARTrailAchievementId.sourceSampler]?.statusLabel,
      '2 more sources to unlock',
    );
    expect(
      container.read(arTrailLifetimeStatsProvider).sourceMixProgressLabel(),
      '1/3 sources completed',
    );
    expect(
      container.read(arTrailLifetimeStatsProvider).sourceMixSuggestionLabel(),
      'Try Nearby and Gallery next',
    );
    expect(
      container.read(arTrailLifetimeStatsProvider).suggestedSources(),
      [ARTrailSource.nearby, ARTrailSource.gallery],
    );
    expect(
      achievements[ARTrailAchievementId.routeKeeper]?.statusLabel,
      'Unlocked',
    );
    expect(
      finishUnlocks.map((unlock) => unlock.id),
      [
        ARTrailAchievementId.firstTrail,
        ARTrailAchievementId.cameraExplorer,
      ],
    );
    expect(
      saveUnlocks.map((unlock) => unlock.id),
      [ARTrailAchievementId.routeKeeper],
    );
    expect(
      container
          .read(arTrailAchievementUnlocksProvider)
          .map((unlock) => unlock.title),
      ['Route Keeper', 'First Trail', 'Camera Explorer'],
    );
    expect(
      formatARTrailAchievementUnlocks(finishUnlocks),
      'Achievements unlocked: First Trail, Camera Explorer',
    );
  });

  test('source sampler unlocks after three trail sources', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(activeARTrailProgressProvider.notifier);
    final firstSession = ARTrailSession.fromMemoryIds(
      title: 'Nearby source trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.nearby,
    );
    final secondSession = ARTrailSession.fromMemoryIds(
      title: 'Gallery source trail',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );
    final thirdSession = ARTrailSession.fromMemoryIds(
      title: 'Wall source trail',
      memoryIds: const ['anchor_mural', 'anchor_rooftop'],
      source: ARTrailSource.virtualWall,
    );

    controller.start(
      firstSession,
      startedAt: DateTime(2026, 5, 29, 19),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 19, 2));
    controller.start(
      secondSession,
      startedAt: DateTime(2026, 5, 29, 19, 5),
    );
    final secondUnlocks =
        controller.finish(finishedAt: DateTime(2026, 5, 29, 19, 7));
    controller.start(
      thirdSession,
      startedAt: DateTime(2026, 5, 29, 19, 10),
    );
    final thirdUnlocks =
        controller.finish(finishedAt: DateTime(2026, 5, 29, 19, 12));

    final lifetimeStats = container.read(arTrailLifetimeStatsProvider);
    final achievements = {
      for (final achievement in container.read(arTrailAchievementsProvider))
        achievement.id: achievement,
    };

    expect(lifetimeStats.completedSourceCount, 3);
    expect(secondUnlocks, isEmpty);
    expect(
      thirdUnlocks.map((unlock) => unlock.id),
      [
        ARTrailAchievementId.wallExplorer,
        ARTrailAchievementId.sourceSampler,
      ],
    );
    expect(achievements[ARTrailAchievementId.wallExplorer]?.isUnlocked, isTrue);
    expect(
        achievements[ARTrailAchievementId.sourceSampler]?.isUnlocked, isTrue);
    expect(
      achievements[ARTrailAchievementId.sourceSampler]?.statusLabel,
      'Unlocked',
    );
    expect(lifetimeStats.sourceMixSuggestionLabel(), 'Source variety complete');
  });

  test('clearing history keeps lifetime achievement progress', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Persistent achievement route',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.camera,
    );
    final progressController =
        container.read(activeARTrailProgressProvider.notifier);

    progressController.start(
      session,
      startedAt: DateTime(2026, 5, 29, 18),
    );
    progressController.finish(finishedAt: DateTime(2026, 5, 29, 18, 6));
    container.read(completedARTrailHistoryProvider.notifier).clear();

    final lifetimeStats = container.read(arTrailLifetimeStatsProvider);
    final achievements = {
      for (final achievement in container.read(arTrailAchievementsProvider))
        achievement.id: achievement,
    };

    expect(container.read(completedARTrailHistoryProvider), isEmpty);
    expect(
      container.read(completedARTrailHistorySummaryProvider).hasHistory,
      isFalse,
    );
    expect(lifetimeStats.completedTrailCount, 1);
    expect(lifetimeStats.reachedStopCount, 4);
    expect(lifetimeStats.completedTrailCountForSource(ARTrailSource.camera), 1);
    expect(achievements[ARTrailAchievementId.firstTrail]?.isUnlocked, isTrue);
    expect(
        achievements[ARTrailAchievementId.cameraExplorer]?.isUnlocked, isTrue);
    expect(
      achievements[ARTrailAchievementId.stopCollector]?.progressLabel,
      '4/10',
    );
  });

  test('starting a completed route again creates a fresh active trail', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Replay trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);

    controller.start(
      session,
      startedAt: DateTime(2026, 5, 29, 11),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 29, 11, 5));
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 29, 12),
    );

    final activeProgress = container.read(activeARTrailProgressProvider);
    final history = container.read(completedARTrailHistoryProvider);

    expect(activeProgress, isNotNull);
    expect(activeProgress!.isFinished, isFalse);
    expect(activeProgress.currentMemoryId, 'anchor_courtyard');
    expect(activeProgress.completedMemoryIds, {'anchor_courtyard'});
    expect(activeProgress.startedAt, DateTime(2026, 5, 29, 12));
    expect(history, hasLength(1));
    expect(history.single.session.title, 'Replay trail');
  });
}
