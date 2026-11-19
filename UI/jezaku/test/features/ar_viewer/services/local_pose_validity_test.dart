import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/local_pose_validity.dart';

void main() {
  final sessionStart = DateTime.utc(2026, 11, 19, 8, 0, 0);

  test('pose captured after the session started is valid', () {
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: sessionStart.add(const Duration(minutes: 2)),
        sessionStartedAt: sessionStart,
      ),
      isTrue,
    );
  });

  test('pose from an earlier session is not valid', () {
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: sessionStart.subtract(const Duration(minutes: 10)),
        sessionStartedAt: sessionStart,
      ),
      isFalse,
    );
  });

  test('a restarted session invalidates poses from before the restart', () {
    final restartedAt = sessionStart.add(const Duration(minutes: 5));
    final capturedBeforeRestart = sessionStart.add(const Duration(minutes: 3));

    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: capturedBeforeRestart,
        sessionStartedAt: sessionStart,
      ),
      isTrue,
    );
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: capturedBeforeRestart,
        sessionStartedAt: restartedAt,
      ),
      isFalse,
    );
  });

  test('tolerates a few seconds of clock difference', () {
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: sessionStart.subtract(const Duration(seconds: 4)),
        sessionStartedAt: sessionStart,
      ),
      isTrue,
    );
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: sessionStart.subtract(const Duration(seconds: 6)),
        sessionStartedAt: sessionStart,
      ),
      isFalse,
    );
  });

  test('missing timestamps are never valid', () {
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: null,
        sessionStartedAt: sessionStart,
      ),
      isFalse,
    );
    expect(
      LocalPoseValidity.isValidInSession(
        poseCapturedAt: sessionStart,
        sessionStartedAt: null,
      ),
      isFalse,
    );
  });
}
