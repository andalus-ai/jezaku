import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activeARTrailProgressKey = 'jejaku.active_ar_trail_progress';
const _completedARTrailHistoryKey = 'jejaku.completed_ar_trail_history';
const _savedARTrailsKey = 'jejaku.saved_ar_trails';
const _arTrailLifetimeStatsKey = 'jejaku.ar_trail_lifetime_stats';
const _arTrailAchievementUnlocksKey = 'jejaku.ar_trail_achievement_unlocks';

final arTrailProgressStoreProvider = Provider<ARTrailProgressStore>((ref) {
  return InMemoryARTrailProgressStore();
});

abstract class ARTrailProgressStore {
  ARTrailProgress? loadActiveProgress();

  void saveActiveProgress(ARTrailProgress? progress);

  void clearActiveProgress();

  List<ARTrailProgress> loadCompletedHistory();

  void saveCompletedHistory(List<ARTrailProgress> history);

  List<SavedARTrail> loadSavedTrails();

  void saveSavedTrails(List<SavedARTrail> trails);

  ARTrailLifetimeStats loadLifetimeStats();

  void saveLifetimeStats(ARTrailLifetimeStats stats);

  List<ARTrailAchievementUnlock> loadAchievementUnlocks();

  void saveAchievementUnlocks(List<ARTrailAchievementUnlock> unlocks);
}

class InMemoryARTrailProgressStore implements ARTrailProgressStore {
  ARTrailProgress? _activeProgress;
  List<ARTrailProgress> _completedHistory = const <ARTrailProgress>[];
  List<SavedARTrail> _savedTrails = const <SavedARTrail>[];
  ARTrailLifetimeStats _lifetimeStats = const ARTrailLifetimeStats.empty();
  List<ARTrailAchievementUnlock> _achievementUnlocks =
      const <ARTrailAchievementUnlock>[];

  /// Keeps unreadable data under `<key>.corrupt` before removing the original,
  /// so a bad write does not silently erase a player's trail history.
  void _quarantine(String key, String rawValue) {
    unawaited(_preferences.setString('$key.corrupt', rawValue));
    unawaited(_preferences.remove(key));
  }

  @override
  ARTrailProgress? loadActiveProgress() {
    return _activeProgress;
  }

  @override
  void saveActiveProgress(ARTrailProgress? progress) {
    _activeProgress = progress;
  }

  @override
  void clearActiveProgress() {
    _activeProgress = null;
  }

  @override
  List<ARTrailProgress> loadCompletedHistory() {
    return List.unmodifiable(_completedHistory);
  }

  @override
  void saveCompletedHistory(List<ARTrailProgress> history) {
    _completedHistory = List.unmodifiable(
      history.where((progress) => progress.isFinished),
    );
  }

  @override
  List<SavedARTrail> loadSavedTrails() {
    return List.unmodifiable(_savedTrails);
  }

  @override
  void saveSavedTrails(List<SavedARTrail> trails) {
    _savedTrails = List.unmodifiable(trails);
  }

  @override
  ARTrailLifetimeStats loadLifetimeStats() {
    return _lifetimeStats;
  }

  @override
  void saveLifetimeStats(ARTrailLifetimeStats stats) {
    _lifetimeStats = stats;
  }

  @override
  List<ARTrailAchievementUnlock> loadAchievementUnlocks() {
    return List.unmodifiable(_achievementUnlocks);
  }

  @override
  void saveAchievementUnlocks(List<ARTrailAchievementUnlock> unlocks) {
    _achievementUnlocks = List.unmodifiable(unlocks.take(20));
  }
}

class SharedPreferencesARTrailProgressStore implements ARTrailProgressStore {
  const SharedPreferencesARTrailProgressStore({
    required SharedPreferences preferences,
    String activeProgressKey = _activeARTrailProgressKey,
    String completedHistoryKey = _completedARTrailHistoryKey,
    String savedTrailsKey = _savedARTrailsKey,
    String lifetimeStatsKey = _arTrailLifetimeStatsKey,
    String achievementUnlocksKey = _arTrailAchievementUnlocksKey,
  })  : _preferences = preferences,
        _activeProgressKey = activeProgressKey,
        _completedHistoryKey = completedHistoryKey,
        _savedTrailsKey = savedTrailsKey,
        _lifetimeStatsKey = lifetimeStatsKey,
        _achievementUnlocksKey = achievementUnlocksKey;

  final SharedPreferences _preferences;
  final String _activeProgressKey;
  final String _completedHistoryKey;
  final String _savedTrailsKey;
  final String _lifetimeStatsKey;
  final String _achievementUnlocksKey;

  @override
  ARTrailProgress? loadActiveProgress() {
    final encodedProgress = _preferences.getString(_activeProgressKey);
    if (encodedProgress == null || encodedProgress.trim().isEmpty) {
      return null;
    }

    try {
      final decodedProgress = jsonDecode(encodedProgress);
      if (decodedProgress is! Map) {
        _quarantine(_activeProgressKey, encodedProgress);
        return null;
      }
      final progress = ARTrailProgress.fromJson(
        Map<String, Object?>.from(decodedProgress),
      );
      if (progress == null) {
        _quarantine(_activeProgressKey, encodedProgress);
        return null;
      }
      if (progress.isFinished) {
        clearActiveProgress();
        return null;
      }
      return progress;
    } on Object {
      _quarantine(_activeProgressKey, encodedProgress);
      return null;
    }
  }

  @override
  void saveActiveProgress(ARTrailProgress? progress) {
    if (progress == null || progress.isFinished) {
      clearActiveProgress();
      return;
    }
    unawaited(
      _preferences.setString(
        _activeProgressKey,
        jsonEncode(progress.toJson()),
      ),
    );
  }

  @override
  void clearActiveProgress() {
    unawaited(_preferences.remove(_activeProgressKey));
  }

  @override
  List<ARTrailProgress> loadCompletedHistory() {
    return List.unmodifiable(
      _loadList(
        key: _completedHistoryKey,
        decode: ARTrailProgress.fromJson,
      ).where((progress) => progress.isFinished),
    );
  }

  @override
  void saveCompletedHistory(List<ARTrailProgress> history) {
    _saveList(
      key: _completedHistoryKey,
      values: [
        for (final progress in history)
          if (progress.isFinished) progress,
      ],
      encode: (progress) => progress.toJson(),
    );
  }

  @override
  List<SavedARTrail> loadSavedTrails() {
    return _loadList(
      key: _savedTrailsKey,
      decode: SavedARTrail.fromJson,
    );
  }

  @override
  void saveSavedTrails(List<SavedARTrail> trails) {
    _saveList(
      key: _savedTrailsKey,
      values: trails,
      encode: (trail) => trail.toJson(),
    );
  }

  @override
  ARTrailLifetimeStats loadLifetimeStats() {
    final encodedStats = _preferences.getString(_lifetimeStatsKey);
    if (encodedStats == null || encodedStats.trim().isEmpty) {
      return const ARTrailLifetimeStats.empty();
    }

    try {
      final decodedStats = jsonDecode(encodedStats);
      if (decodedStats is! Map) {
        _quarantine(_lifetimeStatsKey, encodedStats);
        return const ARTrailLifetimeStats.empty();
      }
      return ARTrailLifetimeStats.fromJson(
            Map<String, Object?>.from(decodedStats),
          ) ??
          const ARTrailLifetimeStats.empty();
    } on Object {
      _quarantine(_lifetimeStatsKey, encodedStats);
      return const ARTrailLifetimeStats.empty();
    }
  }

  @override
  void saveLifetimeStats(ARTrailLifetimeStats stats) {
    unawaited(
      _preferences.setString(
        _lifetimeStatsKey,
        jsonEncode(stats.toJson()),
      ),
    );
  }

  @override
  List<ARTrailAchievementUnlock> loadAchievementUnlocks() {
    return _loadList(
      key: _achievementUnlocksKey,
      decode: ARTrailAchievementUnlock.fromJson,
    ).take(20).toList(growable: false);
  }

  @override
  void saveAchievementUnlocks(List<ARTrailAchievementUnlock> unlocks) {
    _saveList(
      key: _achievementUnlocksKey,
      values: unlocks.take(20).toList(growable: false),
      encode: (unlock) => unlock.toJson(),
    );
  }

  List<T> _loadList<T>({
    required String key,
    required T? Function(Map<String, Object?> json) decode,
  }) {
    final encodedList = _preferences.getString(key);
    if (encodedList == null || encodedList.trim().isEmpty) {
      return <T>[];
    }

    try {
      final decodedList = jsonDecode(encodedList);
      if (decodedList is! List) {
        _quarantine(key, encodedList);
        return <T>[];
      }

      return List.unmodifiable([
        for (final item in decodedList)
          if (item is Map)
            if (decode(Map<String, Object?>.from(item)) case final decoded?)
              decoded,
      ]);
    } on Object {
      _quarantine(key, encodedList);
      return <T>[];
    }
  }

  void _saveList<T>({
    required String key,
    required List<T> values,
    required Map<String, Object?> Function(T value) encode,
  }) {
    unawaited(
      _preferences.setString(
        key,
        jsonEncode([
          for (final value in values) encode(value),
        ]),
      ),
    );
  }
}

persistentARTrailProgressStoreOverride({
  required SharedPreferences preferences,
}) {
  return arTrailProgressStoreProvider.overrideWith((ref) {
    return SharedPreferencesARTrailProgressStore(
      preferences: preferences,
    );
  });
}
