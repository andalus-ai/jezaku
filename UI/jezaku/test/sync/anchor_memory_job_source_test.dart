import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/anchor_memory_job_source.dart';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);

AnchorMemory _memory(String id, {AnchorMediaAttachment? media}) {
  return AnchorMemory(
    id: id,
    title: 'Frame',
    caption: 'Hello',
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
    mediaAttachment: media,
  );
}

void main() {
  test('uses the current frame as it is stored now', () {
    final memories = [_memory('a')];
    final source = AnchorMemoryJobSource(
      memories: () => memories,
      mediaBytes: (_) => null,
    );

    expect(source.jobFor('a', ownerId: 'u-1')?.caption, 'Hello');

    memories[0] = _memory('a').copyWith(caption: 'Edited while waiting');
    expect(
      source.jobFor('a', ownerId: 'u-1')?.caption,
      'Edited while waiting',
    );
  });

  test('a frame deleted on the device gives no job', () {
    final source = AnchorMemoryJobSource(
      memories: () => const <AnchorMemory>[],
      mediaBytes: (_) => null,
    );
    expect(source.jobFor('gone', ownerId: 'u-1'), isNull);
  });

  test('takes the photo from the media store when the frame has no bytes', () {
    final asked = <String>[];
    final source = AnchorMemoryJobSource(
      memories: () => [
        _memory(
          'a',
          media: const AnchorMediaAttachment(
            type: AnchorMediaType.cameraPhoto,
            mediaId: 'media-7',
          ),
        ),
      ],
      mediaBytes: (id) {
        asked.add(id);
        return _jpeg;
      },
    );

    final job = source.jobFor('a', ownerId: 'u-1');

    expect(asked, ['media-7']);
    expect(job?.photo?.contentType, 'image/jpeg');
    expect(job?.photo?.bytes, _jpeg);
    expect(job?.ownerId, 'u-1');
  });

  test('a frame without any photo bytes still gives a job without a photo', () {
    final source = AnchorMemoryJobSource(
      memories: () => [
        _memory(
          'a',
          media: const AnchorMediaAttachment(
            type: AnchorMediaType.cameraPhoto,
            mediaId: 'media-7',
          ),
        ),
      ],
      mediaBytes: (_) => null,
    );
    final job = source.jobFor('a', ownerId: 'u-1');
    expect(job, isNotNull);
    expect(job!.photo, isNull);
  });
}
