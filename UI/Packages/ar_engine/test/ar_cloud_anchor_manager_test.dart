import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
  });

  tearDown(() {
    arHarness.restore();
  });

  TestArEnginePlatform replacePlatform(TestArEnginePlatform platform) {
    arHarness.restore();
    arHarness = ArEngineTestHarness.install(platform: platform);
    return platform;
  }

  test('ARCloudAnchorManager hosts anchors and exports hosted ids', () async {
    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(
      controller,
      hostingDelay: Duration.zero,
      resolutionDelay: Duration.zero,
    );
    final hosted = Completer<ARCloudAnchor>();
    final subscription = manager.onHosted.listen((anchor) {
      if (!hosted.isCompleted) hosted.complete(anchor);
    });

    final anchor = await manager.hostAnchor(hitResult: _hit(), ttlDays: 1);

    expect(anchor.state, ARCloudAnchorState.hosting);

    final event = await hosted.future.timeout(const Duration(seconds: 1));
    expect(identical(event, anchor), isTrue);
    expect(anchor.state, ARCloudAnchorState.hosted);
    expect(anchor.cloudId, isNotNull);
    expect(anchor.expiresAt, isNotNull);
    expect(manager.allCloudAnchors, <ARCloudAnchor>[anchor]);

    final exported = manager.exportHostedIds();
    expect(exported, hasLength(1));
    expect(exported.single['cloudId'], anchor.cloudId);
    expect(exported.single['localId'], anchor.localId);

    await subscription.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('ARCloudAnchorManager resolves anchors', () async {
    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(
      controller,
      hostingDelay: Duration.zero,
      resolutionDelay: Duration.zero,
    );
    final resolved = Completer<ARCloudAnchor>();
    final subscription = manager.onResolved.listen((anchor) {
      if (!resolved.isCompleted) resolved.complete(anchor);
    });

    final anchor = await manager.resolveAnchor('cloud_123');
    final event = await resolved.future.timeout(const Duration(seconds: 1));

    expect(identical(event, anchor), isTrue);
    expect(anchor.localId, 'local_resolve_0');
    expect(anchor.cloudId, 'cloud_123');
    expect(anchor.state, ARCloudAnchorState.resolved);
    expect(anchor.resolvedAnchor?.trackingState, ARTrackingState.tracking);
    expect(manager.allCloudAnchors, <ARCloudAnchor>[anchor]);

    await subscription.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('ARCloudAnchorManager uses native cloud host and resolve paths',
      () async {
    const nativeResolved = ARAnchor(
      id: 'native_resolved',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_native'},
    );
    final platform = replacePlatform(
      TestArEnginePlatform()
        ..hostedCloudIds['anchor_0'] = 'cloud_native'
        ..resolvedCloudAnchors['cloud_native'] = nativeResolved,
    );

    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(
      controller,
      hostingDelay: const Duration(seconds: 5),
      resolutionDelay: const Duration(seconds: 5),
    );
    final hosted = Completer<ARCloudAnchor>();
    final resolved = Completer<ARCloudAnchor>();
    final hostedSub = manager.onHosted.listen((anchor) {
      if (!hosted.isCompleted) hosted.complete(anchor);
    });
    final resolvedSub = manager.onResolved.listen((anchor) {
      if (!resolved.isCompleted) resolved.complete(anchor);
    });

    final hostedAnchor = await manager.hostAnchor(
      hitResult: _hit(),
      ttlDays: 7,
    );
    await hosted.future.timeout(const Duration(seconds: 1));

    expect(hostedAnchor.cloudId, 'cloud_native');
    expect(platform.hostCloudAnchorRequests.single, <String, Object?>{
      'anchorId': 'anchor_0',
      'ttlDays': 7,
    });

    final resolvedAnchor = await manager.resolveAnchor('cloud_native');
    await resolved.future.timeout(const Duration(seconds: 1));

    expect(resolvedAnchor.resolvedAnchor, nativeResolved);
    expect(platform.resolveCloudAnchorRequests.single, 'cloud_native');

    await hostedSub.cancel();
    await resolvedSub.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('ARCloudAnchorManager emits errors from native cloud operations',
      () async {
    replacePlatform(
      TestArEnginePlatform()
        ..hostCloudAnchorError = StateError('native host failed'),
    );

    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(controller);
    final failed = Completer<ARCloudAnchor>();
    final errorSub = manager.onError.listen((anchor) {
      if (!failed.isCompleted) failed.complete(anchor);
    });

    final anchor = await manager.hostAnchor(hitResult: _hit());
    final event = await failed.future.timeout(const Duration(seconds: 1));

    expect(identical(event, anchor), isTrue);
    expect(anchor.state, ARCloudAnchorState.error);
    expect(anchor.errorMessage, contains('native host failed'));

    await errorSub.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('ARCloudAnchorManager cancel and remove suppress late emissions',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(
      controller,
      hostingDelay: const Duration(milliseconds: 20),
      resolutionDelay: const Duration(milliseconds: 20),
    );
    final hostedEvents = <ARCloudAnchor>[];
    final resolvedEvents = <ARCloudAnchor>[];
    final hostedSub = manager.onHosted.listen(hostedEvents.add);
    final resolvedSub = manager.onResolved.listen(resolvedEvents.add);

    final hostingAnchor = await manager.hostAnchor(hitResult: _hit());
    await manager.cancelHosting(hostingAnchor.localId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(hostingAnchor.state, ARCloudAnchorState.none);
    expect(hostedEvents, isEmpty);
    expect(platform.removedAnchors, contains(hostingAnchor.localId));
    expect(manager.exportHostedIds(), isEmpty);

    final resolvingAnchor = await manager.resolveAnchor('cloud_to_cancel');
    await manager.removeCloudAnchor(resolvingAnchor.localId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(resolvedEvents, isEmpty);
    expect(
      manager.allCloudAnchors.map((anchor) => anchor.localId),
      isNot(contains(resolvingAnchor.localId)),
    );

    await hostedSub.cancel();
    await resolvedSub.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('ARCloudAnchorManager dispose is idempotent and blocks later access',
      () async {
    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(
      controller,
      hostingDelay: const Duration(milliseconds: 20),
      resolutionDelay: const Duration(milliseconds: 20),
    );
    final hostedEvents = <ARCloudAnchor>[];
    final resolvedEvents = <ARCloudAnchor>[];
    final hostedSub = manager.onHosted.listen(hostedEvents.add);
    final resolvedSub = manager.onResolved.listen(resolvedEvents.add);

    await manager.hostAnchor(hitResult: _hit());
    await manager.resolveAnchor('cloud_after_dispose');
    await Future.wait(<Future<void>>[
      manager.dispose(),
      manager.dispose(),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(manager.isDisposed, isTrue);
    expect(hostedEvents, isEmpty);
    expect(resolvedEvents, isEmpty);
    expect(() => manager.onHosted, throwsStateError);
    expect(() => manager.onResolved, throwsStateError);
    expect(() => manager.onError, throwsStateError);
    expect(() => manager.allCloudAnchors, throwsStateError);
    expect(manager.exportHostedIds, throwsStateError);
    await expectLater(
      manager.hostAnchor(hitResult: _hit()),
      throwsStateError,
    );
    await expectLater(manager.resolveAnchor('cloud_late'), throwsStateError);
    await expectLater(manager.cancelHosting('anchor_0'), throwsStateError);
    await expectLater(manager.removeCloudAnchor('anchor_0'), throwsStateError);

    await hostedSub.cancel();
    await resolvedSub.cancel();
    await controller.dispose();
  });

  test('ARCloudAnchorManager validates ttl and cloud id input', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(controller);

    await expectLater(
      manager.hostAnchor(hitResult: _hit(), ttlDays: -1),
      throwsRangeError,
    );
    await expectLater(
      manager.hostAnchor(hitResult: _hit(), ttlDays: 366),
      throwsRangeError,
    );
    await expectLater(manager.resolveAnchor('   '), throwsArgumentError);

    expect(platform.anchors, isEmpty);

    await manager.dispose();
    await controller.dispose();
  });

  test('ARCloudAnchorManager cleans up host anchor if disposed mid-add',
      () async {
    final addAnchorGate = Completer<void>();
    final platform = replacePlatform(
      TestArEnginePlatform(addAnchorGate: addAnchorGate),
    );

    final controller = await arHarness.createController();
    final manager = ARCloudAnchorManager(controller);

    final hostFuture = manager.hostAnchor(hitResult: _hit());
    await pumpEventQueue();

    await manager.dispose();
    addAnchorGate.complete();

    await expectLater(hostFuture, throwsStateError);
    expect(platform.removedAnchors, <String>['anchor_0']);
    expect(platform.anchors, isEmpty);

    await controller.dispose();
  });
}

ARHitTestResult _hit() => const ARHitTestResult(
      type: ARHitTestResultType.estimatedHorizontalPlane,
      worldPose: ARPose.identity(),
      distance: 1,
      planeId: 'plane_0',
    );
