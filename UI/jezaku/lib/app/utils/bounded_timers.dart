import 'dart:async';

/// Time-limits futures like [Future.timeout], but the timers are owned by this
/// object so [cancelAll] can stop them when the owner (a screen or provider)
/// goes away. A slow platform call can then never leave a timer running past
/// its owner. Futures whose timers were cancelled simply never complete.
class BoundedTimers {
  final Set<Timer> _timers = <Timer>{};

  Future<T> run<T>(
    Future<T> operation,
    Duration limit, {
    T Function()? onTimeout,
  }) {
    final completer = Completer<T>();
    late final Timer timer;
    timer = Timer(limit, () {
      _timers.remove(timer);
      if (completer.isCompleted) {
        return;
      }
      if (onTimeout != null) {
        completer.complete(onTimeout());
      } else {
        completer.completeError(TimeoutException('Timed out', limit));
      }
    });
    _timers.add(timer);
    operation.then<void>(
      (value) {
        timer.cancel();
        _timers.remove(timer);
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        timer.cancel();
        _timers.remove(timer);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future;
  }

  void cancelAll() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
