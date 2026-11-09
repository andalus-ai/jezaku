import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('shared preferences AR capture diagnostics cache round trips safely',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARCaptureDiagnosticsCacheStore(
      preferences: preferences,
      key: 'test.ar_capture_diagnostics_cache',
      capacity: 2,
      now: () => DateTime.utc(2026, 6, 2, 10),
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 4);
    final first = _diagnostics('first', 1);
    final second = _diagnostics('second', 2);
    final third = _diagnostics('third', 3);
    final unsyncable = ARCaptureDiagnostics.fromMap(
      const <String, Object?>{
        'source': 'ar_capture_cache_test',
        'hudStatusLabel': 'Missing timestamp',
      },
    );

    cache.putAll(<ARCaptureDiagnostics>[first, unsyncable, second, third]);
    store.saveCache(cache);
    await Future<void>.delayed(Duration.zero);

    final persisted = jsonDecode(
      preferences.getString('test.ar_capture_diagnostics_cache')!,
    ) as Map<String, Object?>;
    final persistedEntries = persisted['entries'] as List<Object?>;

    expect(persistedEntries, hasLength(2));

    final restored = store.loadCache();

    expect(restored.capacity, 2);
    expect(restored.values.map((diagnostics) => diagnostics.sessionId), [
      'second',
      'third',
    ]);
    expect(restored.syncableValues, restored.values);

    store.clearCache();
    await Future<void>.delayed(Duration.zero);

    expect(store.loadCache().isEmpty, isTrue);
  });

  test('shared preferences AR capture diagnostics cache drops old bad entries',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARCaptureDiagnosticsCacheStore(
      preferences: preferences,
      key: 'test.ar_capture_diagnostics_cache',
      capacity: 4,
      now: () => DateTime.utc(2026, 6, 2, 10),
    );
    final first = _diagnostics('first', 1);
    final second = _diagnostics('second', 2);
    final unsyncable = ARCaptureDiagnostics.fromMap(
      const <String, Object?>{
        'source': 'ar_capture_cache_test',
        'hudStatusLabel': 'Missing timestamp',
      },
    );

    await preferences.setString(
      'test.ar_capture_diagnostics_cache',
      jsonEncode(<String, Object?>{
        'capacity': 4,
        'entries': <Object?>[
          first.toMap(),
          unsyncable.toMap(),
          'bad entry',
          second.toMap(),
        ],
      }),
    );

    final restored = store.loadCache();

    expect(restored.values, [first, second]);

    await preferences.setString(
      'test.ar_capture_diagnostics_cache',
      'not json',
    );

    expect(store.loadCache().isEmpty, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.getString('test.ar_capture_diagnostics_cache'), isNull);
  });

  test('shared preferences AR capture diagnostics cache prunes stale entries',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARCaptureDiagnosticsCacheStore(
      preferences: preferences,
      key: 'test.ar_capture_diagnostics_cache',
      capacity: 4,
      maxAge: const Duration(days: 7),
      now: () => DateTime.utc(2026, 6, 10, 9),
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 4);
    final stale = _diagnostics('stale', 1, day: 1);
    final fresh = _diagnostics('fresh', 2, day: 9);

    cache.putAll(<ARCaptureDiagnostics>[stale, fresh]);
    store.saveCache(cache);
    await Future<void>.delayed(Duration.zero);

    final persisted = jsonDecode(
      preferences.getString('test.ar_capture_diagnostics_cache')!,
    ) as Map<String, Object?>;
    final persistedEntries = persisted['entries'] as List<Object?>;

    expect(persistedEntries, hasLength(1));
    expect(store.loadCache().values, [fresh]);

    await preferences.setString(
      'test.ar_capture_diagnostics_cache',
      jsonEncode(<String, Object?>{
        'capacity': 4,
        'entries': <Object?>[
          stale.toMap(),
        ],
      }),
    );

    expect(store.loadCache().isEmpty, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.getString('test.ar_capture_diagnostics_cache'), isNull);
  });
}

ARCaptureDiagnostics _diagnostics(
  String sessionId,
  int minute, {
  int day = 2,
}) {
  return ARCaptureDiagnostics(
    capturedAt: DateTime.utc(2026, 6, day, 9, minute),
    source: 'ar_capture_cache_test',
    sessionId: sessionId,
    hudStatusLabel: '$minute native anchors',
  );
}
