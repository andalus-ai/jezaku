import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

const _originLat = -6.91755;
const _originLng = 107.61905;

AnchorMemory _memory(
  String id, {
  double metersNorth = 0,
  bool isPrivate = false,
  AnchorModerationStatus moderation = AnchorModerationStatus.approved,
}) {
  return AnchorMemory(
    id: id,
    title: id,
    caption: '',
    distanceLabel: '',
    capturedAgo: 'Just now',
    locationLabel: '',
    latitude: _originLat + metersNorth / 111320,
    longitude: _originLng,
    reactions: 0,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 714,
      headingDegrees: 0,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: 3,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    isPrivate: isPrivate,
    moderationStatus: moderation,
  );
}

List<ARMemoryProjection> _project(
  List<AnchorMemory> memories, {
  double viewerMetersNorth = 0,
}) {
  return projectAnchorMemories(
    memories: memories,
    viewerPose: JejakuViewerPose(
      origin: JejakuGeoOrigin(
        latitude: _originLat + viewerMetersNorth / 111320,
        longitude: _originLng,
        altitudeMeters: 714,
      ),
      headingDegrees: 0,
      pitchDegrees: 0,
      horizontalFovDegrees: 118,
      verticalFovDegrees: 52,
      maxDistanceMeters: 260,
    ),
    onlyInRange: false,
  );
}

FrameViewerContext viewerWith(FrameViewerRelation relation) =>
    FrameViewerContext(relationTo: (_) => relation);

List<String> _ids(List<ARMemoryProjection> projections) =>
    [for (final projection in projections) projection.memory.id]..sort();

void main() {
  final policy = FrameVisibilityPolicy.standard();
  const owner = FrameViewerContext.localStore();

  group('physical radius', () {
    test('shows only frames within the default 20 m of the viewer', () {
      final projected = _project([
        _memory('here'),
        _memory('near', metersNorth: 15),
        _memory('far', metersNorth: 25),
        _memory('distant', metersNorth: 200),
      ]);

      expect(defaultFrameViewRadiusMeters, 20);
      expect(_ids(policy.viewable(projected, owner)), ['here', 'near']);
    });

    test('the visible area follows the viewer as they walk', () {
      final memories = [
        _memory('a', metersNorth: 0),
        _memory('b', metersNorth: 100),
      ];

      expect(
        _ids(policy.viewable(_project(memories), owner)),
        ['a'],
      );
      expect(
        _ids(policy.viewable(_project(memories, viewerMetersNorth: 90), owner)),
        ['b'],
      );
      expect(
        _ids(policy.viewable(_project(memories, viewerMetersNorth: 50), owner)),
        isEmpty,
      );
    });

    test('the boundary is inclusive and an unknown distance fails closed', () {
      const rule = FramePhysicalRadiusRule();
      FrameVisibilityDecision at(double meters) => rule.evaluate(
            FrameVisibilityCandidate(
              memory: _memory('m'),
              horizontalDistanceMeters: meters,
            ),
            owner,
          );

      expect(at(20).isVisible, isTrue);
      expect(at(20.01).isVisible, isFalse);
      expect(at(double.nan).isVisible, isFalse);
      expect(at(double.infinity).isVisible, isFalse);
    });

    test('a custom radius is honoured', () {
      final wide = FrameVisibilityPolicy.standard(radiusMeters: 50);
      final projected = _project([_memory('thirty', metersNorth: 30)]);

      expect(_ids(wide.viewable(projected, owner)), ['thirty']);
      expect(policy.viewable(projected, owner), isEmpty);
    });

    test('reports the radius as the reason a close-enough frame is hidden', () {
      final decision = policy.evaluate(
        FrameVisibilityCandidate(
          memory: _memory('far'),
          horizontalDistanceMeters: 80,
        ),
        owner,
      );

      expect(decision, isA<FrameHidden>());
      expect(
        (decision as FrameHidden).reason,
        FrameHiddenReason.outsidePhysicalRadius,
      );
    });
  });

  group('edge of the radius', () {
    test('a frame already viewable stays visible within the exit margin', () {
      final projected = _project([_memory('edge', metersNorth: 23)]);

      expect(_ids(policy.viewable(projected, owner)), isEmpty);
      expect(
        _ids(
          policy.viewable(
            projected,
            owner,
            previouslyViewableIds: {'edge'},
          ),
        ),
        ['edge'],
      );
    });

    test('the margin ends: past radius plus margin it hides even if seen', () {
      final projected = _project([_memory('gone', metersNorth: 30)]);

      expect(
        _ids(
          policy.viewable(
            projected,
            owner,
            previouslyViewableIds: {'gone'},
          ),
        ),
        isEmpty,
      );
    });

    test('walking out of range and back does not flicker at the edge', () {
      final frames = [_memory('edge')];
      var seen = <String>{};
      final shown = <bool>[];
      // Viewer walks 18, 21, 24, 22, 19 m away from the frame, then 26 m.
      for (final distance in [18.0, 21.0, 24.0, 22.0, 19.0, 26.0]) {
        final outcome = policy.resolve(
          _project(frames, viewerMetersNorth: distance),
          owner,
          previouslyViewableIds: seen,
        );
        seen = outcome.viewableIds;
        shown.add(seen.contains('edge'));
      }

      expect(shown, [true, true, true, true, true, false]);
    });

    test('a frame that was never viewable still needs the real radius', () {
      final outcome = policy.resolve(
        _project([_memory('new', metersNorth: 22)]),
        owner,
      );

      expect(outcome.viewable, isEmpty);
    });
  });

  group('nearest own frame cue', () {
    test('reports the closest own frame that is out of range', () {
      final outcome = policy.resolve(
        _project([
          _memory('here', metersNorth: 5),
          _memory('far', metersNorth: 80),
          _memory('farther', metersNorth: 150),
        ]),
        owner,
      );

      expect(_ids(outcome.viewable), ['here']);
      expect(outcome.nearestOwnFrameOutsideRadiusMeters, closeTo(80, 1));
    });

    test('is null when every own frame is already in range', () {
      final outcome = policy.resolve(
        _project([_memory('here', metersNorth: 5)]),
        owner,
      );

      expect(outcome.nearestOwnFrameOutsideRadiusMeters, isNull);
    });

    test('never reports other people\'s frames, so it cannot find them', () {
      final outcome = policy.resolve(
        _project([_memory('theirs', metersNorth: 80)]),
        viewerWith(FrameViewerRelation.friend),
      );

      expect(outcome.nearestOwnFrameOutsideRadiusMeters, isNull);
    });
  });

  group('audience', () {
    test('public frames are visible to strangers, friends and the owner', () {
      final projected = _project([_memory('public')]);

      for (final relation in FrameViewerRelation.values) {
        expect(
          _ids(policy.viewable(projected, viewerWith(relation))),
          ['public'],
          reason: '$relation',
        );
      }
    });

    test('private frames are visible to their owner only', () {
      final projected = _project([_memory('secret', isPrivate: true)]);

      expect(
        _ids(policy.viewable(projected, viewerWith(FrameViewerRelation.owner))),
        ['secret'],
      );
      expect(
        policy.viewable(projected, viewerWith(FrameViewerRelation.friend)),
        isEmpty,
      );
      expect(
        policy.viewable(projected, viewerWith(FrameViewerRelation.none)),
        isEmpty,
      );
    });

    test('non-private frames map to public until friends-only is modelled', () {
      // The client model records private versus not private only. When
      // AnchorMemory carries the backend's public | friends | private, map it
      // in frameAudienceOf and extend this group with friends-only cases.
      expect(frameAudienceOf(_memory('open')), FrameAudience.public);
      expect(
        frameAudienceOf(_memory('secret', isPrivate: true)),
        FrameAudience.private,
      );
    });

    test('a hidden audience reason is notShared', () {
      final decision = policy.evaluate(
        FrameVisibilityCandidate(
          memory: _memory('secret', isPrivate: true),
          horizontalDistanceMeters: 1,
        ),
        viewerWith(FrameViewerRelation.none),
      );

      expect((decision as FrameHidden).reason, FrameHiddenReason.notShared);
    });
  });

  group('moderation', () {
    test('hidden frames are never shown, even to their owner', () {
      final projected = _project([
        _memory('ok'),
        _memory('removed', moderation: AnchorModerationStatus.hidden),
        _memory('flagged', moderation: AnchorModerationStatus.flagged),
      ]);

      expect(_ids(policy.viewable(projected, owner)), ['flagged', 'ok']);
    });
  });

  group('policy composition', () {
    test('eligible ignores distance so guidance can still point to a frame', () {
      final projected = _project([
        _memory('near'),
        _memory('far', metersNorth: 500),
        _memory('secret', isPrivate: true),
      ]);
      const stranger = FrameViewerContext(
        relationTo: _noRelation,
      );

      expect(_ids(policy.eligible(projected, stranger)), ['far', 'near']);
      expect(_ids(policy.viewable(projected, stranger)), ['near']);
    });

    test('a new rule joins the policy without touching callers', () {
      final custom = FrameVisibilityPolicy(
        rules: [
          const FramePhysicalRadiusRule(),
          _HideTitled('banned'),
        ],
      );
      final projected = _project([_memory('banned'), _memory('fine')]);

      expect(_ids(custom.viewable(projected, owner)), ['fine']);
    });

    test('evaluate can be limited to one stage', () {
      final decision = policy.evaluate(
        FrameVisibilityCandidate(
          memory: _memory('far'),
          horizontalDistanceMeters: 500,
        ),
        owner,
        stage: FrameRuleStage.eligibility,
      );

      expect(decision.isVisible, isTrue);
    });
  });
}

FrameViewerRelation _noRelation(AnchorMemory memory) => FrameViewerRelation.none;

class _HideTitled implements FrameVisibilityRule {
  _HideTitled(this.title);

  final String title;

  @override
  FrameRuleStage get stage => FrameRuleStage.eligibility;

  @override
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  ) {
    return candidate.memory.title == title
        ? const FrameVisibilityDecision.hidden(FrameHiddenReason.moderated)
        : const FrameVisibilityDecision.visible();
  }
}
