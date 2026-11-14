part of '../profile_screen.dart';

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                profile.initial,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(profile.handle),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.displayName,
    required this.handle,
  });

  final String displayName;
  final String handle;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _nameController = TextEditingController(
    text: widget.profile.displayName,
  );
  late final _handleController = TextEditingController(
    text: widget.profile.handle,
  );
  var _showNameError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('profile_name_field'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display name',
              errorText: _showNameError ? 'Name required' : null,
            ),
            onChanged: (_) {
              if (_showNameError) {
                setState(() => _showNameError = false);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('profile_handle_field'),
            controller: _handleController,
            decoration: const InputDecoration(labelText: 'Handle'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveProfile,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveProfile() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    Navigator.pop(
      context,
      _ProfileDraft(
        displayName: displayName,
        handle: _handleController.text,
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatCard(label: 'Memories', value: '128')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Walls', value: '12')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Friends', value: '430')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTileActionButton extends StatelessWidget {
  const _FeatureTileActionButton({
    required this.buttonKey,
    required this.action,
  });

  final Key buttonKey;
  final _TrailGoalAction action;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: buttonKey,
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progressKey,
    this.progressLabelKey,
    this.progressLabel,
    this.progressCaptionKey,
    this.progressCaption,
    this.footer,
    this.progressValue,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key? progressKey;
  final Key? progressLabelKey;
  final String? progressLabel;
  final Key? progressCaptionKey;
  final String? progressCaption;
  final Widget? footer;
  final double? progressValue;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final progressValue = this.progressValue;
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: progressValue == null
            ? Text(subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          key: progressKey,
                          value: progressValue.clamp(0.0, 1.0).toDouble(),
                        ),
                      ),
                      if (progressLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          progressLabel!,
                          key: progressLabelKey,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                  if (progressCaption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      progressCaption!,
                      key: progressCaptionKey,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 4),
                    footer!,
                  ],
                ],
              ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
