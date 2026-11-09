import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/screens/sync_queue_screen.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

void main() {
  testWidgets('sync queue treats bundled 3D model assets as metadata-only',
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
          caption: 'Bundled AR object',
          radiusMeters: 30,
          isPrivate: false,
          capturedAt: DateTime(2026, 5, 30, 11),
          mediaAttachment: AnchorMediaAttachment(
            type: AnchorMediaType.arModel,
            modelAsset: ARModelAsset.fromPath(
              'assets/models/queue_marker.obj',
            ),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncQueueScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '1 sync item: 1 upload, 0 media payloads, 0 metadata updates, '
        '0 quality issues',
      ),
      findsOneWidget,
    );
    expect(
        find.text('3D AR object: OBJ model: queue_marker.obj'), findsWidgets);
    expect(find.text('3D model metadata'), findsOneWidget);
    expect(find.text('OBJ model'), findsOneWidget);
    expect(find.text('Flutter asset'), findsOneWidget);
    expect(find.text('queue_marker.obj'), findsOneWidget);
    expect(find.text('Model asset ready with 1 warning'), findsOneWidget);
    expect(
      find.text(
        'No fallback size supplied; primitive fallback uses the node scale.',
      ),
      findsOneWidget,
    );
    expect(find.text('No media upload needed'), findsOneWidget);
    expect(find.text('Inspect Media'), findsOneWidget);
    expect(find.text('Upload Media'), findsNothing);
    expect(container.read(pendingMediaUploadMemoriesProvider), isEmpty);
    expect(container.read(anchorMediaUploadQueueProvider), isEmpty);
  });

  testWidgets('sync queue filters media payload uploads', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final qualityReviewedAt = DateTime.utc(2026, 5, 30, 12, 10);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    controller.addCapturedMemory(
      caption: 'AR clip payload',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 12),
      mediaAttachment: AnchorMediaAttachment(
        mediaId: 'media_arRecording_0042',
        storagePath: 'jejaku://media/media_arRecording_0042',
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
    controller.addCapturedMemory(
      caption: 'Metadata-only capture',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 13),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncQueueScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text(
            '2 sync items: 2 uploads, 1 media payload, 0 metadata updates, '
            '1 quality issue'),
        findsOneWidget);
    expect(
      find.text('AR screen recording: 1.0 s - 3 frames'),
      findsOneWidget,
    );
    expect(find.text('Stored media'), findsOneWidget);
    expect(find.text('media_arRecording_0042'), findsOneWidget);
    expect(find.text('jejaku://media/media_arRecording_0042'), findsOneWidget);
    expect(find.text('File-backed payload'), findsOneWidget);
    expect(find.text('Media queued'), findsOneWidget);
    expect(find.text('0 retries'), findsOneWidget);
    expect(find.text('AR recording profile'), findsOneWidget);
    expect(
      find.text('Low captured FPS - Captured 3.0 of 30 fps target'),
      findsOneWidget,
    );
    expect(find.text('30 fps target'), findsOneWidget);
    expect(find.text('3.0 fps captured'), findsOneWidget);
    expect(find.text('6.0 Mbps'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);
    expect(find.text('AR visual overlay'), findsOneWidget);
    expect(find.text('Silent'), findsOneWidget);
    expect(find.text('Quality review accepted'), findsOneWidget);
    expect(find.text('Reviewed 19:10'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('Upload Media'), findsOneWidget);
    expect(find.text('Metadata-only capture'), findsWidgets);

    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();

    expect(find.text('AR clip payload'), findsWidgets);
    expect(find.text('media_arRecording_0042'), findsOneWidget);
    expect(find.text('Metadata-only capture'), findsNothing);

    await tester.tap(find.text('Upload Media'));
    await tester.pumpAndSettle();

    expect(find.text('Media uploaded'), findsOneWidget);
    expect(find.text('Media Uploaded'), findsOneWidget);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();

    expect(find.text('No media uploads pending'), findsOneWidget);
    expect(find.text('AR clip payload'), findsNothing);
    expect(find.text('media_arRecording_0042'), findsNothing);
    expect(find.text('Metadata-only capture'), findsNothing);
    expect(find.text('/tmp/jejaku_clip.mp4'), findsNothing);
  });

  testWidgets('sync all uploads media payloads before clearing pending sync',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final memory = controller.addCapturedMemory(
      caption: 'Bulk synced AR clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 14),
      mediaAttachment: const AnchorMediaAttachment(
        mediaId: 'media_arRecording_0099',
        storagePath: 'jejaku://media/media_arRecording_0099',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/bulk_clip.mp4',
        duration: Duration(milliseconds: 1200),
        frameCount: 36,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 2048,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncQueueScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync All'), findsOneWidget);
    expect(
      mediaUploadEntryFor(
        container.read(anchorMediaUploadQueueProvider),
        memory,
      ).status,
      AnchorMediaUploadStatus.queued,
    );

    await tester.tap(find.text('Sync All'));
    await tester.pumpAndSettle();

    expect(container.read(pendingSyncMemoriesProvider), isEmpty);
    expect(
      mediaUploadEntryFor(
        container.read(anchorMediaUploadQueueProvider),
        memory,
      ).status,
      AnchorMediaUploadStatus.uploaded,
    );
    expect(find.text('All memories synced'), findsOneWidget);
  });

  testWidgets('sync queue accepts pending AR recording quality review',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final memory = controller.addCapturedMemory(
      caption: 'Pending queue AR clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 15),
      mediaAttachment: const AnchorMediaAttachment(
        mediaId: 'media_arRecording_0101',
        storagePath: 'jejaku://media/media_arRecording_0101',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/pending_queue_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 2048,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncQueueScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final acceptButton = find.byKey(
      ValueKey('sync_quality_review_accept_${memory.id}'),
    );

    expect(find.text('Quality review pending'), findsOneWidget);
    expect(acceptButton, findsOneWidget);

    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    final updated = container
        .read(nearbyAnchorsProvider)
        .singleWhere((item) => item.id == memory.id);

    expect(updated.mediaAttachment?.recordingQualityReviewedAt, isNotNull);
    expect(updated.syncStatus, AnchorSyncStatus.queued);
    expect(updated.syncReason, AnchorSyncReason.newCapture);
    expect(find.text('Quality review pending'), findsNothing);
    expect(find.text('Quality review accepted'), findsOneWidget);
    expect(find.textContaining('Reviewed '), findsOneWidget);
    expect(acceptButton, findsNothing);
    expect(find.text('Recording quality review accepted.'), findsOneWidget);
  });

  testWidgets('sync queue bulk accepts pending AR recording quality reviews',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final first = controller.addCapturedMemory(
      caption: 'First pending queue clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 16),
      mediaAttachment: const AnchorMediaAttachment(
        mediaId: 'media_arRecording_0102',
        storagePath: 'jejaku://media/media_arRecording_0102',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/first_pending_queue_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
      ),
    );
    final second = controller.addCapturedMemory(
      caption: 'Second pending queue clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 17),
      mediaAttachment: const AnchorMediaAttachment(
        mediaId: 'media_arRecording_0103',
        storagePath: 'jejaku://media/media_arRecording_0103',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/second_pending_queue_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 6,
        targetFps: 30,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncQueueScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();

    final bulkAcceptButton = find.byKey(
      const ValueKey('sync_accept_all_quality_reviews_button'),
    );

    expect(find.textContaining('2 quality issues'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync_quality_review_summary')),
      findsOneWidget,
    );
    expect(find.text('Quality reviews pending'), findsOneWidget);
    expect(find.text('2 pending reviews'), findsOneWidget);
    expect(find.text('0 accepted'), findsOneWidget);
    expect(find.text('Quality review pending'), findsNWidgets(2));
    expect(find.text('Accept 2 Quality Reviews'), findsOneWidget);
    expect(bulkAcceptButton, findsOneWidget);

    await tester.tap(bulkAcceptButton);
    await tester.pumpAndSettle();

    final updatedMemories = container.read(nearbyAnchorsProvider);
    final updatedFirst =
        updatedMemories.singleWhere((memory) => memory.id == first.id);
    final updatedSecond =
        updatedMemories.singleWhere((memory) => memory.id == second.id);

    expect(updatedFirst.mediaAttachment?.recordingQualityReviewedAt, isNotNull);
    expect(
      updatedSecond.mediaAttachment?.recordingQualityReviewedAt,
      updatedFirst.mediaAttachment?.recordingQualityReviewedAt,
    );
    expect(find.text('Quality review pending'), findsNothing);
    expect(find.text('Quality reviews ready for sync'), findsOneWidget);
    expect(find.text('0 pending reviews'), findsOneWidget);
    expect(find.text('2 accepted'), findsOneWidget);
    expect(find.text('Quality review accepted'), findsNWidgets(2));
    expect(bulkAcceptButton, findsNothing);
    expect(
      find.text('2 recording quality reviews accepted.'),
      findsOneWidget,
    );
  });
}
