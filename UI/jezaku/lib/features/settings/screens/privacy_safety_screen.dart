import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';

class PrivacySafetyScreen extends ConsumerWidget {
  const PrivacySafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and safety')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _PrivacySectionHeader(title: 'Sharing'),
          SwitchListTile(
            key: const ValueKey('share_precise_location_switch'),
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('Precise location sharing'),
            subtitle: const Text(
              'Show exact coordinates on newly published memories',
            ),
            value: settings.sharePreciseLocation,
            onChanged: controller.setSharePreciseLocation,
          ),
          SwitchListTile(
            key: const ValueKey('comments_default_switch'),
            secondary: const Icon(Icons.mode_comment_outlined),
            title: const Text('Comments by default'),
            subtitle: const Text('Start newly published memories with replies'),
            value: settings.commentsEnabledByDefault,
            onChanged: controller.setCommentsEnabledByDefault,
          ),
          SwitchListTile(
            key: const ValueKey('profile_discoverable_switch'),
            secondary: const Icon(Icons.travel_explore_outlined),
            title: const Text('Discoverable profile'),
            subtitle: const Text('Let nearby friends find your public anchors'),
            value: settings.profileDiscoverable,
            onChanged: controller.setProfileDiscoverable,
          ),
          const Divider(),
          const _PrivacySectionHeader(title: 'Blocked accounts'),
          if (settings.blockedAccounts.isEmpty)
            const ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('No blocked accounts'),
              subtitle: Text('Accounts you block will appear here'),
            )
          else
            for (final account in settings.blockedAccounts)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: Text(account),
                subtitle: const Text('Cannot view or comment on your anchors'),
                trailing: TextButton(
                  key: ValueKey('unblock_account_${_accountKey(account)}'),
                  onPressed: () => _unblockAccount(
                    context,
                    controller.unblockAccount,
                    account,
                  ),
                  child: const Text('Unblock'),
                ),
              ),
          const Divider(),
          const _PrivacySectionHeader(title: 'Review'),
          ListTile(
            leading: Icon(
              settings.privateByDefault
                  ? Icons.lock_outline
                  : Icons.public_outlined,
            ),
            title: const Text('Memory visibility'),
            subtitle: Text(
              settings.privateByDefault
                  ? 'New memories start private'
                  : 'New memories start public',
            ),
          ),
          ListTile(
            leading: Icon(
              settings.highAccuracyMode ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
            title: const Text('Anchor precision'),
            subtitle: Text(
              settings.highAccuracyMode
                  ? 'High accuracy anchoring is enabled'
                  : 'Standard anchoring is enabled',
            ),
          ),
        ],
      ),
    );
  }

  void _unblockAccount(
    BuildContext context,
    void Function(String accountName) unblockAccount,
    String account,
  ) {
    unblockAccount(account);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('$account unblocked.')),
      );
  }
}

class _PrivacySectionHeader extends StatelessWidget {
  const _PrivacySectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _accountKey(String account) {
  return account
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
