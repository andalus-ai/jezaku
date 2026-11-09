import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/screens/memory_detail_screen.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';

void main() {
  testWidgets('memory detail resolves preview bytes from stored media id',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Stored media detail',
              radiusMeters: 30,
              isPrivate: false,
              capturedAt: DateTime(2026, 5, 30, 12, 1),
              mediaAttachment: AnchorMediaAttachment(
                mediaId: storedAttachment.mediaId,
                storagePath: storedAttachment.storagePath,
                storedAt: storedAttachment.storedAt,
                type: AnchorMediaType.arSnapshot,
              ),
            );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MemoryDetailScreen(memoryId: memory.id),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('memory_media_image_${memory.id}')),
        findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('memory_media_inspect_${memory.id}')),
      120,
    );
    await tester.pumpAndSettle();

    expect(find.text(storedAttachment.mediaId!), findsOneWidget);
    expect(find.text(storedAttachment.storagePath!), findsOneWidget);
    expect(find.text('${_png1x1.length} B stored'), findsOneWidget);
    expect(find.text('Preview cached'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('memory_media_inspect_${memory.id}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('anchor_media_detail_sheet_${memory.id}')),
      findsOneWidget,
    );
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Media queued - 0 retries'), findsOneWidget);
    expect(find.text('Altitude'), findsWidgets);
    expect(find.text('714.2 m'), findsWidgets);
    expect(find.text('Heading'), findsWidgets);
    expect(find.text('245 deg SW'), findsWidgets);
    expect(find.text('Source'), findsWidgets);
    expect(find.text('GPS + compass + gyro'), findsWidgets);
  });

  testWidgets('memory detail labels media references with missing cache',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Missing cache detail',
              radiusMeters: 30,
              isPrivate: false,
              capturedAt: DateTime(2026, 5, 30, 12, 2),
              mediaAttachment: AnchorMediaAttachment(
                mediaId: storedAttachment.mediaId,
                storagePath: storedAttachment.storagePath,
                storedAt: storedAttachment.storedAt,
                type: AnchorMediaType.arSnapshot,
              ),
            );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MemoryDetailScreen(memoryId: memory.id),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(ValueKey('memory_media_image_${memory.id}')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('memory_media_inspect_${memory.id}')),
      120,
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview cache missing'), findsOneWidget);
    expect(find.text(storedAttachment.mediaId!), findsOneWidget);
    expect(find.text('${_png1x1.length} B stored'), findsNothing);
  });

  testWidgets('memory detail shows audit timeline for reviewed AR recording',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final capturedAt = DateTime.utc(2026, 5, 30, 12);
    final reviewedAt = DateTime.utc(2026, 5, 30, 12, 10);
    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Reviewed AR memory',
              radiusMeters: 30,
              isPrivate: false,
              capturedAt: capturedAt,
              mediaAttachment: AnchorMediaAttachment(
                type: AnchorMediaType.arRecording,
                filePath: '/tmp/reviewed_ar_clip.mp4',
                duration: const Duration(seconds: 1),
                frameCount: 3,
                targetFps: 30,
                videoBitrateKbps: 6000,
                outputFormat: 'mp4',
                includesUIOverlay: true,
                includesAudio: false,
                fileSizeBytes: 2048,
                recordingQualityReviewedAt: reviewedAt,
              ),
            );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MemoryDetailScreen(memoryId: memory.id),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timeline = find.byKey(const ValueKey('memory_audit_timeline_card'));

    expect(timeline, findsOneWidget);
    expect(_timelineText(timeline, 'Memory timeline'), findsOneWidget);
    expect(_timelineText(timeline, 'Capture'), findsOneWidget);
    expect(
      _timelineText(timeline, 'Just now at ${_timeLabel(capturedAt)}'),
      findsOneWidget,
    );
    expect(_timelineText(timeline, 'Media'), findsOneWidget);
    expect(
      _timelineText(timeline, 'AR screen recording: 1.0 s - 3 frames'),
      findsOneWidget,
    );
    expect(_timelineText(timeline, 'Quality review'), findsOneWidget);
    expect(
      _timelineText(
        timeline,
        'Quality review accepted - Reviewed ${_timeLabel(reviewedAt)}',
      ),
      findsOneWidget,
    );
    expect(_timelineText(timeline, 'Sync'), findsOneWidget);
    expect(
      _timelineText(timeline, 'Queued upload - New memory upload'),
      findsOneWidget,
    );
    expect(_timelineText(timeline, 'Moderation'), findsOneWidget);
    expect(_timelineText(timeline, 'Approved'), findsOneWidget);
  });

  testWidgets('memory detail can accept pending AR recording quality review',
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
      caption: 'Pending quality AR memory',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime.utc(2026, 5, 30, 12),
      mediaAttachment: const AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/pending_quality_ar_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
      ),
    );
    controller.markMemorySynced(memory.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MemoryDetailScreen(memoryId: memory.id),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timeline = find.byKey(const ValueKey('memory_audit_timeline_card'));
    final acceptButton = find.byKey(
      ValueKey('memory_quality_review_accept_${memory.id}'),
    );

    expect(_timelineText(timeline, 'Quality review pending'), findsOneWidget);
    expect(
        _timelineText(timeline, 'Synced - No local changes'), findsOneWidget);
    expect(acceptButton, findsOneWidget);

    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    final updated = container
        .read(nearbyAnchorsProvider)
        .singleWhere((item) => item.id == memory.id);

    expect(updated.mediaAttachment?.recordingQualityReviewedAt, isNotNull);
    expect(updated.syncStatus, AnchorSyncStatus.queued);
    expect(updated.syncReason, AnchorSyncReason.metadataUpdate);
    expect(
      _timelineTextContaining(timeline, 'Quality review accepted - Reviewed'),
      findsOneWidget,
    );
    expect(
      _timelineText(timeline, 'Queued update - Metadata update'),
      findsOneWidget,
    );
    expect(acceptButton, findsNothing);
    expect(find.text('Recording quality review accepted.'), findsOneWidget);
  });
}

Finder _timelineText(Finder timeline, String text) {
  return find.descendant(of: timeline, matching: find.text(text));
}

Finder _timelineTextContaining(Finder timeline, String text) {
  return find.descendant(of: timeline, matching: find.textContaining(text));
}

String _timeLabel(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
