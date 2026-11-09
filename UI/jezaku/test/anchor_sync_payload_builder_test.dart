import 'dart:convert';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';

void main() {
  test('sync payload builder exports backend-ready memory envelopes', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final memory = AnchorMemory(
      id: 'captured_payload_1',
      title: 'Payload memory',
      caption: 'A local-first capture.',
      distanceLabel: '100 m radius',
      capturedAgo: 'Just now',
      locationLabel: '-6.9175, 107.6191',
      latitude: -6.9175,
      longitude: 107.6191,
      reactions: 0,
      capturedAt: DateTime.utc(2026, 5, 31, 9, 15),
      syncStatus: AnchorSyncStatus.queued,
      syncReason: AnchorSyncReason.newCapture,
      isPrivate: true,
      allowComments: false,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: 714.2,
        headingDegrees: double.nan,
        pitchDegrees: -2,
        rollDegrees: 0.4,
        gpsAccuracyMeters: 3.2,
        anchorType: 'Hybrid geo/orientation',
        captureSource: 'GPS + compass + gyro',
        correctionEastMeters: 1.5,
        correctionNorthMeters: -0.5,
        correctionUpMeters: 0.3,
        manualCorrectionSavedAt: DateTime.utc(2026, 5, 31, 9, 20),
        localAnchorId: 'local_anchor_1',
        cloudAnchorId: 'cloud_anchor_1',
        cloudAnchorExpiresAt: DateTime.utc(2026, 6, 30),
      ),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        mediaId: 'media_cameraPhoto_0001',
        storagePath: 'jejaku://media/media_cameraPhoto_0001',
        storedAt: DateTime.utc(2026, 5, 31, 9, 16),
        bytes: Uint8List.fromList([1, 2, 3]),
        filePath: '/private/local/path/should-not-sync.jpg',
      ),
    );

    final batch = builder.batchPayload(
      [memory],
      batchType: AnchorSyncBatchType.fullQueue,
      generatedAt: DateTime.utc(2026, 5, 31, 9, 30),
    );

    expect(batch.summaryLabel, '1 item, 1 media payload');
    final json = batch.toJson();
    expect(json['tenantRealm'], 'jezaku');
    expect(json['batchType'], 'full_queue');
    expect(json['generatedAt'], '2026-05-31T09:30:00.000Z');
    expect(json['idempotencyKey'], startsWith('batch_jezaku_full_queue_'));
    expect(
        json['payloadFingerprint'],
        isA<String>().having(
          (value) => value.length,
          'length',
          8,
        ));

    final memories = json['memories'] as List<Object?>;
    final payload = memories.single as Map<String, Object?>;
    expect(payload['operation'], 'create_memory');
    expect(payload['clientMemoryId'], 'captured_payload_1');
    expect(
      payload['clientMutationId'],
      startsWith('memory_captured_payload_1_create_memory_'),
    );
    expect(
        payload['payloadFingerprint'],
        isA<String>().having(
          (value) => value.length,
          'length',
          8,
        ));
    expect(payload['capturedAt'], '2026-05-31T09:15:00.000Z');
    expect(payload['syncReason'], 'newCapture');

    final location = payload['location'] as Map<String, Object?>;
    expect(location['latitude'], -6.9175);
    expect(location['longitude'], 107.6191);
    expect(location['altitudeMeters'], 714.2);
    expect(location['accuracyMeters'], 3.2);

    final metadata = payload['captureMetadata'] as Map<String, Object?>;
    expect(metadata['headingDegrees'], isNull);
    expect(metadata['pitchDegrees'], -2);
    expect(metadata['rollDegrees'], 0.4);
    final correction = metadata['manualCorrection'] as Map<String, Object?>;
    expect(correction['active'], isTrue);
    expect(correction['eastMeters'], 1.5);
    expect(correction['savedAt'], '2026-05-31T09:20:00.000Z');

    final privacy = payload['privacy'] as Map<String, Object?>;
    expect(privacy['isPrivate'], isTrue);
    expect(privacy['allowComments'], isFalse);

    final media = payload['media'] as Map<String, Object?>;
    expect(media['type'], 'cameraPhoto');
    expect(media['mediaId'], 'media_cameraPhoto_0001');
    expect(media['byteLength'], 3);
    expect(media['hasLocalPayload'], isTrue);

    final encoded = jsonEncode(json);
    expect(encoded, isNot(contains('/private/local/path')));
    expect(encoded, isNot(contains('[1,2,3]')));

    final retryBatch = builder.batchPayload(
      [memory],
      batchType: AnchorSyncBatchType.fullQueue,
      generatedAt: DateTime.utc(2026, 5, 31, 9, 45),
    );
    expect(retryBatch.idempotencyKey, batch.idempotencyKey);

    final changedMemory = memory.copyWith(caption: 'A corrected caption.');
    expect(
      builder.memoryPayload(changedMemory).payloadFingerprint,
      isNot(builder.memoryPayload(memory).payloadFingerprint),
    );
  });

  test('metadata updates use metadata operation and omit absent media', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final memory = _memory().copyWith(
      syncReason: AnchorSyncReason.metadataUpdate,
      mediaAttachment: null,
    );

    final payload = builder.memoryPayload(memory);

    expect(payload.operation, 'metadata_update');
    expect(payload.operationLabel, 'Metadata payload');
    expect(payload.media, isNull);
    expect(payload.visibilityLabel, 'Public payload');
  });

  test('sync media payload includes AR recording profile metadata', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final qualityReviewedAt = DateTime.utc(2026, 5, 31, 9, 25);
    final arDiagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 5, 31, 9, 24),
      source: 'sync_payload_test',
      hudStatusLabel: '1 native anchor',
      sessionReadinessLabel: 'Ready for placement',
      unsupportedSessionFeatureKeys: const <String>['cloudAnchors'],
    ).toMap();
    final memory = _memory().copyWith(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        mediaId: 'media_arRecording_0001',
        storagePath: 'jejaku://media/media_arRecording_0001',
        filePath: '/tmp/local_clip.mp4',
        duration: const Duration(milliseconds: 1200),
        frameCount: 36,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 2048,
        recordingQualityReviewedAt: qualityReviewedAt,
        arDiagnostics: arDiagnostics,
      ),
    );

    final media = builder.memoryPayload(memory).media!;
    final json = media.toJson();

    expect(json['type'], 'arRecording');
    expect(json['durationMs'], 1200);
    expect(json['frameCount'], 36);
    expect(json['targetFps'], 30);
    expect(json['videoBitrateKbps'], 6000);
    expect(json['outputFormat'], 'mp4');
    expect(json['includesUIOverlay'], isTrue);
    expect(json['includesAudio'], isFalse);
    expect(json['fileSizeBytes'], 2048);
    expect(
      json['recordingQualityReviewedAt'],
      '2026-05-31T09:25:00.000Z',
    );
    final syncedDiagnostics = json['arDiagnostics'] as Map<String, Object?>?;
    expect(syncedDiagnostics?['schemaVersion'],
        ARCaptureDiagnostics.currentSchemaVersion);
    expect(syncedDiagnostics?['source'], 'sync_payload_test');
    expect(syncedDiagnostics?['hudStatusLabel'], '1 native anchor');
    expect(syncedDiagnostics?['sessionReadinessLabel'], 'Ready for placement');
    expect(
      syncedDiagnostics?['unsupportedSessionFeatureKeys'],
      ['cloudAnchors'],
    );
  });

  test('sync media payload includes 3D model asset metadata', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final asset = ARModelAsset.fromPath(
      'assets/models/sync_marker.obj',
      fallbackSizeMeters: const ARVector3(0.5, 0.4, 0.5),
    );
    final memory = _memory().copyWith(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        mediaId: 'model_sync_marker',
        storagePath: 'jezaku://models/sync_marker',
        modelAsset: asset,
      ),
    );

    final media = builder.memoryPayload(memory).media!;
    final json = media.toJson();
    final modelAsset = json['modelAsset'] as Map<String, Object?>;
    final modelValidation = json['modelValidation'] as Map<String, Object?>;
    final modelRenderProfile =
        json['modelRenderProfile'] as Map<String, Object?>;
    final fallbackSize =
        modelAsset['fallbackSizeMeters'] as Map<String, Object?>;

    expect(json['type'], 'arModel');
    expect(json['mediaId'], 'model_sync_marker');
    expect(json['storagePath'], 'jezaku://models/sync_marker');
    expect(json['hasLocalPayload'], isFalse);
    expect(json['requiresUpload'], isFalse);
    expect(modelAsset['path'], 'assets/models/sync_marker.obj');
    expect(modelAsset['format'], 'obj');
    expect(modelAsset['source'], 'flutterAsset');
    expect(fallbackSize['x'], 0.5);
    expect(fallbackSize['y'], 0.4);
    expect(fallbackSize['z'], 0.5);
    expect(modelValidation['target'], 'crossPlatform');
    expect(modelValidation['isValid'], isTrue);
    expect(modelValidation['hasWarnings'], isFalse);
    expect(modelValidation['summaryLabel'], 'Model asset ready');
    expect(modelValidation['issueLabels'], isEmpty);
    expect(modelValidation['usesAndroidPrimitiveFallback'], isFalse);
    expect(
      modelRenderProfile['summaryLabel'],
      'Native mesh on Android and iOS',
    );
    expect(modelRenderProfile['usesAnyPrimitiveFallback'], isFalse);
    expect(modelRenderProfile['requiresPreparation'], isFalse);
    expect(
      modelRenderProfile['notes'],
      isEmpty,
    );
    final platforms = modelRenderProfile['platforms'] as List<Object?>;
    final androidPlatform = platforms.first as Map<String, Object?>;
    expect(androidPlatform['platform'], 'android');
    expect(androidPlatform['mode'], 'nativeMesh');
    expect(androidPlatform['label'], 'Android native OBJ mesh');

    final batch = builder.batchPayload(
      [memory],
      batchType: AnchorSyncBatchType.fullQueue,
    );
    expect(batch.mediaCount, 0);
    expect(batch.summaryLabel, '1 item, 0 media payloads');
  });

  test('sync media payload marks local 3D model files uploadable', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final memory = _memory().copyWith(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: ARModelAsset.fromPath(
          '/tmp/local_sync_marker.glb',
          source: ARModelAssetSource.file,
        ),
      ),
    );

    final media = builder.memoryPayload(memory).media!;
    final json = media.toJson();

    expect(json['type'], 'arModel');
    expect(json['hasLocalPayload'], isTrue);
    expect(json['requiresUpload'], isTrue);
    expect(media.requiresUpload, isTrue);

    final modelValidation = json['modelValidation'] as Map<String, Object?>;
    final modelRenderProfile =
        json['modelRenderProfile'] as Map<String, Object?>;
    expect(modelValidation['isValid'], isTrue);
    expect(
      modelValidation['summaryLabel'],
      'Model asset ready with 3 warnings',
    );
    expect(
      modelValidation['issueLabels'],
      contains(
        'Android imports OBJ meshes directly; this format uses primitive fallback rendering.',
      ),
    );
    expect(modelValidation['usesAndroidPrimitiveFallback'], isTrue);
    expect(
      modelRenderProfile['summaryLabel'],
      'Android primitive fallback; iOS model conversion recommended',
    );
    expect(modelRenderProfile['usesAnyPrimitiveFallback'], isTrue);
    expect(modelRenderProfile['requiresPreparation'], isTrue);
    expect(
      modelRenderProfile['notes'],
      contains('Convert to OBJ for Android native mesh rendering.'),
    );
  });

  test('sync media payload exports blocking 3D model validation issues', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final memory = _memory().copyWith(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: ARModelAsset.fromPath(
          'assets/models/broken_marker.obj',
          fallbackSizeMeters: const ARVector3(0, 0.4, 0.5),
        ),
      ),
    );

    final json = builder.memoryPayload(memory).media!.toJson();
    final modelValidation = json['modelValidation'] as Map<String, Object?>;

    expect(modelValidation['isValid'], isFalse);
    expect(modelValidation['hasWarnings'], isFalse);
    expect(
      modelValidation['summaryLabel'],
      'Model asset has 1 blocking issue',
    );
    expect(modelValidation['errorLabels'], [
      'Fallback size must use finite positive dimensions.',
    ]);
    expect(modelValidation['warningLabels'], isEmpty);
  });

  test('sync media payload normalizes or drops AR diagnostics', () {
    final builder = AnchorSyncPayloadBuilder(runtime: _runtime());
    final legacyMemory = _memory().copyWith(
      mediaAttachment: const AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        arDiagnostics: <String, Object?>{
          'capturedAt': '2026-06-02T09:15:00.000Z',
          'hudStatusLabel': 'Scene pending',
          'unsupportedSessionFeatureKeys': <String>['geospatial'],
        },
      ),
    );
    final invalidMemory = _memory().copyWith(
      mediaAttachment: const AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        arDiagnostics: <String, Object?>{
          'hudStatusLabel': 'Missing capture timestamp',
        },
      ),
    );

    final legacyDiagnostics =
        builder.memoryPayload(legacyMemory).media!.arDiagnostics!;
    final invalidDiagnostics =
        builder.memoryPayload(invalidMemory).media!.arDiagnostics;

    expect(
      legacyDiagnostics['schemaVersion'],
      ARCaptureDiagnostics.currentSchemaVersion,
    );
    expect(legacyDiagnostics['source'], 'ar_capture');
    expect(legacyDiagnostics['capturedAt'], '2026-06-02T09:15:00.000Z');
    expect(legacyDiagnostics['unsupportedSessionFeatureKeys'], ['geospatial']);
    expect(invalidDiagnostics, isNull);
  });
}

AnchorMemory _memory() {
  return const AnchorMemory(
    id: 'anchor_metadata',
    title: 'Metadata',
    caption: 'Metadata update.',
    distanceLabel: '30 m radius',
    capturedAgo: 'Just now',
    locationLabel: '-6.9175, 107.6191',
    latitude: -6.9175,
    longitude: 107.6191,
    reactions: 0,
    syncStatus: AnchorSyncStatus.queued,
    captureMetadata: AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
  );
}

LocalFirstSyncRuntime _runtime() {
  return const LocalFirstSyncRuntime(
    offlineMode: false,
    useDummyData: false,
    profileMode: 'default',
    apiBaseUrl: 'http://localhost:7100',
    backendHost: 'localhost:7100',
    tenantRealm: 'jezaku',
  );
}
