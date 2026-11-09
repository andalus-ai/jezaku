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

  test('ARAnimationPlayer dispose is idempotent and blocks later access',
      () async {
    final controller = await arHarness.createController();
    final player = ARAnimationPlayer(controller);
    const node = ARNode(id: 'animated_node');

    player.trackNode(node);
    final animationId = player.play(
      ARAnimation.moveTo(
        nodeId: node.id,
        from: const ARVector3.zero(),
        to: const ARVector3.one(),
        duration: 5,
      ),
    );

    expect(player.isDisposed, isFalse);
    expect(player.isPlaying(animationId), isTrue);

    player.dispose();
    player.dispose();
    await pumpEventQueue();

    expect(player.isDisposed, isTrue);
    expect(() => player.onAnimationComplete, throwsStateError);
    expect(() => player.getTracked(node.id), throwsStateError);
    expect(() => player.trackNode(node), throwsStateError);
    expect(() => player.stop(animationId), throwsStateError);
    expect(
      () => player.play(
        ARAnimation.popIn(nodeId: node.id),
      ),
      throwsStateError,
    );

    await controller.dispose();
  });

  test('ARPhysicsWorld dispose is idempotent and blocks later access',
      () async {
    final controller = await arHarness.createController();
    final world = ARPhysicsWorld(controller);
    final body = ARPhysicsBody(
      nodeId: 'physics_node',
      initialPosition: const ARVector3.zero(),
    );

    world.addBody(body);
    world.setGravity(const ARVector3(0, -1, 0));
    world.setGroundPlane(-0.5);

    expect(world.isDisposed, isFalse);
    expect(world.bodyCount, 1);
    expect(world.gravity.y, -1);
    expect(world.groundY, -0.5);

    world.dispose();
    world.dispose();
    await pumpEventQueue();

    expect(world.isDisposed, isTrue);
    expect(() => world.bodyCount, throwsStateError);
    expect(() => world.gravity, throwsStateError);
    expect(() => world.groundY, throwsStateError);
    expect(() => world.onCollision, throwsStateError);
    expect(() => world.addBody(body), throwsStateError);
    expect(
      () => world.applyImpulse('physics_node', ARVector3.up),
      throwsStateError,
    );

    await controller.dispose();
  });
}
