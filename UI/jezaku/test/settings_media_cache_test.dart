import 'dart:io';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle_cache.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/screens/settings_screen.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/settings/widgets/ar_model_cache_settings_tile.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

void main() {
  testWidgets('settings storage tile clears repository-backed media cache',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).clearCachedMedia();
    final repository = container.read(anchorMediaRepositoryProvider);
    repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final clearCacheButton = find.byKey(
      const ValueKey('clear_cached_media_button'),
    );
    await tester.scrollUntilVisible(
      clearCacheButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('3 B cached media'), findsOneWidget);
    expect(tester.widget<TextButton>(clearCacheButton).onPressed, isNotNull);

    await tester.tap(clearCacheButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Cache is empty'), findsOneWidget);
    expect(repository.allMedia, isEmpty);
    expect(tester.widget<TextButton>(clearCacheButton).onPressed, isNull);
  });

  testWidgets('settings storage tile cleans only unused media cache',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).clearCachedMedia();
    final repository = container.read(anchorMediaRepositoryProvider);
    final referenced = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
    );
    final orphaned = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[5, 6, 7]),
      ),
    );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Referenced media cache',
          radiusMeters: 8,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 12),
          mediaAttachment: AnchorMediaAttachment(
            type: AnchorMediaType.arSnapshot,
            mediaId: referenced.mediaId,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final cleanUnusedButton = find.byKey(
      const ValueKey('clean_unused_media_button'),
    );
    await tester.scrollUntilVisible(
      cleanUnusedButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('7 B cached media'), findsOneWidget);
    expect(find.text('1 unused media item - 3 B'), findsOneWidget);

    await tester.tap(cleanUnusedButton);
    await tester.pumpAndSettle();

    expect(find.text('Unused media cleaned.'), findsOneWidget);
    expect(repository.mediaById(orphaned.mediaId!), isNull);
    expect(repository.mediaById(referenced.mediaId!), isNotNull);
    expect(find.text('4 B cached media'), findsOneWidget);
    expect(find.byKey(const ValueKey('unused_media_cache_tile')), findsNothing);
  });

  testWidgets('settings storage tile cleans stale media uploads',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).clearCachedMedia();
    final liveMemory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Live upload cache',
              radiusMeters: 8,
              isPrivate: false,
              capturedAt: DateTime(2026, 5, 30, 12),
              mediaAttachment: const AnchorMediaAttachment(
                type: AnchorMediaType.arRecording,
                mediaId: 'live_media_upload',
                duration: Duration(milliseconds: 1200),
                frameCount: 36,
              ),
            );
    final staleMemory = _staleUploadMemory();
    final uploadQueue = container.read(anchorMediaUploadQueueProvider.notifier);
    uploadQueue.queueMedia(liveMemory);
    uploadQueue.queueMedia(staleMemory);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final cleanStaleButton = find.byKey(
      const ValueKey('clean_stale_media_uploads_button'),
    );
    await tester.scrollUntilVisible(
      cleanStaleButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1 stale media upload'), findsOneWidget);

    await tester.tap(cleanStaleButton);
    await tester.pumpAndSettle();

    expect(find.text('Stale media uploads cleaned.'), findsOneWidget);
    expect(
      container.read(anchorMediaUploadQueueProvider).containsKey(
            'live_media_upload',
          ),
      isTrue,
    );
    expect(
      container.read(anchorMediaUploadQueueProvider).containsKey(
            'stale_media_upload',
          ),
      isFalse,
    );
    expect(find.byKey(const ValueKey('stale_media_upload_tile')), findsNothing);
  });

  testWidgets('AR model cache settings tile shows activity and details',
      (tester) async {
    late final Directory tempDir;
    late final File modelSource;
    late final ARModelAssetCacheStats stats;
    late final List<ARModelAssetCacheEntry> entries;
    late final ARModelAssetCacheIntegrityReport integrityReport;

    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'jejaku_settings_model_cache_test_',
      );
      final cacheDir = Directory('${tempDir.path}/model_cache');
      modelSource = File('${tempDir.path}/settings_marker.obj');
      await modelSource.writeAsString('o SettingsMarker\nv 0 0 0\n');
      final cache = ARModelAssetCache(
        cacheDirectory: cacheDir,
        now: () => DateTime(2026, 6, 5, 9, 30),
      );
      await cache.resolve(
        ARModelAsset.fromPath(
          modelSource.path,
          source: ARModelAssetSource.file,
        ),
      );
      await File('${cacheDir.path}/missing_manifest.obj').writeAsString(
        'o MissingManifest\nv 0 0 0\n',
      );
      stats = await cache.inspect();
      entries = await cache.inspectEntries();
      integrityReport = await cache.inspectIntegrity();
    });
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    String? copiedModelCache;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedModelCache = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ARModelCacheSettingsTile(
            stats: AsyncValue.data(stats),
            entries: AsyncValue.data(entries),
            integrity: AsyncValue.data(integrityReport),
          ),
        ),
      ),
    );
    await tester.pump();

    final modelCacheTile = find.byKey(
      const ValueKey('ar_model_cache_tile'),
    );

    expect(find.text('3D model cache'), findsOneWidget);
    expect(find.textContaining('2 cached 3D models'), findsOneWidget);
    expect(
      find.textContaining('Model cache has 1 integrity issue'),
      findsOneWidget,
    );
    expect(find.textContaining('last used'), findsOneWidget);

    await tester.tap(modelCacheTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Cached models'), findsOneWidget);
    expect(find.text('Cached bytes'), findsOneWidget);
    expect(find.text('Manifests'), findsOneWidget);
    expect(find.text('Integrity'), findsOneWidget);
    expect(find.text('Model cache has 1 integrity issue'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('settings_marker.obj'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('settings_marker.obj'), findsOneWidget);
    expect(find.text('missing_manifest.obj'), findsOneWidget);
    expect(find.textContaining('OBJ'), findsOneWidget);
    expect(find.textContaining('MODEL - missing manifest'), findsOneWidget);

    final copyModelCacheButton = find.byKey(
      const ValueKey('copy_ar_model_cache_button'),
    );
    await tester.scrollUntilVisible(
      copyModelCacheButton,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    await tester.ensureVisible(copyModelCacheButton);
    await tester.pump();
    await tester.tap(copyModelCacheButton);
    await tester.pump();

    expect(copiedModelCache, contains('"schemaVersion": 1'));
    expect(copiedModelCache, contains('"entryCount": 2'));
    expect(copiedModelCache, contains('"sourcePath": "${modelSource.path}"'));
    expect(copiedModelCache, contains('"format": "obj"'));
    expect(copiedModelCache, contains('"cacheKey": "missing_manifest"'));
    expect(copiedModelCache, contains('"hasManifest": false'));
    expect(copiedModelCache, contains('"integrity": {'));
    expect(copiedModelCache, contains('"missingManifest": 1'));
    expect(find.text('3D model cache copied.'), findsOneWidget);
  });

  testWidgets('AR model cache settings tile repairs missing manifests',
      (tester) async {
    var repairCalled = false;
    const stats = ARModelAssetCacheStats(entryCount: 1, byteLength: 4);
    final entries = <ARModelAssetCacheEntry>[
      ARModelAssetCacheEntry(
        cacheKey: 'unindexed_marker',
        path: '/tmp/unindexed_marker.obj',
        manifestPath: '/tmp/unindexed_marker.manifest.json',
        byteLength: 4,
        modifiedAt: DateTime.utc(2026, 6, 5, 8, 30),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ARModelCacheSettingsTile(
            stats: const AsyncValue.data(stats),
            entries: AsyncValue.data(entries),
            onRepairManifests: () async {
              repairCalled = true;
              return const ARModelAssetCacheRepairResult(
                beforeStats: stats,
                afterStats: stats,
                repairedManifestPaths: <String>[
                  '/tmp/unindexed_marker.manifest.json',
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ar_model_cache_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Manifests'), findsOneWidget);
    expect(find.text('1 missing manifest'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('repair_ar_model_cache_manifests_button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repairCalled, isTrue);
    expect(find.text('Repaired 1 model cache manifest'), findsOneWidget);
  });

  testWidgets('AR model cache settings tile repairs integrity issues',
      (tester) async {
    var repairCalled = false;
    const stats = ARModelAssetCacheStats(entryCount: 1, byteLength: 7);
    final manifest = ARModelAssetCacheEntryManifest(
      cacheKey: 'tampered_marker',
      sourcePath: '/tmp/tampered_marker.obj',
      source: ARModelAssetSource.file.name,
      format: ARModelFormat.obj.name,
      resolvedPath: '/tmp/tampered_marker.obj',
      resolvedSource: ARModelAssetSource.file.name,
      byteLength: 99,
      contentFingerprint: 'stale_fingerprint',
      createdAt: DateTime.utc(2026, 6, 5, 8),
      lastUsedAt: DateTime.utc(2026, 6, 5, 8, 30),
    );
    final entries = <ARModelAssetCacheEntry>[
      ARModelAssetCacheEntry(
        cacheKey: 'tampered_marker',
        path: '/tmp/tampered_marker.obj',
        manifestPath: '/tmp/tampered_marker.manifest.json',
        byteLength: 7,
        modifiedAt: DateTime.utc(2026, 6, 5, 8, 30),
        manifest: manifest,
      ),
    ];
    const beforeReport = ARModelAssetCacheIntegrityReport(
      stats: stats,
      issues: <ARModelAssetCacheIntegrityIssue>[
        ARModelAssetCacheIntegrityIssue(
          code: ARModelAssetCacheIntegrityIssueCode.byteLengthMismatch,
          cacheKey: 'tampered_marker',
          path: '/tmp/tampered_marker.obj',
          manifestPath: '/tmp/tampered_marker.manifest.json',
          expected: 99,
          actual: 7,
          label: 'Cached model byte length differs from its manifest.',
        ),
      ],
    );
    const afterReport = ARModelAssetCacheIntegrityReport(
      stats: stats,
      issues: <ARModelAssetCacheIntegrityIssue>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ARModelCacheSettingsTile(
            stats: const AsyncValue.data(stats),
            entries: AsyncValue.data(entries),
            integrity: const AsyncValue.data(beforeReport),
            onRepairIntegrity: () async {
              repairCalled = true;
              return const ARModelAssetCacheIntegrityRepairResult(
                beforeReport: beforeReport,
                afterReport: afterReport,
                repairedManifestPaths: <String>[
                  '/tmp/tampered_marker.manifest.json',
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ar_model_cache_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Integrity'), findsOneWidget);
    expect(find.text('Model cache has 1 integrity issue'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('repair_ar_model_cache_integrity_button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repairCalled, isTrue);
    expect(find.text('Repaired 1 model cache manifest'), findsOneWidget);
  });

  testWidgets('settings shows and clears AR diagnostics cache', (tester) async {
    final store = InMemoryARCaptureDiagnosticsCacheStore(
      now: () => DateTime.utc(2026, 6, 2, 12),
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 8);
    cache.put(
      ARCaptureDiagnostics(
        capturedAt: DateTime.utc(2026, 6, 2, 9, 15),
        source: 'settings_cache_test',
        sessionId: 'session_settings',
        sessionStartedAt: DateTime.utc(2026, 6, 2, 9, 14),
        hudStatusLabel: '2 native anchors',
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
      ),
    );
    store.saveCache(cache);
    String? copiedDiagnostics;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedDiagnostics = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final container = ProviderContainer(
      overrides: [
        arCaptureDiagnosticsCacheStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final arCacheTile = find.byKey(
      const ValueKey('ar_diagnostics_cache_tile'),
    );
    await tester.scrollUntilVisible(
      arCacheTile,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('AR diagnostics cache'), findsOneWidget);
    expect(
      find.text('1 cached capture - AR diagnostics: 2 native anchors'),
      findsOneWidget,
    );

    await tester.tap(arCacheTile);
    await tester.pumpAndSettle();

    expect(find.text('Syncable captures'), findsOneWidget);
    expect(find.text('Timeline events'), findsOneWidget);
    expect(find.text('Timeline status'), findsOneWidget);
    expect(find.text('1 AR warning'), findsWidgets);
    expect(find.text('Timeline latest'), findsOneWidget);
    expect(find.text('Timeline warnings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Timeline warning'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Timeline warning'), findsOneWidget);
    expect(
      find.text(
        'Improve light: Move to a brighter area or add light before placing anchors.',
      ),
      findsOneWidget,
    );
    expect(find.text('settings_cache_test'), findsOneWidget);
    expect(find.text('session_settings'), findsOneWidget);
    final timelineSearchField = find.byKey(
      const ValueKey('ar_diagnostics_timeline_search_field'),
    );
    await tester.scrollUntilVisible(
      timelineSearchField,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(timelineSearchField, 'improve light');
    await tester.pumpAndSettle();

    expect(find.text('Timeline matches'), findsOneWidget);
    expect(find.text('Match status'), findsOneWidget);
    expect(find.text('Match warnings'), findsOneWidget);
    expect(find.text('Match types'), findsOneWidget);
    expect(find.text('Capture diagnostics (1)'), findsWidgets);
    expect(find.text('Match severities'), findsOneWidget);
    expect(find.text('Warning (1)'), findsWidgets);
    expect(find.text('1 matching AR warning'), findsWidgets);
    final captureFacetChip = find.byKey(
      const ValueKey('ar_diagnostics_facet_type_captureDiagnostics'),
    );
    expect(captureFacetChip, findsOneWidget);
    await tester.tap(captureFacetChip);
    await tester.pumpAndSettle();
    expect(find.text('Active facet'), findsOneWidget);
    expect(tester.widget<FilterChip>(captureFacetChip).selected, isTrue);
    await tester.tap(captureFacetChip);
    await tester.pumpAndSettle();
    expect(find.text('Active facet'), findsNothing);
    expect(tester.widget<FilterChip>(captureFacetChip).selected, isFalse);

    await tester.enterText(timelineSearchField, 'session started');
    await tester.pumpAndSettle();

    expect(find.text('Session lifecycle (1)'), findsWidgets);
    expect(
      find.text('Session lifecycle: Session started (Good)'),
      findsOneWidget,
    );

    await tester.enterText(timelineSearchField, 'missing camera');
    await tester.pumpAndSettle();

    expect(find.text('No timeline events match'), findsOneWidget);

    final copyDiagnosticsButton = find.byKey(
      const ValueKey('copy_ar_diagnostics_cache_button'),
    );
    await tester.scrollUntilVisible(
      copyDiagnosticsButton,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(copyDiagnosticsButton);
    await tester.pumpAndSettle();

    expect(copiedDiagnostics, contains('"source": "settings_cache_test"'));
    expect(copiedDiagnostics, contains('"hudStatusLabel": "2 native anchors"'));
    expect(copiedDiagnostics, contains('"sessionLifecycleEvent"'));
    expect(copiedDiagnostics, contains('"kind": "sessionStarted"'));
    expect(copiedDiagnostics, contains('"queryResult"'));
    expect(copiedDiagnostics, contains('"cacheStatusLabel"'));
    expect(find.text('AR diagnostics cache copied.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('sheet_clear_ar_diagnostics_cache_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('AR diagnostics cache cleared.'), findsOneWidget);
    expect(store.loadCache().isEmpty, isTrue);
    expect(find.text('No AR diagnostics cached'), findsOneWidget);
  });

  testWidgets('settings shows and clears AR diagnostics bundle cache',
      (tester) async {
    final store = InMemoryARSceneDiagnosticsExportBundleCacheStore(
      maxAge: null,
    );
    final cache = ARSceneDiagnosticsExportBundleCache(capacity: 8)
      ..put(
        _diagnosticsBundle(
          sessionId: 'session_bundle',
          exportedAt: DateTime.utc(2026, 6, 2, 9, 33),
        ),
      );
    store.saveCache(cache);
    String? copiedBundleCache;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedBundleCache = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final container = ProviderContainer(
      overrides: [
        arSceneDiagnosticsExportBundleCacheStoreProvider.overrideWith(
          (ref) => store,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final bundleCacheTile = find.byKey(
      const ValueKey('ar_diagnostics_bundle_cache_tile'),
    );
    await tester.scrollUntilVisible(
      bundleCacheTile,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('AR diagnostics bundles'), findsOneWidget);
    expect(
      find.text(
        '1 cached bundle - 2 native anchors, '
        'ARCore: AR camera frame unavailable',
      ),
      findsOneWidget,
    );

    await tester.tap(bundleCacheTile);
    await tester.pumpAndSettle();

    expect(find.text('Cached bundles'), findsOneWidget);
    expect(find.text('Latest summary'), findsOneWidget);
    expect(
      find.text(
        '2 native anchors, ARCore: AR camera frame unavailable',
      ),
      findsWidgets,
    );
    expect(find.text('Latest export'), findsOneWidget);
    expect(find.text('Latest session'), findsOneWidget);
    expect(find.text('session_bundle'), findsOneWidget);
    expect(find.text('Latest report'), findsOneWidget);
    expect(find.text('Latest runtime'), findsOneWidget);
    expect(find.text('ARCore: AR camera frame unavailable'), findsWidgets);
    expect(find.text('Runtime detail'), findsOneWidget);
    expect(
      find.text(
        'The backend session is running but has not received a camera frame.',
      ),
      findsOneWidget,
    );
    expect(find.text('Runtime action'), findsOneWidget);
    expect(
      find.text(
        'Keep the camera view unobstructed, move the device slightly, and wait '
        'for the first AR frame.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Latest trend'),
      findsOneWidget,
      reason: 'DIAGTEXTS ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '').where((t) => t.isNotEmpty).join(' | ')}',
    );
    expect(find.text('1 new AR warning'), findsOneWidget);
    final recentBundlesHeader = find.text('Recent bundles');
    await tester.scrollUntilVisible(
      recentBundlesHeader,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(recentBundlesHeader, findsOneWidget);

    final copyBundleCacheButton = find.byKey(
      const ValueKey('copy_ar_diagnostics_bundle_cache_button'),
    );
    await tester.scrollUntilVisible(
      copyBundleCacheButton,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(copyBundleCacheButton);
    await tester.pumpAndSettle();

    expect(copiedBundleCache,
        contains('"kind": "jezaku.ar.sceneDiagnosticsBundle"'));
    expect(copiedBundleCache, contains('"sessionId": "session_bundle"'));
    expect(copiedBundleCache, contains('"sessionDiagnosticsReportDiff"'));
    expect(
      copiedBundleCache,
      contains(
        '"runtimeDiagnosticsStatusLabel": '
        '"ARCore: AR camera frame unavailable"',
      ),
    );
    expect(
      copiedBundleCache,
      contains(
        '"runtimeDiagnosticsGuidanceLabel": '
        '"Keep the camera view unobstructed, move the device slightly, and wait '
        'for the first AR frame."',
      ),
    );
    expect(find.text('AR diagnostics bundles copied.'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('sheet_clear_ar_diagnostics_bundle_cache_button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AR diagnostics bundles cleared.'), findsOneWidget);
    expect(store.loadCache().isEmpty, isTrue);
    expect(find.text('No AR diagnostics bundles cached'), findsOneWidget);
  });

  testWidgets('settings storage tile shows repository storage warnings',
      (tester) async {
    final repository = _WarningMediaRepository();
    String? copiedDiagnostics;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedDiagnostics = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final container = ProviderContainer(
      overrides: [
        anchorMediaRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).clearCachedMedia();
    repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[1, 2]),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('clear_cached_media_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text(
        '2 B cached media - 1 orphaned media file, '
        'recovery manifest available',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('repair_media_storage_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Media storage diagnostics'), findsOneWidget);
    expect(find.text('Warning media cache'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Orphaned blobs'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Orphaned blobs'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('media_storage_diagnostics_payload')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('"schemaVersion": 1'), findsOneWidget);
    expect(
      find.textContaining('"orphanedBlobFileCount": 1'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('copy_media_storage_diagnostics_button')),
    );
    await tester.pumpAndSettle();

    expect(
      copiedDiagnostics,
      contains('"backendLabel": "Warning media cache"'),
    );
    expect(
      find.text('Media storage diagnostics copied.'),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('repair_media_storage_button')));
    await tester.pumpAndSettle();

    expect(repository.repairCalled, isTrue);
    expect(
      find.text(
        'Media storage repaired: removed 1 orphaned media file, '
        'cleared recovery manifest.',
      ),
      findsOneWidget,
    );
  });
}

ARSceneDiagnosticsExportBundle _diagnosticsBundle({
  required String sessionId,
  required DateTime exportedAt,
}) {
  final healthy = _sessionHealthAssessment(
    sampledAt: DateTime.utc(2026, 6, 2, 9, 30),
    lightEstimateLux: 120,
  );
  final warning = _sessionHealthAssessment(
    sampledAt: DateTime.utc(2026, 6, 2, 9, 31),
    lightEstimateLux: 12,
  );
  final runtimeEvent = ARSessionLifecycleEvent.create(
    kind: ARSessionLifecycleEventKind.custom,
    occurredAt: DateTime.utc(2026, 6, 2, 9, 30, 45),
    source: 'android_runtime',
    sessionId: sessionId,
    summaryLabel: 'AR camera frame unavailable',
    detailLabel:
        'The backend session is running but has not received a camera frame.',
    severity: ARSessionHealthSeverity.warning,
    code: 'runtime_camera_frame_unavailable',
    metadata: const <String, Object?>{
      'backend': 'arcore',
    },
  );
  final previousReport = ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          healthy,
          source: 'health_monitor',
          sessionId: sessionId,
        ),
        ARDiagnosticsTimelineEvent.fromSessionLifecycle(runtimeEvent),
      ],
    ),
    generatedAt: DateTime.utc(2026, 6, 2, 9, 30, 30),
  );
  final report = ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          healthy,
          source: 'health_monitor',
          sessionId: sessionId,
        ),
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          warning,
          source: 'health_monitor',
          sessionId: sessionId,
        ),
        ARDiagnosticsTimelineEvent.fromSessionLifecycle(runtimeEvent),
      ],
    ),
    generatedAt: DateTime.utc(2026, 6, 2, 9, 31, 5),
  );

  return ARSceneDiagnosticsExportBundle.fromDiagnostics(
    sceneDiagnostics: ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: DateTime.utc(2026, 6, 2, 9, 29),
      lastSyncedAt: DateTime.utc(2026, 6, 2, 9, 31),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 2,
      sessionHealthAssessment: warning,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [previousReport, report],
    ),
    latestCaptureDiagnostics: ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 32),
      source: 'settings_bundle_test',
      sessionId: sessionId,
      hudStatusLabel: 'Scene captured',
      activeMemoryCount: 2,
      extra: <String, Object?>{
        'sessionDiagnosticsReport': report.toSyncableMap(),
      },
    ),
    exportedAt: exportedAt,
  );
}

ARSessionHealthAssessment _sessionHealthAssessment({
  required DateTime sampledAt,
  required double lightEstimateLux,
}) {
  return ARSessionHealthPolicy.placementReadiness.assess(
    ARSessionHealthSnapshot(
      sampledAt: sampledAt,
      lastCameraFrameAt: sampledAt,
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: ARTrackingFailureReason.none,
      planeCount: 1,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 0,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 1,
      lightEstimateLux: lightEstimateLux,
      lastLightEstimateAt: sampledAt,
    ),
  );
}

class _WarningMediaRepository extends InMemoryAnchorMediaRepository {
  var repairCalled = false;
  var _hasWarnings = true;

  @override
  AnchorMediaStorageReport inspectStorage() {
    if (!_hasWarnings) {
      return super.inspectStorage();
    }

    return AnchorMediaStorageReport(
      backendLabel: 'Warning media cache',
      cachedMediaCount: cachedMediaCount,
      cachedByteLength: cachedByteLength,
      trackedBlobFileCount: 1,
      orphanedBlobFileCount: 1,
      hasPersistentManifest: true,
      hasBackupManifest: false,
      hasTemporaryManifest: false,
      hasInvalidManifest: true,
    );
  }

  @override
  AnchorMediaStorageRepairResult repairStorage() {
    repairCalled = true;
    _hasWarnings = false;
    return const AnchorMediaStorageRepairResult(
      removedOrphanedBlobFileCount: 1,
      removedTemporaryManifest: false,
      removedBackupManifest: false,
      removedInvalidManifest: true,
      restoredBackupManifest: false,
      rebuiltManifest: false,
    );
  }
}

AnchorMemory _staleUploadMemory() {
  return const AnchorMemory(
    id: 'stale_upload_memory',
    title: 'Stale upload',
    caption: 'Upload queue fixture.',
    distanceLabel: '5 m',
    capturedAgo: 'Just now',
    locationLabel: '-6.9175, 107.6191',
    latitude: -6.9175,
    longitude: 107.6191,
    reactions: 0,
    captureMetadata: AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    mediaAttachment: AnchorMediaAttachment(
      type: AnchorMediaType.arRecording,
      mediaId: 'stale_media_upload',
      duration: Duration(milliseconds: 1200),
      frameCount: 36,
    ),
  );
}
