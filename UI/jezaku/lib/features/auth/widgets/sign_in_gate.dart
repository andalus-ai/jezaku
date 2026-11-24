import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/screens/sign_in_screen.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/auth/states/sign_in_requirement.dart';
import 'package:material_ui/material_ui.dart';

/// Shows [child] (the app) once the user is signed in, or straight away when
/// this build does not require sign-in (demo builds, or no identity service).
/// Signing out brings the sign-in screen back.
class SignInGate extends ConsumerWidget {
  const SignInGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(signInRequiredProvider);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!required || signedIn) {
      return child;
    }
    // Own navigator: the gate sits above the app's, which is not built yet.
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const SignInScreen(),
      ),
    );
  }
}
