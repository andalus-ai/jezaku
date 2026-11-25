import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';
import 'package:jejaku/features/remote_frames/widgets/locked_frame_card.dart';

const _lat = -6.9175;
const _lng = 107.6191;

/// Someone else's frame hanging at ([_lat], [_lng]).
AnchorMemory _theirs({
  FrameAudience audience = FrameAudience.public,
  String moderation = 'approved',
  String ownerId = 'amy',
  double? distanceMeters = 5,
}) {
  return RemoteFrameMapper.toAnchorMemory(
    RemoteFrame(
      id: 'frame',
      ownerId: ownerId,
      latitude: _lat,
      longitude: _lng,
      audience: audience,
      distanceMeters: distanceMeters,
      moderationStatus: moderation,
    ),
  );
}

ViewerLocation _viewerMetersNorth(double meters) => ViewerLocation(
      latitude: _lat + meters / 111320,
      longitude: _lng,
      isLive: true,
    );

FrameAccessResolver _resolver(FrameRulesMode mode) =>
    FrameAccessResolver(policy: FrameVisibilityPolicy.forMode(mode));

final _me = FrameViewerContext.forUser(userId: 'me');

FrameAccess _resolveStrict(
  AnchorMemory? memory, {
  required ViewerLocation location,
  FrameViewerContext? viewer,
  bool alreadyOnSite = false,
}) {
  return _resolver(FrameRulesMode.strict).resolve(
    memory: memory,
    viewer: viewer ?? _me,
    location: location,
    alreadyOnSite: alreadyOnSite,
  );
}

void main() {
  group('FrameAccessResolver (strict rules)', () {
    test('the owner opens their own frame from anywhere', () {
      final own = _theirs(ownerId: 'me');

      expect(
        _resolveStrict(own, location: _viewerMetersNorth(5000)),
        isA<FrameAccessOpen>(),
      );
      // Even a private, moderator-hidden frame of the viewer's own opens for them.
      final local = RemoteFrameMapper.toAnchorMemory(
        const RemoteFrame(
          id: 'frame',
          ownerId: 'me',
          latitude: _lat,
          longitude: _lng,
          audience: FrameAudience.private,
          distanceMeters: 1,
        ),
      ).copyWith(moderationStatus: AnchorModerationStatus.hidden);
      expect(
        _resolveStrict(local, location: _viewerMetersNorth(5000)),
        isA<FrameAccessOpen>(),
      );
    });

    test('someone else\'s public frame opens only on site', () {
      final frame = _theirs();

      expect(
        _resolveStrict(frame, location: _viewerMetersNorth(10)),
        isA<FrameAccessOpen>(),
      );
      final far = _resolveStrict(frame, location: _viewerMetersNorth(340));
      expect(far, isA<FrameAccessLocked>());
      expect((far as FrameAccessLocked).distanceMeters, closeTo(340, 2));
    });

    test('a friend gets no remote access either', () {
      final frame = _theirs(audience: FrameAudience.friends);
      final friend = FrameViewerContext.forUser(
        userId: 'me',
        friendIds: {'amy'},
      );

      expect(
        _resolveStrict(
          frame,
          viewer: friend,
          location: _viewerMetersNorth(10),
        ),
        isA<FrameAccessOpen>(),
      );
      expect(
        _resolveStrict(
          frame,
          viewer: friend,
          location: _viewerMetersNorth(340),
        ),
        isA<FrameAccessLocked>(),
      );
    });

    test('a frame the viewer may not see at all is unavailable, not locked',
        () {
      expect(
        _resolveStrict(
          _theirs(audience: FrameAudience.friends),
          location: _viewerMetersNorth(10),
        ),
        isA<FrameAccessUnavailable>(),
      );
      expect(
        _resolveStrict(
          _theirs(audience: FrameAudience.private),
          location: _viewerMetersNorth(340),
        ),
        isA<FrameAccessUnavailable>(),
      );
      expect(
        _resolveStrict(
          _theirs(moderation: 'hidden'),
          location: _viewerMetersNorth(10),
        ),
        isA<FrameAccessUnavailable>(),
      );
      expect(
        _resolveStrict(
          _theirs(moderation: ''),
          location: _viewerMetersNorth(10),
        ),
        isA<FrameAccessUnavailable>(),
      );
    });

    test('the edge margin applies only to a screen opened on site', () {
      final frame = _theirs();
      final edge = _viewerMetersNorth(23);

      expect(_resolveStrict(frame, location: edge), isA<FrameAccessLocked>());
      expect(
        _resolveStrict(frame, location: edge, alreadyOnSite: true),
        isA<FrameAccessOpen>(),
      );
      expect(
        _resolveStrict(
          frame,
          location: _viewerMetersNorth(40),
          alreadyOnSite: true,
        ),
        isA<FrameAccessLocked>(),
      );
    });

    test('without a live fix nothing opens, even if the label says it is near',
        () {
      // "1.2 km" would read as 1.2 from the text label; it must never open.
      final far = _theirs(distanceMeters: 1200);
      final near = _theirs(distanceMeters: 5);

      for (final frame in [far, near]) {
        final access = _resolveStrict(
          frame,
          location: const ViewerLocation(latitude: _lat, longitude: _lng),
        );
        expect(access, isA<FrameAccessLocked>());
        expect((access as FrameAccessLocked).distanceMeters, isNull);
      }
    });

    test('a frame this device does not know is locked, never open', () {
      expect(
        _resolveStrict(null, location: _viewerMetersNorth(0)),
        isA<FrameAccessLocked>(),
      );
    });

    test('a remote frame has no place name to show', () {
      final access = _resolveStrict(
        _theirs(),
        location: _viewerMetersNorth(340),
      ) as FrameAccessLocked;

      expect(access.placeLabel, isNull);
    });

    test('a named place is kept', () {
      final named = _theirs().copyWith(locationLabel: 'Sasana Budaya');

      final access = _resolveStrict(
        named,
        location: _viewerMetersNorth(340),
      ) as FrameAccessLocked;

      expect(access.placeLabel, 'Sasana Budaya');
    });
  });

  group('FrameAccessResolver (demo rules)', () {
    final demoViewer = FrameViewerContext.everyoneIsAFriend(_me);

    test('distance does not lock anything and unknown frames are left open',
        () {
      final resolver = _resolver(FrameRulesMode.demo);

      expect(
        resolver.resolve(
          memory: _theirs(audience: FrameAudience.friends),
          viewer: demoViewer,
          location: _viewerMetersNorth(5000),
        ),
        isA<FrameAccessOpen>(),
      );
      expect(
        resolver.resolve(
          memory: null,
          viewer: demoViewer,
          location: _viewerMetersNorth(5000),
        ),
        isA<FrameAccessOpen>(),
      );
    });

    test('moderation still applies', () {
      expect(
        _resolver(FrameRulesMode.demo).resolve(
          memory: _theirs(moderation: 'hidden'),
          viewer: demoViewer,
          location: _viewerMetersNorth(5),
        ),
        isA<FrameAccessUnavailable>(),
      );
    });
  });

  group('locked frame text', () {
    test('formatFrameDistance', () {
      expect(formatFrameDistance(null), isNull);
      expect(formatFrameDistance(double.infinity), isNull);
      expect(formatFrameDistance(-3), isNull);
      expect(formatFrameDistance(12.4), '12 m');
      expect(formatFrameDistance(340), '340 m');
      expect(formatFrameDistance(1234), '1.2 km');
    });

    test('blockedFrameMessage', () {
      expect(blockedFrameMessage(const FrameAccess.open()), isNull);
      expect(
        blockedFrameMessage(const FrameAccess.unavailable()),
        'This frame is no longer available.',
      );
      expect(
        blockedFrameMessage(
          const FrameAccess.locked(distanceMeters: 340, placeLabel: 'Museum'),
        ),
        'Go to Museum to open it. 340 m away. Frames open only on site.',
      );
      expect(
        blockedFrameMessage(const FrameAccess.locked()),
        'Go to this frame to open it. Frames open only on site.',
      );
      expect(
        blockedFrameMessage(
          const FrameAccess.locked(),
          fallbackPlace: 'Campus Walk',
        ),
        'Go to Campus Walk to open it. Frames open only on site.',
      );
    });
  });
}
