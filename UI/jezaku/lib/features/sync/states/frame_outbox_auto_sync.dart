import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';

/// Keeps the outbox moving while the app is open: sends what is waiting when
/// the app starts, when a user signs in or changes, and whenever the app comes
/// back to the foreground (the usual moment a device has a connection again).
/// The controller adds its own timer for frames that are waiting out a delay.
///
/// There is no connectivity plugin on purpose: a failed call is the signal
/// that the device is offline, so the outbox never guesses wrong.
final frameOutboxAutoSyncProvider = Provider<void>((ref) {
  final controller = ref.read(frameOutboxControllerProvider.notifier);
  if (!controller.isActive) {
    return;
  }

  ref.listen<String?>(
    signedInUserIdProvider,
    (previous, userId) {
      // Not signed in at start (the saved session may still be loading):
      // nothing changed, so do not mark frames as waiting for a sign-in.
      if (previous == null && userId == null) {
        return;
      }
      unawaited(controller.onSignedInChanged(userId));
    },
    fireImmediately: true,
  );

  final observer = _ResumeObserver(
    onResumed: () => unawaited(controller.syncNow()),
  );
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
