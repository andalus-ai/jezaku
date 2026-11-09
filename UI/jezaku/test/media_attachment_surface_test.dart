import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/gallery/screens/gallery_screen.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/screens/home_screen.dart';
import 'package:jejaku/features/home/screens/memory_search_screen.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_list_tile.dart';
import 'package:jejaku/features/home/widgets/anchor_media_detail_sheet.dart';

void main() {
  testWidgets('anchor list tile surfaces media payload type and details',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnchorListTile(
              anchor: _memory(
                mediaAttachment: const AnchorMediaAttachment(
                  type: AnchorMediaType.arRecording,
                  filePath: '/tmp/jejaku_clip.mp4',
                  duration: Duration(milliseconds: 1500),
                  frameCount: 45,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('AR screen recording: 1.5 s - 45 frames'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.video_file_outlined), findsWidgets);
    expect(find.text('/tmp/jejaku_clip.mp4'), findsNothing);
  });

  testWidgets('anchor list tile badges low-quality AR recordings',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnchorListTile(
              anchor: _memory(
                mediaAttachment: const AnchorMediaAttachment(
                  type: AnchorMediaType.arRecording,
                  filePath: '/tmp/slow_jejaku_clip.mp4',
                  duration: Duration(seconds: 1),
                  frameCount: 3,
                  targetFps: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('AR screen recording: 1.0 s - 3 frames'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.byTooltip(
        'AR screen recording: 1.0 s - 3 frames\n'
        'Low captured FPS - Captured 3.0 of 30 fps target',
      ),
      findsOneWidget,
    );
  });

  testWidgets('media detail sheet shows AR recording profile metadata',
      (tester) async {
    final qualityReviewedAt = DateTime.utc(2026, 5, 30, 12, 10);
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/jejaku_clip.mp4',
        duration: const Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 2048,
        recordingQualityReviewedAt: qualityReviewedAt,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnchorMediaDetailSheet(memory: memory),
          ),
        ),
      ),
    );

    expect(find.text('Target FPS'), findsOneWidget);
    expect(find.text('30 fps target'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(
      find.text('Low captured FPS - Captured 3.0 of 30 fps target'),
      findsOneWidget,
    );
    expect(find.text('Quality review'), findsOneWidget);
    expect(find.text('Quality review accepted'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.text('Reviewed 19:10'), findsOneWidget);
    expect(find.text('Captured FPS'), findsOneWidget);
    expect(find.text('3.0 fps captured'), findsOneWidget);
    expect(find.text('Encoding'), findsOneWidget);
    expect(find.text('MP4 - 6.0 Mbps'), findsOneWidget);
    expect(find.text('Visual'), findsOneWidget);
    expect(find.text('AR visual overlay'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Silent'), findsOneWidget);
    expect(find.text('Recording size'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets('media detail sheet shows 3D model asset profile',
      (tester) async {
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: ARModelAsset.fromPath(
          'assets/models/detail_marker.obj',
          package: 'jezaku_models',
          fallbackSizeMeters: const ARVector3(0.5, 0.35, 0.5),
          centerOrigin: false,
          metadata: const <String, Object?>{
            'author': 'Jezaku',
            'purpose': 'detail test',
          },
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnchorMediaDetailSheet(memory: memory),
          ),
        ),
      ),
    );

    expect(find.text('No media upload needed'), findsOneWidget);
    expect(find.text('Media queued - 0 retries'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('3D Object'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('3D Object'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('OBJ model'), findsOneWidget);
    expect(find.text('Source'), findsWidgets);
    expect(find.text('Flutter asset'), findsOneWidget);
    expect(find.text('Asset path'), findsOneWidget);
    expect(find.text('assets/models/detail_marker.obj'), findsOneWidget);
    expect(find.text('Package'), findsOneWidget);
    expect(find.text('jezaku_models'), findsOneWidget);
    expect(find.text('Fallback size'), findsOneWidget);
    expect(find.text('0.50 x 0.35 x 0.50 m'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('Preserve model origin'), findsOneWidget);
    expect(find.text('Sync payload'), findsOneWidget);
    expect(find.text('Model metadata only'), findsOneWidget);
    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Model asset ready'), findsOneWidget);
    expect(find.text('Render profile'), findsOneWidget);
    expect(find.text('Native mesh on Android and iOS'), findsOneWidget);
    expect(find.text('Platform render'), findsNWidgets(2));
    expect(find.text('Android native OBJ mesh'), findsOneWidget);
    expect(find.text('iOS native SceneKit mesh'), findsOneWidget);
    expect(find.text('Model metadata'), findsOneWidget);
    expect(find.text('2 metadata keys: author, purpose'), findsOneWidget);
    expect(
      memory.mediaAttachment?.matchesQuery('model metadata only'),
      isTrue,
    );
    expect(
      memory.mediaAttachment?.matchesQuery('0.50 x 0.35 x 0.50'),
      isTrue,
    );
    expect(
      memory.mediaAttachment?.matchesQuery('preserve model origin'),
      isTrue,
    );
    expect(memory.mediaAttachment?.matchesQuery('model asset ready'), isTrue);
    expect(memory.mediaAttachment?.matchesQuery('native mesh'), isTrue);
    expect(
      memory.mediaAttachment?.matchesQuery('ios native scenekit mesh'),
      isTrue,
    );
    expect(memory.mediaAttachment?.matchesQuery('author'), isTrue);
  });

  testWidgets('media detail sheet shows captured AR diagnostics',
      (tester) async {
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
    final localPose = AnchorLocalPose(
      x: 0.1,
      y: 1.2,
      z: -0.3,
      qx: 0,
      qy: 0,
      qz: 0,
      qw: 1,
      planeId: 'plane_wall_1',
      surfaceType: 'plane',
      distanceMeters: 0.42,
      confidence: 0.82,
      capturedAt: DateTime.utc(2026, 5, 31, 9, 14),
    );
    final arDiagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 5, 31, 9, 15),
      source: 'media_surface_test',
      hudStatusLabel: '2 native anchors',
      sessionReadinessLabel: 'Ready for placement',
      nativePlacementStatusLabel: 'Native placement ready',
      sessionHealthStatusLabel: 'Tracking stable',
      syncStatusLabel: 'Synced 2026-05-31 09:15 UTC',
      unsupportedSessionFeatureKeys: const <String>['cloudAnchors'],
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
      extra: <String, Object?>{
        'localSurfacePose': localPose.toMap(),
        'localSurfacePoseLabel': localPose.surfaceLabel,
      },
    ).toMap();
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        arDiagnostics: arDiagnostics,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AnchorMediaDetailSheet(memory: memory),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('AR Diagnostics'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('AR Diagnostics'), findsOneWidget);
    expect(find.text('AR diagnostics: 2 native anchors'), findsOneWidget);
    expect(find.text('Ready for placement'), findsOneWidget);
    expect(find.text('Native placement ready'), findsOneWidget);
    expect(find.text('Tracking stable'), findsOneWidget);
    expect(find.text('AR capture limited'), findsOneWidget);
    expect(
      find.text(
        'Improve light: Move to a brighter area or add light before placing anchors.',
      ),
      findsOneWidget,
    );
    expect(find.text('Synced 2026-05-31 09:15 UTC'), findsOneWidget);
    expect(find.text('1 native feature limited'), findsOneWidget);
    expect(find.text('Local surface'), findsOneWidget);
    expect(find.text('Wall/plane anchor - 0.42 m'), findsOneWidget);
    expect(find.text('Local pose'), findsOneWidget);
    expect(
      find.text('Tracked plane - Plane plane_wall_1 - Confidence 82%'),
      findsOneWidget,
    );
    expect(memory.mediaAttachment?.matchesQuery('native anchors'), isTrue);
    expect(
        memory.mediaAttachment?.matchesQuery('native feature limited'), isTrue);
    expect(memory.mediaAttachment?.matchesQuery('capture limited'), isTrue);
    expect(memory.mediaAttachment?.matchesQuery('improve light'), isTrue);
    expect(memory.mediaAttachment?.matchesQuery('local surface'), isTrue);
    expect(memory.mediaAttachment?.matchesQuery('plane_wall_1'), isTrue);

    await tester.scrollUntilVisible(
      find.text('Raw payload'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw payload'));
    await tester.pumpAndSettle();

    final rawJson = tester.widget<SelectableText>(
      find.byKey(const ValueKey('anchor_media_ar_diagnostics_payload_json')),
    );
    expect(rawJson.data, contains('"schemaVersion": 1'));
    expect(rawJson.data, contains('"source": "media_surface_test"'));
    expect(rawJson.data, contains('"capturedAt": "2026-05-31T09:15:00.000Z"'));
    expect(rawJson.data, contains('"localSurfacePoseLabel"'));
    expect(rawJson.data, contains('"captureCapability"'));
    expect(rawJson.data, contains('"planeId": "plane_wall_1"'));

    final copyButton = find.byKey(
      const ValueKey('anchor_media_ar_diagnostics_copy_button'),
    );
    await tester.scrollUntilVisible(
      copyButton,
      -220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('AR diagnostics copied'), findsOneWidget);
    final decoded = jsonDecode(copiedDiagnostics!) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], ARCaptureDiagnostics.currentSchemaVersion);
    expect(decoded['source'], 'media_surface_test');
    expect(decoded['hudStatusLabel'], '2 native anchors');
    expect(decoded['sessionReadinessLabel'], 'Ready for placement');
    expect(decoded['unsupportedSessionFeatureKeys'], ['cloudAnchors']);
    expect(
      (decoded['captureCapability'] as Map<String, dynamic>)['readiness'],
      containsPair('primaryIssue', 'lowLight'),
    );
    expect(decoded['localSurfacePoseLabel'], 'Wall/plane anchor - 0.42 m');
    expect(
      (decoded['localSurfacePose'] as Map<String, dynamic>)['planeId'],
      'plane_wall_1',
    );
  });

  testWidgets('anchor list tile resolves repository-backed media preview',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final storedAttachment =
        container.read(anchorMediaRepositoryProvider).storeAttachment(
              AnchorMediaAttachment(
                type: AnchorMediaType.arSnapshot,
                bytes: Uint8List.fromList(_png1x1),
              ),
              storedAt: DateTime(2026, 5, 30, 12),
            );
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
        storagePath: storedAttachment.storagePath,
        storedAt: storedAttachment.storedAt,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AnchorListTile(anchor: memory),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('anchor_media_preview_image_${memory.id}')),
      findsOneWidget,
    );
    expect(find.text('AR snapshot: Captured in AR viewer'), findsOneWidget);
  });

  testWidgets('anchor list tile badges media references with missing cache',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(anchorMediaRepositoryProvider);
    final storedAttachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(_png1x1),
      ),
      storedAt: DateTime(2026, 5, 30, 12),
    );
    repository.clearCachedMedia();
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
        storagePath: storedAttachment.storagePath,
        storedAt: storedAttachment.storedAt,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AnchorListTile(anchor: memory),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('anchor_media_preview_image_${memory.id}')),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey('anchor_media_preview_missing_cache_badge_${memory.id}'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Preview cache missing'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('gallery tiles surface captured media type', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Gallery AR clip',
          radiusMeters: 30,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 12),
          mediaAttachment: const AnchorMediaAttachment(
            type: AnchorMediaType.arRecording,
            filePath: '/tmp/gallery_ar_clip.mp4',
            duration: Duration(seconds: 1),
            frameCount: 3,
            targetFps: 30,
          ),
        );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Plain gallery capture',
          radiusMeters: 28,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 13),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: GalleryScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gallery AR clip'), findsWidgets);
    expect(find.text('AR screen recording'), findsOneWidget);
    expect(find.byIcon(Icons.video_file_outlined), findsWidgets);
    expect(find.text('/tmp/gallery_ar_clip.mp4'), findsNothing);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();

    expect(find.text('3 media memories'), findsOneWidget);
    expect(find.text('Gallery AR clip'), findsWidgets);
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Hidden mural frame'), findsWidgets);
    expect(find.text('Plain gallery capture'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'AR snapshots'));
    await tester.pumpAndSettle();

    expect(find.text('1 AR snapshot memory'), findsOneWidget);
    expect(find.text('Hidden mural frame'), findsWidgets);
    expect(find.text('Gallery AR clip'), findsNothing);
    expect(find.text('Rooftop sunset'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Recordings'));
    await tester.pumpAndSettle();

    expect(find.text('1 AR screen recording memory'), findsOneWidget);
    expect(find.text('Gallery AR clip'), findsWidgets);
    expect(find.text('Hidden mural frame'), findsNothing);
    expect(find.text('Rooftop sunset'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(-260, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Quality issues'));
    await tester.pumpAndSettle();

    expect(find.text('1 quality issue memory'), findsOneWidget);
    expect(find.text('Gallery AR clip'), findsWidgets);
    expect(find.text('Hidden mural frame'), findsNothing);
    expect(find.text('Rooftop sunset'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Photos'));
    await tester.pumpAndSettle();

    expect(find.text('1 photo memory'), findsOneWidget);
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Gallery AR clip'), findsNothing);
    expect(find.text('Hidden mural frame'), findsNothing);
  });

  testWidgets('memory search filters and matches media metadata',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Search AR clip',
          radiusMeters: 30,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 12),
          mediaAttachment: const AnchorMediaAttachment(
            type: AnchorMediaType.arRecording,
            filePath: '/tmp/search_ar_clip.mp4',
            duration: Duration(seconds: 1),
            frameCount: 3,
            targetFps: 30,
          ),
        );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Plain search capture',
          radiusMeters: 28,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 13),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MemorySearchScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Media'));
    await tester.pumpAndSettle();

    expect(find.text('3 results'), findsOneWidget);
    expect(find.text('Search AR clip'), findsWidgets);
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Hidden mural frame'), findsWidgets);
    expect(find.text('Plain search capture'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Quality Issues'));
    await tester.pumpAndSettle();

    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Search AR clip'), findsWidgets);
    expect(find.text('Rooftop sunset'), findsNothing);
    expect(find.text('Hidden mural frame'), findsNothing);
    expect(find.text('Plain search capture'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '3 frames');
    await tester.pumpAndSettle();

    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Search AR clip'), findsWidgets);

    await tester.enterText(find.byType(EditableText), 'quality issue');
    await tester.pumpAndSettle();

    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Search AR clip'), findsWidgets);

    await tester.enterText(
        find.byType(EditableText), '/tmp/search_ar_clip.mp4');
    await tester.pumpAndSettle();

    expect(find.text('No memories found'), findsOneWidget);
  });

  testWidgets('nearby filter narrows the home list to media captures',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Nearby AR clip',
          radiusMeters: 30,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 12),
          mediaAttachment: const AnchorMediaAttachment(
            type: AnchorMediaType.arRecording,
            filePath: '/tmp/nearby_ar_clip.mp4',
            duration: Duration(milliseconds: 1200),
            frameCount: 36,
          ),
        );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Plain nearby capture',
          radiusMeters: 28,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 13),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomeScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Media'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby AR clip'), findsWidgets);
    expect(
      find.text('AR screen recording: 1.2 s - 36 frames'),
      findsOneWidget,
    );
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Hidden mural frame'), findsWidgets);
    expect(find.text('Plain nearby capture'), findsNothing);
  });
}

AnchorMemory _memory({AnchorMediaAttachment? mediaAttachment}) {
  return AnchorMemory(
    id: 'anchor_media_surface',
    title: 'AR capture',
    caption: 'Recorded in the AR viewer.',
    distanceLabel: '7 m',
    capturedAgo: 'Just now',
    locationLabel: '-6.9175, 107.6191',
    latitude: -6.9175,
    longitude: 107.6191,
    reactions: 0,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    mediaAttachment: mediaAttachment,
  );
}

const _png1x1 = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
