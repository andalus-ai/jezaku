import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';

Map<String, Object?> _memory({
  Object? id = 'm-1',
  Object? ownerId = 'u-1',
  Object? position = const <String, Object?>{
    'latitude': -6.2,
    'longitude': 106.8,
    'altitudeMeters': 12.5,
  },
  Object? visibility = 'friends',
}) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'mediaId': 'media-1',
      'mediaStatus': 'ready',
      'moderationStatus': 'approved',
      'mediaUrl': 'https://cdn.test/m.jpg',
      'thumbnailUrl': 'https://cdn.test/t.jpg',
      'caption': 'Cabinet in the hallway',
      'position': position,
      'headingDegrees': 90,
      'visibility': visibility,
      'capturedAt': '2026-11-20T11:07:00Z',
      'distanceMeters': 14.5,
    };

void main() {
  group('RemoteFrame.tryParse', () {
    test('reads a full memory', () {
      final frame = RemoteFrame.tryParse(_memory())!;

      expect(frame.id, 'm-1');
      expect(frame.ownerId, 'u-1');
      expect(frame.latitude, -6.2);
      expect(frame.longitude, 106.8);
      expect(frame.altitudeMeters, 12.5);
      expect(frame.headingDegrees, 90);
      expect(frame.audience, FrameAudience.friends);
      expect(frame.distanceMeters, 14.5);
      expect(frame.caption, 'Cabinet in the hallway');
      expect(frame.thumbnailUrl, 'https://cdn.test/t.jpg');
      expect(frame.mediaUrl, 'https://cdn.test/m.jpg');
      expect(frame.mediaStatus, 'ready');
      expect(frame.moderationStatus, 'approved');
      expect(frame.capturedAt, DateTime.utc(2026, 11, 20, 11, 7));
    });

    test('reads a minimap dot: heading from the anchor, no caption', () {
      final frame = RemoteFrame.tryParse(<String, Object?>{
        'id': 'd-1',
        'ownerId': 'u-2',
        'thumbnailUrl': 'https://cdn.test/t.jpg',
        'position': <String, Object?>{'latitude': 1, 'longitude': 2},
        'anchor': <String, Object?>{'headingDegrees': 45.0},
        'distanceMeters': 3,
      })!;

      expect(frame.headingDegrees, 45);
      expect(frame.caption, '');
      expect(frame.mediaUrl, isNull);
      expect(frame.distanceMeters, 3);
    });

    test('an unknown or missing visibility reads as private (fail closed)',
        () {
      for (final visibility in <Object?>['galaxy', null, 7]) {
        expect(
          RemoteFrame.tryParse(_memory(visibility: visibility))!.audience,
          FrameAudience.private,
          reason: '$visibility',
        );
      }
      expect(
        RemoteFrame.tryParse(_memory(visibility: 'public'))!.audience,
        FrameAudience.public,
      );
    });

    test('an entry without id, owner or a usable position is dropped', () {
      expect(RemoteFrame.tryParse(null), isNull);
      expect(RemoteFrame.tryParse('frame'), isNull);
      expect(RemoteFrame.tryParse(_memory(id: null)), isNull);
      expect(RemoteFrame.tryParse(_memory(id: '  ')), isNull);
      expect(RemoteFrame.tryParse(_memory(ownerId: null)), isNull);
      expect(RemoteFrame.tryParse(_memory(position: null)), isNull);
      expect(RemoteFrame.tryParse(_memory(position: 'here')), isNull);
      expect(
        RemoteFrame.tryParse(
          _memory(position: <String, Object?>{'latitude': 'x', 'longitude': 1}),
        ),
        isNull,
      );
    });

    test('coordinates outside the globe are dropped', () {
      for (final position in <Map<String, Object?>>[
        {'latitude': 91, 'longitude': 0},
        {'latitude': -91, 'longitude': 0},
        {'latitude': 0, 'longitude': 181},
        {'latitude': 0, 'longitude': -181},
        {'latitude': double.nan, 'longitude': 0},
      ]) {
        expect(RemoteFrame.tryParse(_memory(position: position)), isNull,
            reason: '$position');
      }
    });

    test('optional fields that are the wrong type are ignored', () {
      final frame = RemoteFrame.tryParse(<String, Object?>{
        ..._memory(),
        'capturedAt': 'yesterday-ish',
        'distanceMeters': 'close',
        'caption': 12,
        'thumbnailUrl': '',
      })!;

      expect(frame.capturedAt, isNull);
      expect(frame.distanceMeters, isNull);
      expect(frame.caption, '');
      expect(frame.thumbnailUrl, isNull);
    });
  });

  group('RemoteFrame.parseList', () {
    test('keeps the good entries and drops the bad ones', () {
      final frames = RemoteFrame.parseList(<Object?>[
        _memory(id: 'a'),
        'junk',
        _memory(id: null),
        _memory(id: 'b'),
      ]);

      expect(frames.map((f) => f.id), ['a', 'b']);
    });

    test('anything that is not a list is empty', () {
      expect(RemoteFrame.parseList(null), isEmpty);
      expect(RemoteFrame.parseList(<String, Object?>{}), isEmpty);
    });

    test('the returned list cannot be changed', () {
      final frames = RemoteFrame.parseList(<Object?>[_memory()]);

      expect(() => frames.clear(), throwsUnsupportedError);
    });
  });
}
