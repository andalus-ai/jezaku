import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jejaku/features/virtual_wall/widgets/ar_wall_card.dart';
import 'package:jejaku/features/virtual_wall/widgets/create_wall_dialog.dart';
import 'package:jejaku/features/virtual_wall/widgets/empty_wall_filter_state.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_search_dialog.dart';
import 'package:material_ui/material_ui.dart';

export 'package:jejaku/features/virtual_wall/screens/virtual_wall_detail_screen.dart';

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
    final origin = ref.watch(viewerLocationProvider);
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
                ? EmptyWallFilterState(filter: _filter, query: _query)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: walls.length,
                    itemBuilder: (context, index) {
                      final wall = walls[index];
                      final linkedMemories =
                          ref.watch(wallLinkedMemoriesProvider(wall.id));
                      final trailPreview = wallTrailPreviewFor(
                        linkedMemories,
                        originLatitude: origin.latitude,
                        originLongitude: origin.longitude,
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
      builder: (_) => WallSearchDialog(initialQuery: _query),
    );

    if (query == null || !mounted) {
      return;
    }

    setState(() => _query = query.trim());
  }

  Future<void> _showCreateWallDialog() async {
    final draft = await showDialog<WallDraft>(
      context: context,
      builder: (_) => CreateWallDialog(
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
