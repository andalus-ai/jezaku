import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_rules_mode.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_policy.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/friends/states/friends_controller.dart';

/// Demo or strict rules for this build. Override in tests.
final frameRulesModeProvider = Provider<FrameRulesMode>(
  (ref) => FrameRulesMode.current,
);

/// The rules the AR viewer applies. Override in tests or to change the rule
/// set for a build; do not filter frames anywhere else.
final frameVisibilityPolicyProvider = Provider<FrameVisibilityPolicy>(
  (ref) => FrameVisibilityPolicy.forMode(ref.watch(frameRulesModeProvider)),
);

/// The signed-in user's id, or null while nobody is signed in (always, in demo
/// builds, which bypass sign-in).
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(signedInUserIdProvider),
);

/// The ids of the viewer's friends, from the social service (empty until the
/// first answer, and always in builds without a social service).
final friendIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(friendsProvider.select((state) => state.ids)),
);

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
