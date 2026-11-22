import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_policy.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';

/// The rules the AR viewer applies. Override in tests or to change the rule
/// set for a build; do not filter frames anywhere else.
final frameVisibilityPolicyProvider = Provider<FrameVisibilityPolicy>(
  (ref) => FrameVisibilityPolicy.standard(),
);

/// Who is looking. Replace with a context fed by the backend (owner id,
/// friends) when other people's frames reach the client.
final frameViewerContextProvider = Provider<FrameViewerContext>(
  (ref) => const FrameViewerContext.localStore(),
);
