import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_rules_mode.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_providers.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';

/// Whether the app must show sign-in before anything else.
///
/// Production (strict) builds require it; demo and prototype builds bypass it
/// so the UI and AR objects stay usable offline. It also stays off while the
/// build has no identity service, so a strict build without one keeps
/// working. The client gate is a convenience: the backend is what actually
/// refuses unauthenticated requests.
final signInRequiredProvider = Provider<bool>((ref) {
  return ref.watch(frameRulesModeProvider) == FrameRulesMode.strict &&
      ref.watch(authGatewayProvider).isAvailable;
});
