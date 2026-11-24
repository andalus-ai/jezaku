import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:material_ui/material_ui.dart';

/// "Signed in as ..." with Sign out. Draws nothing when nobody is signed in,
/// which is always the case in demo builds.
class AccountSettingsTile extends ConsumerWidget {
  const AccountSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider.select((s) => s.session));
    if (session == null) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const ValueKey('account_tile'),
      leading: const Icon(Icons.account_circle_outlined),
      title: const Text('Signed in'),
      subtitle: Text(session.userId),
      trailing: const Icon(Icons.logout),
      onTap: () => _confirmSignOut(context, ref),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Frames saved on this device stay here. You will need to sign in '
          'again to continue.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('sign_out_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('sign_out_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}
