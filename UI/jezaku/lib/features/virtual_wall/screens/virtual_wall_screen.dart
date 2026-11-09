import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jejaku/features/virtual_wall/widgets/ar_wall_card.dart';

class VirtualWallScreen extends ConsumerStatefulWidget {
  const VirtualWallScreen({super.key});

  @override
  ConsumerState<VirtualWallScreen> createState() => _VirtualWallScreenState();
}

class _VirtualWallScreenState extends ConsumerState<VirtualWallScreen> {
  ARWallFilter _filter = ARWallFilter.nearby;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final walls = ref.watch(
      visibleARWallsProvider((filter: _filter, query: _query)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Walls'),
        actions: [
          IconButton(
            tooltip: 'Search walls',
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear wall search',
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in ARWallFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          if (_query.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: InputChip(
                  label: Text(_query),
                  onDeleted: () {
                    setState(() => _query = '');
                  },
                ),
              ),
            ),
          Expanded(
            child: walls.isEmpty
                ? _EmptyWallFilterState(filter: _filter, query: _query)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: walls.length,
                    itemBuilder: (context, index) {
                      final wall = walls[index];
                      final linkedMemories =
                          ref.watch(wallLinkedMemoriesProvider(wall.id));
                      final trailPreview = wallTrailPreviewFor(
                        linkedMemories,
                        originLatitude: viewerLatitude,
                        originLongitude: viewerLongitude,
                        optimizeFromOrigin: true,
                      );
                      return ARWallCard(
                        wall: wall,
                        trailPreview: trailPreview,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.virtualWallDetails,
                            arguments: wall.id,
                          );
                        },
                        onStartTrail: trailPreview == null
                            ? null
                            : () => _startWallTrail(
                                  context,
                                  wall,
                                  trailPreview,
                                ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateWallDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final query = await showDialog<String>(
      context: context,
      builder: (_) => _WallSearchDialog(initialQuery: _query),
    );

    if (query == null || !mounted) {
      return;
    }

    setState(() => _query = query.trim());
  }

  Future<void> _showCreateWallDialog() async {
    final draft = await showDialog<_WallDraft>(
      context: context,
      builder: (_) => _CreateWallDialog(
        availableMemories: ref.read(nearbyAnchorsProvider),
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).createWall(
          title: draft.title,
          description: draft.description,
          isPublic: draft.isPublic,
          linkedMemoryIds: draft.linkedMemoryIds,
        );
    setState(() => _filter = ARWallFilter.nearby);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${draft.title} wall created.')),
    );
  }

  void _startWallTrail(
    BuildContext context,
    ARWall wall,
    WallTrailPreview preview,
  ) {
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(
        ARTrailSession.fromMemoryIds(
          title: '${wall.title} trail',
          memoryIds: preview.orderedMemoryIds,
          source: ARTrailSource.virtualWall,
          sourceWallId: wall.id,
        ),
      ),
    );
  }
}

class _WallSearchDialog extends StatefulWidget {
  const _WallSearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_WallSearchDialog> createState() => _WallSearchDialogState();
}

class _WallSearchDialogState extends State<_WallSearchDialog> {
  late final _queryController = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search walls'),
      content: TextField(
        key: const ValueKey('wall_search_field'),
        controller: _queryController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          labelText: 'Title or description',
        ),
        onSubmitted: (_) => _applySearch(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: _applySearch,
          child: const Text('Search'),
        ),
      ],
    );
  }

  void _applySearch() {
    Navigator.pop(context, _queryController.text);
  }
}

class _WallDraft {
  const _WallDraft({
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

class _CreateWallDialog extends StatefulWidget {
  const _CreateWallDialog({required this.availableMemories});

  final List<AnchorMemory> availableMemories;

  @override
  State<_CreateWallDialog> createState() => _CreateWallDialogState();
}

class _CreateWallDialogState extends State<_CreateWallDialog> {
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
                _LinkedAnchorRouteOrderEditor(
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
      _WallDraft(
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
    setState(() => _moveMemoryId(_selectedMemoryIds, memoryId, -1));
  }

  void _moveLater(String memoryId) {
    setState(() => _moveMemoryId(_selectedMemoryIds, memoryId, 1));
  }

  void _optimizeNearestFirst() {
    final orderedMemories = _nearestFirstMemories(
      memoryIds: _selectedMemoryIds,
      availableMemories: widget.availableMemories,
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

class _ManageLinkedAnchorsDialog extends StatefulWidget {
  const _ManageLinkedAnchorsDialog({
    required this.availableMemories,
    required this.selectedMemoryIds,
  });

  final List<AnchorMemory> availableMemories;
  final List<String> selectedMemoryIds;

  @override
  State<_ManageLinkedAnchorsDialog> createState() =>
      _ManageLinkedAnchorsDialogState();
}

class _ManageLinkedAnchorsDialogState
    extends State<_ManageLinkedAnchorsDialog> {
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
                    _LinkedAnchorRouteOrderEditor(
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
    setState(() => _moveMemoryId(_selectedMemoryIds, memoryId, -1));
  }

  void _moveLater(String memoryId) {
    setState(() => _moveMemoryId(_selectedMemoryIds, memoryId, 1));
  }

  void _optimizeNearestFirst() {
    final orderedMemories = _nearestFirstMemories(
      memoryIds: _selectedMemoryIds,
      availableMemories: widget.availableMemories,
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

class _LinkedAnchorRouteOrderEditor extends StatelessWidget {
  const _LinkedAnchorRouteOrderEditor({
    required this.keyPrefix,
    required this.selectedMemories,
    required this.onOptimizeNearestFirst,
    required this.onMoveEarlier,
    required this.onMoveLater,
  });

  final String keyPrefix;
  final List<AnchorMemory> selectedMemories;
  final VoidCallback? onOptimizeNearestFirst;
  final ValueChanged<String> onMoveEarlier;
  final ValueChanged<String> onMoveLater;

  @override
  Widget build(BuildContext context) {
    final preview = wallTrailPreviewFor(
      selectedMemories,
      originLatitude: viewerLatitude,
      originLongitude: viewerLongitude,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Trail order',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton.icon(
              key: ValueKey('${keyPrefix}_optimize_nearest_first'),
              onPressed: onOptimizeNearestFirst,
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Nearest first'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview != null) ...[
          _RouteAuthoringPreview(
            keyPrefix: keyPrefix,
            preview: preview,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < selectedMemories.length; index++)
              _RouteOrderChip(
                keyPrefix: keyPrefix,
                memory: selectedMemories[index],
                index: index,
                total: selectedMemories.length,
                onMoveEarlier: onMoveEarlier,
                onMoveLater: onMoveLater,
              ),
          ],
        ),
      ],
    );
  }
}

class _RouteAuthoringPreview extends StatelessWidget {
  const _RouteAuthoringPreview({
    required this.keyPrefix,
    required this.preview,
  });

  final String keyPrefix;
  final WallTrailPreview preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: ValueKey('${keyPrefix}_route_preview'),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined,
                    color: colorScheme.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preview.routeSummaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              preview.startEndLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _RoutePreviewChip(
                  icon: Icons.near_me_outlined,
                  label: preview.startDistanceLabel,
                ),
                _RoutePreviewChip(
                  icon: Icons.directions_walk,
                  label: preview.walkTimeLabel,
                ),
                _RoutePreviewChip(
                  icon: preview.hasPrivateStops
                      ? Icons.lock_outline
                      : Icons.public,
                  label: preview.privacyLabel,
                ),
                _RoutePreviewChip(
                  icon: preview.hasCalibrationReviews
                      ? Icons.warning_amber
                      : Icons.verified_outlined,
                  label: preview.anchorHealthLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePreviewChip extends StatelessWidget {
  const _RoutePreviewChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RouteOrderChip extends StatelessWidget {
  const _RouteOrderChip({
    required this.keyPrefix,
    required this.memory,
    required this.index,
    required this.total,
    required this.onMoveEarlier,
    required this.onMoveLater,
  });

  final String keyPrefix;
  final AnchorMemory memory;
  final int index;
  final int total;
  final ValueChanged<String> onMoveEarlier;
  final ValueChanged<String> onMoveLater;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('${keyPrefix}_route_order_${memory.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              child: Text('${index + 1}'),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                memory.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: ValueKey('${keyPrefix}_route_move_earlier_${memory.id}'),
              tooltip: 'Move ${memory.title} earlier',
              onPressed: index == 0 ? null : () => onMoveEarlier(memory.id),
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              key: ValueKey('${keyPrefix}_route_move_later_${memory.id}'),
              tooltip: 'Move ${memory.title} later',
              onPressed:
                  index == total - 1 ? null : () => onMoveLater(memory.id),
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

void _moveMemoryId(List<String> memoryIds, String memoryId, int delta) {
  final index = memoryIds.indexOf(memoryId);
  if (index == -1) {
    return;
  }
  final newIndex = (index + delta).clamp(0, memoryIds.length - 1).toInt();
  if (newIndex == index) {
    return;
  }
  final removedMemoryId = memoryIds.removeAt(index);
  memoryIds.insert(newIndex, removedMemoryId);
}

List<AnchorMemory> _nearestFirstMemories({
  required List<String> memoryIds,
  required List<AnchorMemory> availableMemories,
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
    originLatitude: viewerLatitude,
    originLongitude: viewerLongitude,
  );
}

class _EmptyWallFilterState extends StatelessWidget {
  const _EmptyWallFilterState({
    required this.filter,
    required this.query,
  });

  final ARWallFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view, color: colorScheme.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'No ${filter.label.toLowerCase()} walls'
                  : 'No matching walls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Create or join a wall to see it in this view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class VirtualWallDetailScreen extends ConsumerWidget {
  const VirtualWallDetailScreen({super.key, required this.wallId});

  final String wallId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wall = _findWall(ref.watch(arWallsProvider));
    final linkedMemories = ref.watch(wallLinkedMemoriesProvider(wallId));
    final availableMemories = ref.watch(nearbyAnchorsProvider);
    if (wall == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Virtual Wall')),
        body: const Center(child: Text('Wall not found')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(wall.title),
          actions: [
            IconButton(
              tooltip: 'Manage linked anchors',
              icon: const Icon(Icons.hub_outlined),
              onPressed: () => _showManageLinkedAnchorsDialog(
                context,
                ref,
                wall,
                availableMemories,
              ),
            ),
            IconButton(
              tooltip: 'Invite members',
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => _showInviteMemberDialog(context, ref, wall),
            ),
            IconButton(
              tooltip: 'QR code',
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showQrCode(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Wall'),
              Tab(text: 'Members'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _WallOverviewTab(
              wall: wall,
              linkedMemories: linkedMemories,
            ),
            _MembersList(
              memberCount: wall.memberCount,
              memberCountLabel: wall.memberCountLabel,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddItemDialog(context, ref, wall),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _showManageLinkedAnchorsDialog(
    BuildContext context,
    WidgetRef ref,
    ARWall wall,
    List<AnchorMemory> availableMemories,
  ) async {
    final linkedMemoryIds = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ManageLinkedAnchorsDialog(
        availableMemories: availableMemories,
        selectedMemoryIds: wall.linkedMemoryIds,
      ),
    );

    if (linkedMemoryIds == null || !context.mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).updateLinkedMemoryIds(
          wallId: wall.id,
          linkedMemoryIds: linkedMemoryIds,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Linked anchors updated.')),
    );
  }

  ARWall? _findWall(List<ARWall> walls) {
    for (final wall in walls) {
      if (wall.id == wallId) {
        return wall;
      }
    }
    return null;
  }

  void _showQrCode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Scan to Join'),
          content: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code, size: 160),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInviteMemberDialog(
    BuildContext context,
    WidgetRef ref,
    ARWall wall,
  ) async {
    final invitee = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteMemberDialog(),
    );

    if (invitee == null || !context.mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).inviteMember(
          wallId: wall.id,
          invitee: invitee,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${invitee.trim()} invited.')),
    );
  }

  Future<void> _showAddItemDialog(
    BuildContext context,
    WidgetRef ref,
    ARWall wall,
  ) async {
    final draft = await showDialog<_WallItemDraft>(
      context: context,
      builder: (_) => const _AddWallItemDialog(),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).addWallItem(
          wallId: wall.id,
          type: draft.type,
          content: draft.content,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_labelForType(draft.type)} added.')),
    );
  }
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog();

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final _inviteeController = TextEditingController();
  var _showInviteeError = false;

  @override
  void dispose() {
    _inviteeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite member'),
      content: TextField(
        key: const ValueKey('wall_invitee_field'),
        controller: _inviteeController,
        decoration: InputDecoration(
          labelText: 'Name or email',
          errorText: _showInviteeError ? 'Invitee required' : null,
        ),
        onChanged: (_) {
          if (_showInviteeError) {
            setState(() => _showInviteeError = false);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _invite,
          child: const Text('Invite'),
        ),
      ],
    );
  }

  void _invite() {
    final invitee = _inviteeController.text.trim();
    if (invitee.isEmpty) {
      setState(() => _showInviteeError = true);
      return;
    }

    Navigator.pop(context, invitee);
  }
}

class _WallItemDraft {
  const _WallItemDraft({
    required this.type,
    required this.content,
  });

  final WallItemType type;
  final String content;
}

class _AddWallItemDialog extends StatefulWidget {
  const _AddWallItemDialog();

  @override
  State<_AddWallItemDialog> createState() => _AddWallItemDialogState();
}

class _AddWallItemDialogState extends State<_AddWallItemDialog> {
  final _contentController = TextEditingController();
  var _selectedType = WallItemType.note;
  var _showContentError = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add wall item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WallItemType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final type in WallItemType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(_labelForType(type)),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedType = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('wall_item_content_field'),
            controller: _contentController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Content',
              errorText: _showContentError ? 'Content required' : null,
            ),
            onChanged: (_) {
              if (_showContentError) {
                setState(() => _showContentError = false);
              }
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
          onPressed: _addItem,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _addItem() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _showContentError = true);
      return;
    }

    Navigator.pop(
      context,
      _WallItemDraft(
        type: _selectedType,
        content: content,
      ),
    );
  }
}

String _labelForType(WallItemType type) {
  return switch (type) {
    WallItemType.photo => 'Photo',
    WallItemType.note => 'Note',
    WallItemType.drawing => 'Drawing',
    WallItemType.audio => 'Audio',
    WallItemType.model3d => '3D item',
  };
}

class _WallItemsGrid extends StatelessWidget {
  const _WallItemsGrid({required this.items});

  final List<WallItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showItemDetail(context, item),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconForType(item.type), size: 30),
                  const SizedBox(height: 8),
                  Text(
                    item.content,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showItemDetail(BuildContext context, WallItem item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.content),
          content: Text('Added by ${item.author}. ${item.likes} likes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForType(WallItemType type) {
    return switch (type) {
      WallItemType.photo => Icons.photo,
      WallItemType.note => Icons.sticky_note_2_outlined,
      WallItemType.drawing => Icons.draw,
      WallItemType.audio => Icons.mic,
      WallItemType.model3d => Icons.view_in_ar,
    };
  }
}

class _WallOverviewTab extends StatelessWidget {
  const _WallOverviewTab({
    required this.wall,
    required this.linkedMemories,
  });

  final ARWall wall;
  final List<AnchorMemory> linkedMemories;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (wall.items.isNotEmpty) ...[
          _LatestWallItemCard(item: wall.items.first),
          const SizedBox(height: 12),
        ],
        if (linkedMemories.isNotEmpty) ...[
          _LinkedWallMemoriesCard(
            wall: wall,
            memories: linkedMemories,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Wall items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.dashboard_outlined, size: 16),
              label: Text(wall.itemCountLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _WallItemsGrid(items: wall.items),
      ],
    );
  }
}

class _LinkedWallMemoriesCard extends StatelessWidget {
  const _LinkedWallMemoriesCard({
    required this.wall,
    required this.memories,
  });

  final ARWall wall;
  final List<AnchorMemory> memories;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trailPreview = wallTrailPreviewFor(
      memories,
      originLatitude: viewerLatitude,
      originLongitude: viewerLongitude,
      optimizeFromOrigin: true,
    );
    final trailMemoryIds = trailPreview?.orderedMemoryIds ??
        [
          for (final memory in memories) memory.id,
        ];

    return Card(
      key: const ValueKey('wall_linked_memories_card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Linked spatial memories',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.route_outlined, size: 16),
                  label: Text(wall.linkedMemoryCountLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Anchors around this wall context',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (trailPreview != null) ...[
              const SizedBox(height: 10),
              _WallTrailPreviewPanel(
                wallId: wall.id,
                preview: trailPreview,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('wall_start_trail_${wall.id}'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.arViewer,
                  arguments: ARViewerArgs.trail(
                    ARTrailSession.fromMemoryIds(
                      title: '${wall.title} trail',
                      memoryIds: trailMemoryIds,
                      source: ARTrailSource.virtualWall,
                      sourceWallId: wall.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.route_outlined),
                label: Text(
                  memories.length == 1
                      ? 'View wall anchor in AR'
                      : 'Start wall trail',
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final memory in memories)
              ListTile(
                key: ValueKey('wall_anchor_${memory.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  memory.isPrivate ? Icons.lock_outline : Icons.place_outlined,
                ),
                title: Text(memory.title),
                subtitle: Text(
                  '${memory.distanceLabel} - ${memory.anchorHealthLabel}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('wall_anchor_details_${memory.id}'),
                      tooltip: 'Open ${memory.title} details',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.memoryDetails,
                        arguments: memory.id,
                      ),
                    ),
                    if (memory.hasArExperience)
                      IconButton(
                        key: ValueKey('wall_anchor_ar_${memory.id}'),
                        tooltip: 'View ${memory.title} in AR',
                        icon: const Icon(Icons.view_in_ar),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.arViewer,
                          arguments: ARViewerArgs.trail(
                            ARTrailSession.fromMemoryIds(
                              title: '${wall.title} trail',
                              memoryIds: trailMemoryIds,
                              source: ARTrailSource.virtualWall,
                              focusedMemoryId: memory.id,
                              sourceWallId: wall.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memoryDetails,
                  arguments: memory.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LatestWallItemCard extends StatelessWidget {
  const _LatestWallItemCard({required this.item});

  final WallItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey('wall_latest_item_card'),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Icon(_iconForType(item.type), size: 20),
        ),
        title: Text(
          item.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Latest wall item by ${item.author}'),
        trailing: const Icon(Icons.north_east, size: 18),
      ),
    );
  }

  IconData _iconForType(WallItemType type) {
    return switch (type) {
      WallItemType.photo => Icons.photo,
      WallItemType.note => Icons.sticky_note_2_outlined,
      WallItemType.drawing => Icons.draw,
      WallItemType.audio => Icons.mic,
      WallItemType.model3d => Icons.view_in_ar,
    };
  }
}

class _WallTrailPreviewPanel extends StatelessWidget {
  const _WallTrailPreviewPanel({
    required this.wallId,
    required this.preview,
  });

  final String wallId;
  final WallTrailPreview preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: ValueKey('wall_detail_trail_preview_$wallId'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.route_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    preview.routeSummaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview.startEndLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _TrailPreviewMetric(
                        icon: Icons.near_me_outlined,
                        label: preview.startDistanceLabel,
                      ),
                      _TrailPreviewMetric(
                        icon: Icons.directions_walk,
                        label: preview.walkTimeLabel,
                      ),
                      _TrailPreviewMetric(
                        icon: preview.hasPrivateStops
                            ? Icons.lock_outline
                            : Icons.public,
                        label: preview.privacyLabel,
                      ),
                      _TrailPreviewMetric(
                        icon: preview.hasCalibrationReviews
                            ? Icons.warning_amber
                            : Icons.verified_outlined,
                        label: preview.anchorHealthLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailPreviewMetric extends StatelessWidget {
  const _TrailPreviewMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({
    required this.memberCount,
    required this.memberCountLabel,
  });

  final int memberCount;
  final String memberCountLabel;

  @override
  Widget build(BuildContext context) {
    final count = memberCount.clamp(4, 12);

    return ListView.builder(
      itemCount: count + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text(memberCountLabel),
          );
        }

        final memberIndex = index - 1;
        return ListTile(
          leading: CircleAvatar(child: Text('M${memberIndex + 1}'[0])),
          title: Text('Member ${memberIndex + 1}'),
          subtitle: Text(memberIndex == 0 ? 'Owner' : 'Contributor'),
          trailing: memberIndex == 0 ? const Icon(Icons.verified) : null,
        );
      },
    );
  }
}
