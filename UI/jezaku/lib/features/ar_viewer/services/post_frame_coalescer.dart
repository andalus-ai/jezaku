
import 'package:flutter/widgets.dart';

/// Runs [action] after the next frame, collapsing repeated requests made
/// before that frame into one run.
class PostFrameCoalescer {
  PostFrameCoalescer({
    required this.action,
    void Function(VoidCallback callback)? postFrame,
  }) : _postFrame = postFrame ?? _bindingPostFrame;

  final VoidCallback action;
  final void Function(VoidCallback callback) _postFrame;
  bool _scheduled = false;

  bool get isScheduled => _scheduled;

  void schedule() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    _postFrame(() {
      // Clear first so the action may schedule the next run itself.
      _scheduled = false;
      action();
    });
  }

  /// Forgets a pending request. A callback already queued still fires, but
  /// [action] guards its own liveness, as the screen does with `mounted`.
  void reset() => _scheduled = false;

  static void _bindingPostFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }
}
