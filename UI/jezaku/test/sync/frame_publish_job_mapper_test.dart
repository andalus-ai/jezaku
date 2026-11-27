import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/sync/outbox/frame_publish_job_mapper.dart';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);
final _png = Uint8List.fromList(
  [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0],
);
final _webp = Uint8List.fromList(
  [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50],
);
final _heic = Uint8List.fromList(
  [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63],
);

AnchorMemory _memory({
  AnchorMediaAttachment? media,
  FrameAudience audience = FrameAudience.friends,
  double heading = 90,
  double pitch = 0,
  double roll = 0,
  double accuracy = 4,
  bool ar = true,
  String look = 'oak',
}) {
  return AnchorMemory(
    id: 'frame-1',
    title: 't',
    caption: 'Sunset wall',
    distanceLabel: '',
    capturedAgo: '',
    locationLabel: '',
    latitude: -6.9,
    longitude: 107.6,
    reactions: 0,
    captureMetadata: AnchorCaptureMetadata(
      altitudeMeters: 700,
      headingDegrees: heading,
      pitchDegrees: pitch,
      rollDegrees: roll,
      gpsAccuracyMeters: accuracy,
      anchorType: 'Wall anchor - 2 m plan',
      captureSource: 'GPS + compass',
    ),
    mediaAttachment: media,
    capturedAt: DateTime.utc(2026, 11, 26, 8),
    audience: audience,
    frameLookId: look,
    hasArExperience: ar,
  );
}

AnchorMediaAttachment _photo(Uint8List bytes) =>
    AnchorMediaAttachment(type: AnchorMediaType.cameraPhoto, bytes: bytes);

void main() {
  group('FramePublishJobMapper.fromMemory', () {
    test('carries the frame the way the memory service expects it', () {
      final job = FramePublishJobMapper.fromMemory(
        _memory(media: _photo(_jpeg)),
        ownerId: 'u-1',
      );

      expect(job.memoryId, 'frame-1');
      expect(job.ownerId, 'u-1');
      expect(job.visibility, 'friends');
      expect(job.frameStyle, 'oak');
      expect(job.caption, 'Sunset wall');
      expect(job.latitude, -6.9);
      expect(job.longitude, 107.6);
      expect(job.altitudeMeters, 700);
      expect(job.headingDegrees, 90);
      expect(job.gpsAccuracyMeters, 4);
      expect(job.capturedAt, DateTime.utc(2026, 11, 26, 8));
      expect(job.photo!.contentType, 'image/jpeg');
      expect(job.photo!.fileName, 'frame-1.jpg');
      expect(job.isPublic, isFalse);
    });

    test('the audience travels as the service names it', () {
      for (final audience in FrameAudience.values) {
        final job = FramePublishJobMapper.fromMemory(
          _memory(audience: audience),
          ownerId: 'u',
        );
        expect(job.visibility, audience.name);
      }
      expect(
        FramePublishJobMapper.fromMemory(
          _memory(audience: FrameAudience.public),
          ownerId: 'u',
        ).isPublic,
        isTrue,
      );
    });

    test('anchor type is the service\'s, not the UI label', () {
      expect(
        FramePublishJobMapper.fromMemory(_memory(), ownerId: 'u').anchorType,
        'hybrid',
      );
      expect(
        FramePublishJobMapper.fromMemory(_memory(ar: false), ownerId: 'u')
            .anchorType,
        'geo',
      );
    });

    test('headings are wrapped into 0-360', () {
      double heading(double h) => FramePublishJobMapper.fromMemory(
            _memory(heading: h),
            ownerId: 'u',
          ).headingDegrees!;

      expect(heading(-90), 270);
      expect(heading(450), 90);
      expect(heading(360), 0);
      expect(heading(double.nan), 0);
    });

    test('values the service would refuse are left out, not sent', () {
      final job = FramePublishJobMapper.fromMemory(
        _memory(pitch: 120, roll: -200, accuracy: 0),
        ownerId: 'u',
      );

      expect(job.pitchDegrees, isNull);
      expect(job.rollDegrees, isNull);
      expect(job.gpsAccuracyMeters, isNull);
    });

    test('limits are inclusive', () {
      final job = FramePublishJobMapper.fromMemory(
        _memory(pitch: -90, roll: 180, accuracy: 0.1),
        ownerId: 'u',
      );

      expect(job.pitchDegrees, -90);
      expect(job.rollDegrees, 180);
      expect(job.gpsAccuracyMeters, 0.1);
    });
  });

  group('photoOf', () {
    test('names the type from the bytes, not from how the frame was taken', () {
      final cases = <Uint8List, List<String>>{
        _jpeg: ['image/jpeg', 'frame-1.jpg'],
        _png: ['image/png', 'frame-1.png'],
        _webp: ['image/webp', 'frame-1.webp'],
        _heic: ['image/heic', 'frame-1.heic'],
      };
      cases.forEach((bytes, expected) {
        final photo = FramePublishJobMapper.photoOf(_memory(media: _photo(bytes)));
        expect(photo!.contentType, expected[0]);
        expect(photo.fileName, expected[1]);
      });
    });

    test('no photo for a frame without bytes', () {
      expect(FramePublishJobMapper.photoOf(_memory()), isNull);
      expect(
        FramePublishJobMapper.photoOf(
          _memory(media: const AnchorMediaAttachment(type: AnchorMediaType.cameraPhoto)),
        ),
        isNull,
      );
      expect(
        FramePublishJobMapper.photoOf(_memory(media: _photo(Uint8List(0)))),
        isNull,
      );
    });

    test('no photo for bytes that are not an accepted image', () {
      expect(
        FramePublishJobMapper.photoOf(
          _memory(media: _photo(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]))),
        ),
        isNull,
      );
      expect(
        FramePublishJobMapper.photoOf(_memory(media: _photo(Uint8List.fromList([0xFF])))),
        isNull,
      );
    });

    test('recordings and 3D objects are not uploaded yet', () {
      for (final type in [AnchorMediaType.arRecording, AnchorMediaType.arModel]) {
        final media = AnchorMediaAttachment(type: type, bytes: _jpeg);
        expect(FramePublishJobMapper.photoOf(_memory(media: media)), isNull);
      }
    });

    test('snapshots and imported photos are photos', () {
      for (final type in [
        AnchorMediaType.arSnapshot,
        AnchorMediaType.importedPhoto,
      ]) {
        final media = AnchorMediaAttachment(type: type, bytes: _png);
        expect(FramePublishJobMapper.photoOf(_memory(media: media)), isNotNull);
      }
    });
  });
}
