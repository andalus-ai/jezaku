import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/parent/models/child_account.dart';
import 'package:jejaku/features/parent/states/parent_providers.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Controls'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          return _ChildSummaryCard(
            child: child,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildSafetyDashboardScreen(childId: child.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddChildDialog(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add Child'),
      ),
    );
  }

  Future<void> _showAddChildDialog(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_ChildDraft>(
      context: context,
      builder: (_) => const _AddChildDialog(),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    ref.read(childAccountsProvider.notifier).addChild(
          name: draft.name,
          age: draft.age,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${draft.name} child profile added.')),
    );
  }
}

class _ChildDraft {
  const _ChildDraft({
    required this.name,
    required this.age,
  });

  final String name;
  final int age;
}

class _AddChildDialog extends StatefulWidget {
  const _AddChildDialog();

  @override
  State<_AddChildDialog> createState() => _AddChildDialogState();
}

class _AddChildDialogState extends State<_AddChildDialog> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController(text: '10');
  var _showNameError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add child'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('child_name_field'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
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
            key: const ValueKey('child_age_field'),
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Age',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _addChild,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _addChild() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    Navigator.pop(
      context,
      _ChildDraft(
        name: name,
        age: int.tryParse(_ageController.text.trim()) ?? 10,
      ),
    );
  }
}

class ChildSafetyDashboardScreen extends ConsumerStatefulWidget {
  const ChildSafetyDashboardScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildSafetyDashboardScreen> createState() =>
      _ChildSafetyDashboardScreenState();
}

class _ChildSafetyDashboardScreenState
    extends ConsumerState<ChildSafetyDashboardScreen> {
  bool? _blockInappropriate;
  bool? _blockStrangers;
  bool? _requireApproval;
  bool? _hidePreciseLocation;

  @override
  Widget build(BuildContext context) {
    final child = _findChild(ref.watch(childAccountsProvider));
    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Child Safety')),
        body: const Center(child: Text('Child account not found')),
      );
    }

    _blockInappropriate ??= child.restrictions.blockInappropriate;
    _blockStrangers ??= child.restrictions.blockStrangers;
    _requireApproval ??= child.restrictions.requireFriendApproval;
    _hidePreciseLocation ??= child.restrictions.hidePreciseLocation;

    return Scaffold(
      appBar: AppBar(title: Text(child.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LocationCard(child: child),
          const SizedBox(height: 12),
          _ScreenTimeCard(
            child: child,
            onReviewExtension: () => _showExtensionRequestDialog(child),
          ),
          const SizedBox(height: 12),
          _RestrictionCard(
            blockInappropriate: _blockInappropriate!,
            blockStrangers: _blockStrangers!,
            requireApproval: _requireApproval!,
            hidePreciseLocation: _hidePreciseLocation!,
            onBlockInappropriateChanged: (value) {
              setState(() => _blockInappropriate = value);
            },
            onBlockStrangersChanged: (value) {
              setState(() => _blockStrangers = value);
            },
            onRequireApprovalChanged: (value) {
              setState(() => _requireApproval = value);
            },
            onHidePreciseLocationChanged: (value) {
              setState(() => _hidePreciseLocation = value);
            },
          ),
          const SizedBox(height: 12),
          _SafeZonesCard(
            child: child,
            onAddGeofence: () => _showAddGeofenceDialog(child),
          ),
          const SizedBox(height: 12),
          _WeeklyStatsCard(child: child),
        ],
      ),
    );
  }

  ChildAccount? _findChild(List<ChildAccount> children) {
    for (final child in children) {
      if (child.id == widget.childId) {
        return child;
      }
    }
    return null;
  }

  void _showExtensionRequestDialog(ChildAccount child) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Extension request'),
          content: Text('${child.name} is asking for 15 more minutes today.'),
          actions: [
            TextButton(
              onPressed: () {
                ref
                    .read(childAccountsProvider.notifier)
                    .denyExtensionRequest(child.id);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${child.name} extension denied.'),
                  ),
                );
              },
              child: const Text('Deny'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(childAccountsProvider.notifier)
                    .approveExtensionRequest(child.id);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${child.name} extension approved.'),
                  ),
                );
              },
              child: const Text('Approve 15 min'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddGeofenceDialog(ChildAccount child) async {
    final draft = await showDialog<_GeofenceDraft>(
      context: context,
      builder: (_) => const _AddGeofenceDialog(),
    );

    if (draft == null || !mounted) {
      return;
    }

    ref.read(childAccountsProvider.notifier).addGeofence(
          childId: child.id,
          name: draft.name,
          radiusMeters: draft.radiusMeters,
          type: draft.type,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${draft.name} geofence added.')),
    );
  }
}

class _GeofenceDraft {
  const _GeofenceDraft({
    required this.name,
    required this.radiusMeters,
    required this.type,
  });

  final String name;
  final int radiusMeters;
  final GeoFenceType type;
}

class _AddGeofenceDialog extends StatefulWidget {
  const _AddGeofenceDialog();

  @override
  State<_AddGeofenceDialog> createState() => _AddGeofenceDialogState();
}

class _AddGeofenceDialogState extends State<_AddGeofenceDialog> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '150');
  var _selectedType = GeoFenceType.safe;
  var _showNameError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add geofence'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('geofence_name_field'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
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
            key: const ValueKey('geofence_radius_field'),
            controller: _radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Radius meters',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GeoFenceType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(
                value: GeoFenceType.safe,
                child: Text('Safe zone'),
              ),
              DropdownMenuItem(
                value: GeoFenceType.alert,
                child: Text('Alert zone'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedType = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    Navigator.pop(
      context,
      _GeofenceDraft(
        name: name,
        radiusMeters: int.tryParse(_radiusController.text.trim()) ?? 150,
        type: _selectedType,
      ),
    );
  }
}

class _ChildSummaryCard extends StatelessWidget {
  const _ChildSummaryCard({
    required this.child,
    required this.onTap,
  });

  final ChildAccount child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      child.name[0],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          child.isOnline
                              ? 'Online now'
                              : 'Last active ${child.lastActiveLabel}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (child.hasPendingExtension)
                    Chip(
                      label: const Text('Request'),
                      backgroundColor: Colors.orange.shade100,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Screen time',
                      value: _formatDuration(child.todayScreenTime),
                    ),
                  ),
                  Expanded(
                    child: _MetricTile(
                      label: 'Blocked',
                      value: '${child.blockedContentToday}',
                    ),
                  ),
                  Expanded(
                    child: _MetricTile(
                      label: 'Zones',
                      value: '${child.safeZones.length}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.child});

  final ChildAccount child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Location',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 2.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.map_outlined, size: 56)),
              ),
            ),
            const SizedBox(height: 12),
            Text(child.lastKnownLocation),
          ],
        ),
      ),
    );
  }
}

class _ScreenTimeCard extends StatelessWidget {
  const _ScreenTimeCard({
    required this.child,
    required this.onReviewExtension,
  });

  final ChildAccount child;
  final VoidCallback onReviewExtension;

  @override
  Widget build(BuildContext context) {
    final used = child.todayScreenTime.inMinutes;
    final limit = child.restrictions.dailyLimit.inMinutes;
    final progress = (used / limit).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Screen Time',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text('${used}m / ${limit}m'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            if (child.hasPendingExtension) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onReviewExtension,
                icon: const Icon(Icons.check),
                label: const Text('Review Extension Request'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestrictionCard extends StatelessWidget {
  const _RestrictionCard({
    required this.blockInappropriate,
    required this.blockStrangers,
    required this.requireApproval,
    required this.hidePreciseLocation,
    required this.onBlockInappropriateChanged,
    required this.onBlockStrangersChanged,
    required this.onRequireApprovalChanged,
    required this.onHidePreciseLocationChanged,
  });

  final bool blockInappropriate;
  final bool blockStrangers;
  final bool requireApproval;
  final bool hidePreciseLocation;
  final ValueChanged<bool> onBlockInappropriateChanged;
  final ValueChanged<bool> onBlockStrangersChanged;
  final ValueChanged<bool> onRequireApprovalChanged;
  final ValueChanged<bool> onHidePreciseLocationChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text(
              'Safety Restrictions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Block inappropriate content'),
            value: blockInappropriate,
            onChanged: onBlockInappropriateChanged,
          ),
          SwitchListTile(
            title: const Text('Block unknown people'),
            value: blockStrangers,
            onChanged: onBlockStrangersChanged,
          ),
          SwitchListTile(
            title: const Text('Require friend approval'),
            value: requireApproval,
            onChanged: onRequireApprovalChanged,
          ),
          SwitchListTile(
            title: const Text('Hide precise location'),
            value: hidePreciseLocation,
            onChanged: onHidePreciseLocationChanged,
          ),
        ],
      ),
    );
  }
}

class _SafeZonesCard extends StatelessWidget {
  const _SafeZonesCard({
    required this.child,
    required this.onAddGeofence,
  });

  final ChildAccount child;
  final VoidCallback onAddGeofence;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Geofences',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              tooltip: 'Add geofence',
              icon: const Icon(Icons.add_location_alt_outlined),
              onPressed: onAddGeofence,
            ),
          ),
          for (final zone in child.safeZones)
            ListTile(
              leading: Icon(
                zone.type == GeoFenceType.safe
                    ? Icons.shield_outlined
                    : Icons.warning_amber,
              ),
              title: Text(zone.name),
              subtitle: Text('${zone.radiusMeters} m radius'),
            ),
        ],
      ),
    );
  }
}

class _WeeklyStatsCard extends StatelessWidget {
  const _WeeklyStatsCard({required this.child});

  final ChildAccount child;

  @override
  Widget build(BuildContext context) {
    final stats = child.weeklyStats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Photos',
                    value: '${stats.photosCaptured}',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Places',
                    value: '${stats.locationsVisited}',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Comments',
                    value: '${stats.commentsPosted}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}
