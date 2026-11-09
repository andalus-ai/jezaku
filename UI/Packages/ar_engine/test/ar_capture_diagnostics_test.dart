import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture diagnostics round trip with schema and readiness payloads', () {
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 15),
      source: 'jezaku_ar_viewer',
      sessionId: 'session_1',
      sessionStartedAt: DateTime.utc(2026, 6, 2, 9),
      lastSyncedAt: DateTime.utc(2026, 6, 2, 9, 14),
      hudStatusLabel: '2 native anchors',
      detailStatusLabel: '2 active, 1 scene change',
      syncStatusLabel: 'Synced 2026-06-02 09:14 UTC',
      sessionHealthStatusLabel: 'Tracking stable',
      sessionReadinessLabel: 'Ready for placement',
      nativePlacementStatusLabel: 'Native placement ready',
      activeMemoryCount: 2,
      sceneChangeCount: 1,
      unsupportedSessionFeatureKeys: const <String>[
        'geospatial',
        'cloudAnchors',
      ],
      sessionReadiness: const ARSessionReadiness(
        level: ARSessionReadinessLevel.ready,
        label: 'AR ready',
        detailLabel: 'Tracking is stable.',
        canPlaceAnchors: true,
        canCaptureSnapshot: true,
        canRecord: true,
      ),
      nativePlacementReadiness: const ARSessionReadiness(
        level: ARSessionReadinessLevel.ready,
        label: 'Native ready',
        detailLabel: 'Native anchors can be placed.',
        canPlaceAnchors: true,
        canCaptureSnapshot: true,
        canRecord: true,
      ),
      captureCapability: const ARCaptureCapability(
        hasSession: true,
        supportsSnapshotCapture: true,
        supportsRecording: true,
        readiness: ARSessionReadiness(
          level: ARSessionReadinessLevel.limited,
          label: 'Low light',
          detailLabel:
              'Move to a brighter area or add light before placing anchors.',
          canPlaceAnchors: false,
          canCaptureSnapshot: true,
          canRecord: true,
          primaryIssue: ARSessionHealthIssue.lowLight,
        ),
      ),
      extra: const <String, Object?>{
        'appMemoryId': 'memory_1',
        'nested': <String, Object?>{'status': 'cached'},
      },
    );

    final map = diagnostics.toMap();
    final decoded = ARCaptureDiagnostics.fromMap(map);

    expect(map['schemaVersion'], ARCaptureDiagnostics.currentSchemaVersion);
    expect(decoded, diagnostics);
    expect(decoded.isCurrentSchema, isTrue);
    expect(decoded.cacheKey, contains('jezaku_ar_viewer:session_1:'));
    expect(decoded.toMap()['unsupportedSessionFeatureKeys'], [
      'cloudAnchors',
      'geospatial',
    ]);
    expect(decoded.extra['appMemoryId'], 'memory_1');
    expect(decoded.summaryLabel, 'AR diagnostics: 2 native anchors');
    expect(decoded.unsupportedSessionFeatureCount, 2);
    expect(decoded.captureCapability?.canCaptureSnapshot, isTrue);
    expect(decoded.captureCapability?.canStartRecording, isTrue);
    expect(decoded.captureCapabilityLabel, 'AR capture limited');
    expect(decoded.captureReadinessGuidanceLabel, startsWith('Improve light:'));
    expect(
      decoded.unsupportedSessionFeatureCountLabel,
      '2 native features limited',
    );
    expect(decoded.metadataLabels, [
      'AR diagnostics: 2 native anchors',
      'AR capture limited',
      'Improve light: Move to a brighter area or add light before placing anchors.',
      'Ready for placement',
      'Native placement ready',
      'Tracking stable',
      'Synced 2026-06-02 09:14 UTC',
      '2 native features limited',
    ]);
  });

  test('capture diagnostics cache evicts the oldest entries', () {
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 2);
    final first = _diagnostics('first', 1);
    final second = _diagnostics('second', 2);
    final third = _diagnostics('third', 3);

    cache.put(first);
    cache.put(second);
    cache.put(third);

    expect(cache.length, 2);
    expect(cache.containsKey(first.cacheKey), isFalse);
    expect(cache[second.cacheKey], second);
    expect(cache[third.cacheKey], third);

    cache.put(second.copyWith(hudStatusLabel: 'Updated second'));

    expect(cache.values.map((value) => value.hudStatusLabel), [
      '3 native anchors',
      'Updated second',
    ]);
  });

  test('capture diagnostics cache serializes and restores entries', () {
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 3);
    final first = _diagnostics('first', 1);
    final unsyncable = ARCaptureDiagnostics.fromMap(
      const <String, Object?>{
        'source': 'ar_capture',
        'hudStatusLabel': 'Missing timestamp',
      },
    );
    final third = _diagnostics('third', 3).copyWith(
      source: 'jezaku_ar_viewer',
    );

    cache.putAll(<ARCaptureDiagnostics>[first, unsyncable, third]);

    expect(cache.latest, third);
    expect(cache.latestForSession('first'), first);
    expect(cache.latestForSession(null), unsyncable);
    expect(cache.latestForSource('jezaku_ar_viewer'), third);
    expect(cache.syncableValues, [first, third]);

    final persisted = cache.toMap();
    final persistedEntries = persisted['entries'] as List<Object?>;

    expect(persisted['capacity'], 3);
    expect(persistedEntries.length, 3);

    final restored = ARCaptureDiagnosticsMemoryCache.fromMap(persisted);

    expect(restored.capacity, 3);
    expect(restored.values, [first, unsyncable, third]);

    final syncableSnapshot = cache.toSyncableMap();
    final syncableEntries = syncableSnapshot['entries'] as List<Object?>;

    expect(syncableEntries.length, 2);
    expect(
      syncableEntries
          .map((entry) => ARCaptureDiagnostics.fromMap(entry as Map).sessionId),
      ['first', 'third'],
    );

    final restoredLimited = ARCaptureDiagnosticsMemoryCache.fromMap(
      <String, Object?>{
        'capacity': 1,
        'entries': <Object?>[
          first.toMap(),
          unsyncable.toMap(),
          third.toMap(),
          'bad entry',
        ],
      },
    );

    expect(restoredLimited.capacity, 1);
    expect(restoredLimited.values, [third]);
  });

  test('capture diagnostics cache prunes stale entries', () {
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 5);
    final stale = _diagnostics('stale', 1).copyWith(
      capturedAt: DateTime.utc(2026, 5, 30, 9),
    );
    final fresh = _diagnostics('fresh', 2).copyWith(
      capturedAt: DateTime.utc(2026, 6, 2, 8),
    );
    final otherSource = _diagnostics('other', 3).copyWith(
      capturedAt: DateTime.utc(2026, 6, 2, 9),
      source: 'other_source',
    );

    cache.putAll(<ARCaptureDiagnostics>[stale, fresh, otherSource]);

    expect(
      cache.pruneStale(
        now: DateTime.utc(2026, 6, 2, 9),
        maxAge: const Duration(days: 2),
      ),
      1,
    );
    expect(cache.values, [fresh, otherSource]);

    expect(
      cache.pruneOlderThan(DateTime.utc(2026, 6, 2, 8, 30)),
      1,
    );
    expect(cache.values, [otherSource]);

    expect(
      cache.removeWhere((diagnostics) => diagnostics.source == 'other_source'),
      1,
    );
    expect(cache.isEmpty, isTrue);
  });

  test('capture diagnostics tolerate partial cached maps', () {
    final decoded = ARCaptureDiagnostics.fromMap(const <String, Object?>{
      'capturedAt': '2026-06-02T09:15:00.000Z',
      'hudStatusLabel': 'Scene pending',
      'unsupportedSessionFeatureKeys': <String>['geospatial'],
      'futureField': <String, Object?>{'kept': true},
    });

    expect(decoded.schemaVersion, ARCaptureDiagnostics.currentSchemaVersion);
    expect(decoded.hudStatusLabel, 'Scene pending');
    expect(decoded.source, 'ar_capture');
    expect(decoded.extra, {
      'futureField': {'kept': true},
    });
    expect(decoded.isSyncable, isTrue);
    expect(ARCaptureDiagnostics.fromMap(decoded.toMap()), decoded);
  });

  test('capture diagnostics report sync validation issues', () {
    final missingTimestamp = ARCaptureDiagnostics.fromMap(
      const <String, Object?>{
        'source': 'ar_capture',
        'hudStatusLabel': 'Scene pending',
      },
    );
    final unsupportedSchema = ARCaptureDiagnostics(
      schemaVersion: 99,
      capturedAt: DateTime.utc(2026, 6, 2, 9, 15),
      source: '',
    );

    expect(missingTimestamp.isSyncable, isFalse);
    expect(
      missingTimestamp.validationIssueLabels,
      contains('Missing AR capture timestamp'),
    );
    expect(unsupportedSchema.isSyncable, isFalse);
    expect(unsupportedSchema.validationIssueLabels, [
      'Unsupported AR diagnostics schema',
      'Missing AR diagnostics source',
    ]);
    expect(ARCaptureDiagnostics.tryFromMap(null), isNull);
    expect(ARCaptureDiagnostics.tryFromMap('bad'), isNull);
  });

  test('capture diagnostics normalize syncable maps', () {
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 15),
      source: 'jezaku_ar_viewer',
      hudStatusLabel: '3 native anchors',
      unsupportedSessionFeatureKeys: const <String>[
        'geospatial',
        'cloudAnchors',
      ],
    );
    final normalized = ARCaptureDiagnostics.tryNormalizeSyncableMap(
      <String, Object?>{
        ...diagnostics.toMap(),
        'futureField': const <String, Object?>{'kept': true},
      },
    );

    expect(normalized, isNotNull);
    expect(
      normalized?['schemaVersion'],
      ARCaptureDiagnostics.currentSchemaVersion,
    );
    expect(normalized?['source'], 'jezaku_ar_viewer');
    expect(normalized?['capturedAt'], '2026-06-02T09:15:00.000Z');
    expect(normalized?['unsupportedSessionFeatureKeys'], [
      'cloudAnchors',
      'geospatial',
    ]);
    expect(normalized?['futureField'], {'kept': true});

    expect(
      diagnostics.copyWith(schemaVersion: 99).toSyncableMap(),
      isNull,
    );
    expect(
      ARCaptureDiagnostics.tryNormalizeSyncableMap(<String, Object?>{
        'source': 'jezaku_ar_viewer',
      }),
      isNull,
    );
    expect(ARCaptureDiagnostics.tryNormalizeSyncableMap('bad'), isNull);
  });

  test('capture diagnostics tolerate noisy scalar fields', () {
    final decoded = ARCaptureDiagnostics.fromMap(const <String, Object?>{
      'capturedAt': '2026-06-02T09:15:00.000Z',
      'source': 'ar_capture',
      'sessionId': 42,
      'cloudAnchorsEnabled': 'yes',
      'hasNativeSceneFailure': 'true',
      'hasCloudAnchorFailures': 1,
      'nativeSceneFailureMessage': 7,
      'unsupportedSessionFeatureKeys': <String>[
        'cloudAnchors',
        'cloudAnchors',
      ],
    });

    expect(decoded.sessionId, isNull);
    expect(decoded.cloudAnchorsEnabled, isFalse);
    expect(decoded.hasNativeSceneFailure, isFalse);
    expect(decoded.hasCloudAnchorFailures, isFalse);
    expect(decoded.nativeSceneFailureMessage, isNull);
    expect(decoded.unsupportedSessionFeatureCount, 1);
    expect(
      decoded.metadataLabels,
      contains('1 native feature limited'),
    );
  });
}

ARCaptureDiagnostics _diagnostics(String sessionId, int minute) =>
    ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, minute),
      sessionId: sessionId,
      hudStatusLabel: '$minute native anchors',
    );
