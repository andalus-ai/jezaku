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

/// Who is looking. Replace with a context fed by the backend (owner id,
/// friends) when other people's frames reach the client. In demo mode
/// everyone who is not the owner counts as a friend.
final frameViewerContextProvider = Provider<FrameViewerContext>((ref) {
  const local = FrameViewerContext.localStore();
  return switch (ref.watch(frameRulesModeProvider)) {
    FrameRulesMode.strict => local,
    FrameRulesMode.demo => FrameViewerContext.everyoneIsAFriend(local),
  };
});
