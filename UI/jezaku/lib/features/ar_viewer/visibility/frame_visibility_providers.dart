import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_rules_mode.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_policy.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';

/// Demo or strict rules for this build. Override in tests.
final frameRulesModeProvider = Provider<FrameRulesMode>(
  (ref) => FrameRulesMode.current,
);

/// The rules the AR viewer applies. Override in tests or to change the rule
/// set for a build; do not filter frames anywhere else.
final frameVisibilityPolicyProvider = Provider<FrameVisibilityPolicy>(
  (ref) => FrameVisibilityPolicy.forMode(ref.watch(frameRulesModeProvider)),
);

/// The signed-in user's id, or null until the app has an identity. Feed this
/// from the identity service when the client is connected to the backend.
final currentUserIdProvider = Provider<String?>((ref) => null);

/// The ids of the viewer's friends. Feed this from the social service when the
/// client is connected to the backend.
final friendIdsProvider = Provider<Set<String>>((ref) => const <String>{});

/// Who is looking. In demo mode everyone who is not the owner counts as a
/// friend.
final frameViewerContextProvider = Provider<FrameViewerContext>((ref) {
  final real = FrameViewerContext.forUser(
    userId: ref.watch(currentUserIdProvider),
    friendIds: ref.watch(friendIdsProvider),
  );
  return switch (ref.watch(frameRulesModeProvider)) {
    FrameRulesMode.strict => real,
    FrameRulesMode.demo => FrameViewerContext.everyoneIsAFriend(real),
  };
});
