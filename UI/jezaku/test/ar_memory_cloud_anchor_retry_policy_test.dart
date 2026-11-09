import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_retry_policy.dart';

void main() {
  test('empty failures clear retry state', () {
    const policy = ARMemoryCloudAnchorRetryPolicy();
    const current = ARMemoryCloudAnchorRetryState(
      memoryIds: {'memory'},
      attempt: 2,
    );

    final decision = policy.next(
      memoryIds: const <String>[],
      current: current,
    );

    expect(decision.shouldRetry, isFalse);
    expect(decision.delay, isNull);
    expect(decision.state.hasFailures, isFalse);
    expect(decision.state.attempt, 0);
  });

  test('first retry uses the initial delay', () {
    const policy = ARMemoryCloudAnchorRetryPolicy(
      initialDelay: Duration(seconds: 5),
      maxDelay: Duration(seconds: 30),
    );

    final decision = policy.next(memoryIds: const {'memory'});

    expect(decision.shouldRetry, isTrue);
    expect(decision.delay, const Duration(seconds: 5));
    expect(decision.state.memoryIds, {'memory'});
    expect(decision.state.attempt, 1);
  });

  test('same failures back off until the max delay', () {
    const policy = ARMemoryCloudAnchorRetryPolicy(
      initialDelay: Duration(seconds: 5),
      maxDelay: Duration(seconds: 20),
    );

    final first = policy.next(memoryIds: const {'memory'});
    final second = policy.next(
      memoryIds: const {'memory'},
      current: first.state,
    );
    final third = policy.next(
      memoryIds: const {'memory'},
      current: second.state,
    );
    final fourth = policy.next(
      memoryIds: const {'memory'},
      current: third.state,
    );

    expect(first.delay, const Duration(seconds: 5));
    expect(second.delay, const Duration(seconds: 10));
    expect(third.delay, const Duration(seconds: 20));
    expect(fourth.delay, const Duration(seconds: 20));
    expect(fourth.state.attempt, 4);
  });

  test('same failure set ignores ordering', () {
    const policy = ARMemoryCloudAnchorRetryPolicy(
      initialDelay: Duration(seconds: 5),
      maxDelay: Duration(seconds: 30),
    );

    final first = policy.next(memoryIds: const {'a', 'b'});
    final second = policy.next(
      memoryIds: const {'b', 'a'},
      current: first.state,
    );

    expect(second.delay, const Duration(seconds: 10));
    expect(second.state.attempt, 2);
  });

  test('new failure set resets the backoff attempt', () {
    const policy = ARMemoryCloudAnchorRetryPolicy(
      initialDelay: Duration(seconds: 5),
      maxDelay: Duration(seconds: 30),
    );

    final first = policy.next(memoryIds: const {'a'});
    final second = policy.next(
      memoryIds: const {'a'},
      current: first.state,
    );
    final newSet = policy.next(
      memoryIds: const {'b'},
      current: second.state,
    );

    expect(second.delay, const Duration(seconds: 10));
    expect(newSet.delay, const Duration(seconds: 5));
    expect(newSet.state.attempt, 1);
    expect(newSet.state.memoryIds, {'b'});
  });

  test('blank memory ids are ignored', () {
    const policy = ARMemoryCloudAnchorRetryPolicy();

    final decision = policy.next(memoryIds: const {'memory', '', '  '});

    expect(decision.state.memoryIds, {'memory'});
    expect(decision.state.attempt, 1);
  });

  test('validates retry delay configuration when used', () {
    const zeroInitial = ARMemoryCloudAnchorRetryPolicy(
      initialDelay: Duration.zero,
    );
    const maxBeforeInitial = ARMemoryCloudAnchorRetryPolicy(
      initialDelay: Duration(seconds: 10),
      maxDelay: Duration(seconds: 5),
    );

    expect(
      () => zeroInitial.next(memoryIds: const {'memory'}),
      throwsArgumentError,
    );
    expect(
      () => maxBeforeInitial.next(memoryIds: const {'memory'}),
      throwsArgumentError,
    );
  });
}
