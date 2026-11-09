class ARMemoryCloudAnchorRetryState {
  const ARMemoryCloudAnchorRetryState({
    this.memoryIds = const <String>{},
    this.attempt = 0,
  });

  final Set<String> memoryIds;
  final int attempt;

  bool get hasFailures => memoryIds.isNotEmpty;

  bool tracksSameFailures(Iterable<String> ids) {
    final idSet = ids.toSet();
    return memoryIds.length == idSet.length && memoryIds.containsAll(idSet);
  }
}

class ARMemoryCloudAnchorRetryDecision {
  const ARMemoryCloudAnchorRetryDecision({
    required this.state,
    required this.delay,
  });

  final ARMemoryCloudAnchorRetryState state;
  final Duration? delay;

  bool get shouldRetry => delay != null;
}

class ARMemoryCloudAnchorRetryPolicy {
  const ARMemoryCloudAnchorRetryPolicy({
    this.initialDelay = const Duration(seconds: 10),
    this.maxDelay = const Duration(minutes: 2),
  });

  final Duration initialDelay;
  final Duration maxDelay;

  ARMemoryCloudAnchorRetryDecision next({
    required Iterable<String> memoryIds,
    ARMemoryCloudAnchorRetryState current =
        const ARMemoryCloudAnchorRetryState(),
  }) {
    _validateDelays();
    final normalizedIds = Set<String>.unmodifiable(
      memoryIds.where((id) => id.trim().isNotEmpty),
    );
    if (normalizedIds.isEmpty) {
      return const ARMemoryCloudAnchorRetryDecision(
        state: ARMemoryCloudAnchorRetryState(),
        delay: null,
      );
    }

    final attempt =
        current.tracksSameFailures(normalizedIds) ? current.attempt + 1 : 1;
    final state = ARMemoryCloudAnchorRetryState(
      memoryIds: normalizedIds,
      attempt: attempt,
    );
    return ARMemoryCloudAnchorRetryDecision(
      state: state,
      delay: _delayForAttempt(attempt),
    );
  }

  Duration _delayForAttempt(int attempt) {
    final maxMicros = maxDelay.inMicroseconds;
    var delayMicros = initialDelay.inMicroseconds;
    for (var i = 1; i < attempt; i++) {
      if (delayMicros >= maxMicros) {
        return maxDelay;
      }
      delayMicros *= 2;
      if (delayMicros >= maxMicros) {
        return maxDelay;
      }
    }
    return Duration(microseconds: delayMicros);
  }

  void _validateDelays() {
    if (initialDelay <= Duration.zero) {
      throw ArgumentError.value(
        initialDelay,
        'initialDelay',
        'Must be greater than zero.',
      );
    }
    if (maxDelay < initialDelay) {
      throw ArgumentError.value(
        maxDelay,
        'maxDelay',
        'Must be greater than or equal to initialDelay.',
      );
    }
  }
}
