import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:material_ui/material_ui.dart';

/// What to tell the user about a failed sign-in. Never says which of the
/// identifier or the password was wrong.
String authFailureMessage(AuthFailureReason reason) {
  return switch (reason) {
    AuthFailureReason.invalidCredentials =>
      "Those details didn't match an active account. Check them and try again.",
    AuthFailureReason.network =>
      "Can't reach Jezaku. Check your connection and try again.",
    AuthFailureReason.server =>
      'Something went wrong on our side. Try again in a moment.',
    AuthFailureReason.unavailable => "Sign-in isn't available in this build.",
    AuthFailureReason.sessionRejected =>
      'Your session ended. Sign in again to continue.',
  };
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _missingInput = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _missingInput = true);
      return;
    }
    setState(() => _missingInput = false);
    await ref.read(authControllerProvider.notifier).signIn(
          identifier: _identifier.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final error = _missingInput
        ? 'Enter your email or username and your password.'
        : auth.failure == null
            ? null
            : authFailureMessage(auth.failure!.reason);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.view_in_ar_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to Jezaku',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('sign_in_identifier'),
                      controller: _identifier,
                      enabled: !auth.busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email or username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('sign_in_password'),
                      controller: _password,
                      enabled: !auth.busy,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          key: const ValueKey('sign_in_show_password'),
                          tooltip:
                              _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          key: const ValueKey('sign_in_error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('sign_in_submit'),
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
