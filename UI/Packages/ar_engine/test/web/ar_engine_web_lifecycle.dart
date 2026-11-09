import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine/ar_engine_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web backend event streams remain usable after destroySession',
      () async {
    final platform = ArEngineWebPlugin();

    final firstAnchors = <ARAnchor>[];
    final firstSub = platform.anchorStream.listen(firstAnchors.add);
    await platform.addAnchorAtPose(const ARPoseInput(x: 1, y: 2, z: 3));
    await pumpEventQueue();

    expect(firstAnchors, hasLength(1));
    await platform.destroySession();
    await firstSub.cancel();

    final secondAnchors = <ARAnchor>[];
    final secondSub = platform.anchorStream.listen(secondAnchors.add);
    await platform.addAnchorAtPose(const ARPoseInput(x: 4, y: 5, z: 6));
    await pumpEventQueue();

    expect(secondAnchors, hasLength(1));
    expect(secondAnchors.single.pose.position.x, 4);

    await secondSub.cancel();
    await platform.destroySession();
  });
}
