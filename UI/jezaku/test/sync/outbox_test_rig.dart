// Shared setup for the outbox wiring tests: a fake server and a container
// whose outbox runs against it.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/outbox/anchor_memory_job_source.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/outbox_store.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';

final testJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);

class OutboxTestPublisher implements FramePublisher {
  Object? createError;
  final created = <String>[];

  @override
  Future<String> uploadPhoto(
    FramePhoto photo, {
    required String ownerId,
  }) async =>
      'media-1';

  @override
  Future<MediaReview> reviewOf(String mediaId) async => MediaReview.approved;

  @override
  Future<String> createFrame(
    FramePublishJob job, {
    required String mediaId,
  }) async {
    if (createError != null) {
      throw createError!;
    }
    created.add(job.memoryId);
    return 'srv-${job.memoryId}';
  }
}

ProviderContainer outboxContainer({
  required OutboxTestPublisher publisher,
  String? userId = 'u-1',
  OutboxStore? store,
  bool withOutbox = true,
  List<AnchorMemory> seed = const <AnchorMemory>[],
}) {
  final container = ProviderContainer(
    overrides: [
      anchorMemoryStoreProvider.overrideWithValue(
        InMemoryAnchorMemoryStore()..saveCapturedMemories(seed),
      ),
      sampleDataEnabledProvider.overrideWithValue(false),
      signedInUserIdProvider.overrideWithValue(userId),
      if (withOutbox)
        frameOutboxProcessorProvider.overrideWith(
          (ref) => FrameOutboxProcessor(
            store: store ?? InMemoryOutboxStore(),
            publisher: publisher,
            jobs: AnchorMemoryJobSource(
              memories: () => ref.read(nearbyAnchorsProvider),
              mediaBytes: (_) => null,
            ),
            onPublished: (id, _) async {
              ref.read(nearbyAnchorsProvider.notifier).markMemorySynced(id);
            },
          ),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AnchorMemory captureFrame(
  ProviderContainer container, {
  AnchorMediaType type = AnchorMediaType.cameraPhoto,
  String caption = 'Hello',
}) {
  return container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
        caption: caption,
        radiusMeters: 20,
        ownerId: 'u-1',
        mediaAttachment: AnchorMediaAttachment(type: type, bytes: testJpeg),
      );
}

AnchorMemory storedFrame(ProviderContainer container, String id) => container
    .read(nearbyAnchorsProvider)
    .singleWhere((memory) => memory.id == id);

Future<void> settleOutbox(ProviderContainer container) async {
  await container.read(frameOutboxControllerProvider.notifier).syncNow();
  await pumpEventQueue();
}


AnchorMemory waitingFrame(
  String id, {
  String? ownerId = 'u-1',
  AnchorMediaType type = AnchorMediaType.cameraPhoto,
  AnchorSyncStatus status = AnchorSyncStatus.queued,
  AnchorSyncReason reason = AnchorSyncReason.newCapture,
}) {
  return AnchorMemory(
    id: id,
    title: id,
    caption: id,
    distanceLabel: '10 m',
    capturedAgo: 'Just now',
    locationLabel: 'Here',
    latitude: -6.9,
    longitude: 107.6,
    reactions: 0,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 10,
      headingDegrees: 90,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: 4,
      anchorType: 'geo',
      captureSource: 'test',
    ),
    mediaAttachment: AnchorMediaAttachment(type: type, bytes: testJpeg),
    ownerId: ownerId,
    syncStatus: status,
    syncReason: reason,
  );
}
