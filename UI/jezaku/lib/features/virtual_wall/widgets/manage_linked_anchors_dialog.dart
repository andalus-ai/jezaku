import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_route_authoring_widgets.dart';
import 'package:material_ui/material_ui.dart';

class ManageLinkedAnchorsDialog extends ConsumerStatefulWidget {
  const ManageLinkedAnchorsDialog({
    required this.availableMemories,
    required this.selectedMemoryIds,
    super.key,
  });

  final List<AnchorMemory> availableMemories;
  final List<String> selectedMemoryIds;

  @override
  ConsumerState<ManageLinkedAnchorsDialog> createState() =>
      _ManageLinkedAnchorsDialogState();
}

class _ManageLinkedAnchorsDialogState
    extends ConsumerState<ManageLinkedAnchorsDialog> {
  late final List<String> _selectedMemoryIds = [
    ...normalizeLinkedMemoryIds(widget.selectedMemoryIds),
  ];

  @override
  Widget build(BuildContext context) {
    final memoriesById = {
      for (final memory in widget.availableMemories) memory.id: memory,
    };
    final selectedMemories = [
      for (final memoryId in _selectedMemoryIds)
        if (memoriesById[memoryId] != null) memoriesById[memoryId]!,
    ];

    return AlertDialog(
      title: const Text('Manage linked anchors'),
      content: widget.availableMemories.isEmpty
          ? const Text('No nearby anchors available.')
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedMemories.isNotEmpty) ...[
                    LinkedAnchorRouteOrderEditor(
                      keyPrefix: 'manage_wall',
                      selectedMemories: selectedMemories,
                      onOptimizeNearestFirst: selectedMemories.length < 2
                          ? null
                          : _optimizeNearestFirst,
                      onMoveEarlier: _moveEarlier,
                      onMoveLater: _moveLater,
                    ),
                    const Divider(height: 24),
                  ],
                  Text(
                    'Available anchors',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final memory in widget.availableMemories)
                        FilterChip(
                          key: ValueKey('manage_wall_anchor_${memory.id}'),
                          avatar: Icon(
                            memory.isPrivate
                                ? Icons.lock_outline
                                : Icons.place_outlined,
                            size: 18,
                          ),
                          label: Text(memory.title),
                          selected: _selectedMemoryIds.contains(memory.id),
                          onSelected: (selected) =>
                              _toggleMemory(memory.id, selected),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('clear_wall_anchor_links'),
          onPressed: () => setState(_selectedMemoryIds.clear),
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              List<String>.unmodifiable(_selectedMemoryIds),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _toggleMemory(String memoryId, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedMemoryIds.contains(memoryId)) {
          _selectedMemoryIds.add(memoryId);
        }
      } else {
        _selectedMemoryIds.remove(memoryId);
      }
    });
  }

  void _moveEarlier(String memoryId) {
    setState(() => moveWallMemoryId(_selectedMemoryIds, memoryId, -1));
  }

  void _moveLater(String memoryId) {
    setState(() => moveWallMemoryId(_selectedMemoryIds, memoryId, 1));
  }

  void _optimizeNearestFirst() {
    final orderedMemories = nearestFirstWallMemories(
      memoryIds: _selectedMemoryIds,
      availableMemories: widget.availableMemories,
      origin: ref.read(viewerLocationProvider),
    );

    setState(() {
      _selectedMemoryIds
        ..clear()
        ..addAll([
          for (final memory in orderedMemories) memory.id,
        ]);
    });
  }
}

List<AnchorMemory> nearestFirstWallMemories({
  required List<String> memoryIds,
  required List<AnchorMemory> availableMemories,
  required ViewerLocation origin,
}) {
  final memoriesById = {
    for (final memory in availableMemories) memory.id: memory,
  };
  final selectedMemories = [
    for (final memoryId in memoryIds)
      if (memoriesById[memoryId] != null) memoriesById[memoryId]!,
  ];

  return wallTrailMemoriesFor(
    selectedMemories,
    originLatitude: origin.latitude,
    originLongitude: origin.longitude,
  );
}
