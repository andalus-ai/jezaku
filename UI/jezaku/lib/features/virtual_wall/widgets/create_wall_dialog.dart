import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/virtual_wall/widgets/manage_linked_anchors_dialog.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_route_authoring_widgets.dart';
import 'package:material_ui/material_ui.dart';

class WallDraft {
  const WallDraft({
    required this.title,
    required this.description,
    required this.isPublic,
    required this.linkedMemoryIds,
  });

  final String title;
  final String description;
  final bool isPublic;
  final List<String> linkedMemoryIds;
}

class CreateWallDialog extends ConsumerStatefulWidget {
  const CreateWallDialog({required this.availableMemories, super.key});

  final List<AnchorMemory> availableMemories;

  @override
  ConsumerState<CreateWallDialog> createState() => _CreateWallDialogState();
}

class _CreateWallDialogState extends ConsumerState<CreateWallDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedMemoryIds = <String>[];
  var _isPublic = true;
  var _showTitleError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
      title: const Text('Create wall'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('wall_title_field'),
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                errorText: _showTitleError ? 'Title required' : null,
              ),
              onChanged: (_) {
                if (_showTitleError) {
                  setState(() => _showTitleError = false);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('wall_description_field'),
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.public),
                  label: Text('Public'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.group),
                  label: Text('Group'),
                ),
              ],
              selected: {_isPublic},
              onSelectionChanged: (selection) {
                setState(() => _isPublic = selection.first);
              },
            ),
            if (widget.availableMemories.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (selectedMemories.isNotEmpty) ...[
                LinkedAnchorRouteOrderEditor(
                  keyPrefix: 'create_wall',
                  selectedMemories: selectedMemories,
                  onOptimizeNearestFirst: _selectedMemoryIds.length < 2
                      ? null
                      : _optimizeNearestFirst,
                  onMoveEarlier: _moveEarlier,
                  onMoveLater: _moveLater,
                ),
                const Divider(height: 24),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Linked anchors',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final memory in widget.availableMemories)
                      FilterChip(
                        key: ValueKey('wall_anchor_option_${memory.id}'),
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
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _createWall,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _createWall() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      return;
    }

    Navigator.pop(
      context,
      WallDraft(
        title: title,
        description: _descriptionController.text,
        isPublic: _isPublic,
        linkedMemoryIds: List<String>.unmodifiable(_selectedMemoryIds),
      ),
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
