import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

AnchorMemory _frame({String? ownerId}) {
  return AnchorMemory(
    id: 'frame',
    title: 'frame',
    caption: '',
    distanceLabel: '',
    capturedAgo: 'Just now',
    locationLabel: '',
    latitude: -6.9,
    longitude: 107.6,
    reactions: 0,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 700,
      headingDegrees: 0,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: 3,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    ownerId: ownerId,
  );
}

FrameOwnerActions _actions(
  AnchorMemory memory, {
  String? userId,
  Set<String> friends = const {},
}) {
  return FrameOwnerActions.of(
    memory,
    FrameViewerContext.forUser(userId: userId, friendIds: friends),
  );
}

void _expectAll(FrameOwnerActions actions, {required bool allowed}) {
  expect(actions.isOwner, allowed);
  expect(actions.canChangeFrame, allowed);
  expect(actions.canCalibrate, allowed);
  expect(actions.canRehang, allowed);
  expect(actions.canOpenDetails, allowed);
}

void main() {
  group('FrameOwnerActions', () {
    test('a frame captured on this device is the viewer\'s own', () {
      _expectAll(_actions(_frame()), allowed: true);
      _expectAll(_actions(_frame(), userId: 'me'), allowed: true);
    });

    test('a frame the viewer authored is theirs', () {
      _expectAll(_actions(_frame(ownerId: 'me'), userId: 'me'), allowed: true);
    });

    test('a stranger\'s frame is view-only', () {
      _expectAll(
        _actions(_frame(ownerId: 'other'), userId: 'me'),
        allowed: false,
      );
    });

    test('a friend\'s frame is view-only too', () {
      _expectAll(
        _actions(_frame(ownerId: 'amy'), userId: 'me', friends: {'amy'}),
        allowed: false,
      );
    });

    test('demo rules (everyone is a friend) do not make others\' frames '
        'editable', () {
      final viewer = FrameViewerContext.everyoneIsAFriend(
        FrameViewerContext.forUser(userId: 'me'),
      );

      _expectAll(
        FrameOwnerActions.of(_frame(ownerId: 'other'), viewer),
        allowed: false,
      );
      _expectAll(FrameOwnerActions.of(_frame(), viewer), allowed: true);
    });

    test('nobody signed in: a frame with an owner id is not theirs', () {
      _expectAll(_actions(_frame(ownerId: 'other')), allowed: false);
    });
  });
}
