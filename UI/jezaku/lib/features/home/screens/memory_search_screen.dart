import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_spatial_journey_service.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/home/widgets/anchor_list_tile.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

class MemorySearchScreen extends ConsumerStatefulWidget {
  const MemorySearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialFilter = 'All',
  });

  final String initialQuery;
  final String initialFilter;

  @override
  ConsumerState<MemorySearchScreen> createState() => _MemorySearchScreenState();
}

class MemorySearchArgs {
  const MemorySearchArgs({
    this.initialQuery = '',
    this.initialFilter = 'All',
  });

  final String initialQuery;
  final String initialFilter;
}

class _MemorySearchScreenState extends ConsumerState<MemorySearchScreen> {
  static const _trailRadiusMeters = 100.0;
  static const _filters = [
    'All',
    'AR',
    'Media',
    'Quality Issues',
    'Private',
    'Public',
    'Walls',
    'Needs Calibration',
  ];

  final TextEditingController _queryController = TextEditingController();
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter =
        _filters.contains(widget.initialFilter) ? widget.initialFilter : 'All';
    _queryController.text = widget.initialQuery;
    _queryController.addListener(_onQueryChanged);
  }

  @override
  Widget build(BuildContext context) {
    final anchors = ref.watch(nearbyAnchorsProvider);
    final walls = ref.watch(arWallsProvider);
    final results = _search(anchors, walls);
    final searchTrailSteps = _searchTrailSteps(results);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Memories')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search title, caption, media, or location',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: _queryController.clear,
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} result${results.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (searchTrailSteps.length > 1)
                  TextButton.icon(
                    key: const ValueKey('memory_search_start_ar_trail_button'),
                    onPressed: () => _openArTrail(searchTrailSteps),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: Text('${searchTrailSteps.length} stop AR trail'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const _EmptySearchState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final anchor = results[index];
                      final linkedWalls = wallsLinkedToMemory(
                        anchor.id,
                        walls,
                      );
                      return AnchorListTile(
                        anchor: anchor,
                        linkedWallLabel: _linkedWallLabel(linkedWalls),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.memoryDetails,
                          arguments: anchor.id,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<AnchorMemory> _search(List<AnchorMemory> anchors, List<ARWall> walls) {
    final query = _queryController.text.trim().toLowerCase();
    final wallLinkedMemoryIds = {
      for (final wall in walls) ...wall.linkedMemoryIds,
    };

    return anchors.where((anchor) {
      final linkedWalls = wallsLinkedToMemory(anchor.id, walls);
      final matchesFilter = switch (_filter) {
        'AR' => anchor.hasArExperience,
        'Media' => anchor.hasMediaAttachment,
        'Quality Issues' =>
          anchor.mediaAttachment?.recordingQualityWarningLabel != null,
        'Private' => anchor.isPrivate,
        'Public' => !anchor.isPrivate,
        'Walls' => wallLinkedMemoryIds.contains(anchor.id),
        'Needs Calibration' => anchor.needsCalibrationReview,
        _ => true,
      };

      if (!matchesFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return anchor.title.toLowerCase().contains(query) ||
          anchor.caption.toLowerCase().contains(query) ||
          anchor.locationLabel.toLowerCase().contains(query) ||
          anchor.matchesMediaQuery(query) ||
          linkedWalls.any((wall) => _matchesWall(wall, query));
    }).toList();
  }

  bool _matchesWall(ARWall wall, String query) {
    return wall.title.toLowerCase().contains(query) ||
        wall.description.toLowerCase().contains(query) ||
        wall.distanceLabel.toLowerCase().contains(query);
  }

  String? _linkedWallLabel(List<ARWall> walls) {
    if (walls.isEmpty) {
      return null;
    }
    if (walls.length == 1) {
      return walls.single.title;
    }
    return '${walls.length} virtual walls';
  }

  List<AnchorJourneyStep> _searchTrailSteps(List<AnchorMemory> results) {
    if (results.length < 2) {
      return const <AnchorJourneyStep>[];
    }

    final origin = ref.watch(viewerLocationProvider);
    return const AnchorSpatialJourneyService().stepsFor(
      anchors: results,
      originLatitude: origin.latitude,
      originLongitude: origin.longitude,
      useCoordinateDistance: origin.isLive,
      radiusMeters: _trailRadiusMeters,
    );
  }

  void _openArTrail(List<AnchorJourneyStep> steps) {
    if (steps.length < 2) {
      return;
    }

    final memoryIds = [for (final step in steps) step.memory.id];
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(
        ARTrailSession.fromMemoryIds(
          title: 'Search result trail',
          memoryIds: memoryIds,
          source: ARTrailSource.search,
        ),
      ),
    );
  }

  void _onQueryChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: colorScheme.outline,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'No memories found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different keyword or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
