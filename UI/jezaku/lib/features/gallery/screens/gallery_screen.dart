import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_map_point.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/services/anchor_map_projection_service.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/home/widgets/anchor_health_chip.dart';
import 'package:jejaku/features/home/widgets/anchor_media_detail_sheet.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/home/widgets/anchor_media_preview.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  static const _geoService = AnchorGeoService();
  static const _mapProjectionService = AnchorMapProjectionService();
  static const _mapRadiusMeters = 100.0;

  String _view = 'All';
  _GallerySortOption _sort = _GallerySortOption.newest;
  _GalleryMediaFilter _mediaFilter = _GalleryMediaFilter.all;

  List<AnchorMemory> _items(
    List<AnchorMemory> anchors,
    ViewerLocation origin,
  ) {
    final filteredItems = switch (_view) {
      'Private' => anchors.where((anchor) => anchor.isPrivate).toList(),
      'AR' => anchors.where((anchor) => anchor.hasArExperience).toList(),
      'Media' => anchors.where(_matchesMediaFilter).toList(),
      'Review' =>
        anchors.where((anchor) => anchor.needsCalibrationReview).toList(),
      _ => anchors.toList(),
    };

    return _sortItems(filteredItems, origin);
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(viewerLocationProvider);
    final items = _items(ref.watch(nearbyAnchorsProvider), origin);
    final spatialPoints = _mapProjectionService.pointsFor(
      anchors: items,
      originLatitude: origin.latitude,
      originLongitude: origin.longitude,
      useCoordinateDistance: origin.isLive,
      radiusMeters: _mapRadiusMeters,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          PopupMenuButton<_GallerySortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (sort) {
              setState(() => _sort = sort);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gallery sorted by ${sort.label}.')),
              );
            },
            itemBuilder: (context) {
              return [
                for (final sort in _GallerySortOption.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: _sort == sort,
                    child: Text(sort.menuLabel),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'AR', label: Text('AR')),
                  ButtonSegment(value: 'Media', label: Text('Media')),
                  ButtonSegment(value: 'Private', label: Text('Private')),
                  ButtonSegment(value: 'Review', label: Text('Review')),
                ],
                selected: {_view},
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.first);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _countLabel(items.length),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_view != 'All' && items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _view = 'All'),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Show all'),
                  ),
              ],
            ),
          ),
          if (_view == 'Media')
            SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in _GalleryMediaFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _mediaFilter == filter,
                        onSelected: (_) {
                          setState(() => _mediaFilter = filter);
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (items.isNotEmpty)
            _GallerySpatialTrail(
              points: spatialPoints,
              onOpenMemory: _openMemoryDetails,
              onStartArTrail: spatialPoints.isEmpty
                  ? null
                  : () => _openArTrail(spatialPoints),
            ),
          Expanded(
            child: items.isEmpty
                ? _GalleryEmptyState(
                    view: _view,
                    onShowAll: () => setState(() => _view = 'All'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _GalleryTile(anchor: items[index], index: index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _countLabel(int count) {
    final noun = count == 1 ? 'memory' : 'memories';
    if (_view == 'Media') {
      return '$count ${_mediaFilter.countLabel} $noun';
    }
    final scope = switch (_view) {
      'AR' => 'AR ',
      'Private' => 'private ',
      'Review' => 'review ',
      _ => '',
    };
    return '$count $scope$noun';
  }

  bool _matchesMediaFilter(AnchorMemory anchor) {
    final attachment = anchor.mediaAttachment;
    if (attachment == null) {
      return false;
    }
    return _mediaFilter.matches(attachment);
  }

  List<AnchorMemory> _sortItems(
    List<AnchorMemory> items,
    ViewerLocation origin,
  ) {
    return switch (_sort) {
      _GallerySortOption.newest => items,
      _GallerySortOption.oldest => items.reversed.toList(),
      _GallerySortOption.nearest => items
        ..sort(
          (a, b) =>
              _distanceMeters(a, origin).compareTo(_distanceMeters(b, origin)),
        ),
      _GallerySortOption.reactions => items
        ..sort((a, b) => b.reactions.compareTo(a.reactions)),
    };
  }

  double _distanceMeters(AnchorMemory anchor, ViewerLocation origin) {
    if (origin.isLive) {
      return _geoService.distanceBetweenMeters(
        origin.latitude,
        origin.longitude,
        anchor.latitude,
        anchor.longitude,
      );
    }
    return _geoService.distanceFromLabel(anchor.distanceLabel) ??
        double.infinity;
  }

  void _openMemoryDetails(AnchorMemory anchor) {
    Navigator.pushNamed(
      context,
      AppRoutes.memoryDetails,
      arguments: anchor.id,
    );
  }

  void _openArTrail(List<AnchorMapPoint> points) {
    if (points.isEmpty) {
      return;
    }

    final memoryIds = [for (final point in points) point.memory.id];
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(
        ARTrailSession.fromMemoryIds(
          title: 'Gallery spatial trail',
          memoryIds: memoryIds,
          source: ARTrailSource.gallery,
        ),
      ),
    );
  }
}

enum _GallerySortOption {
  newest('newest first', 'Newest first'),
  oldest('oldest first', 'Oldest first'),
  nearest('nearest first', 'Nearest first'),
  reactions('most reactions', 'Most reactions');

  const _GallerySortOption(this.label, this.menuLabel);

  final String label;
  final String menuLabel;
}

enum _GalleryMediaFilter {
  all('All media', 'media'),
  photos('Photos', 'photo'),
  arSnapshots('AR snapshots', 'AR snapshot'),
  arRecordings('Recordings', 'AR screen recording'),
  qualityIssues('Quality issues', 'quality issue');

  const _GalleryMediaFilter(this.label, this.countLabel);

  final String label;
  final String countLabel;

  bool matches(AnchorMediaAttachment attachment) {
    final type = attachment.type;
    return switch (this) {
      _GalleryMediaFilter.all => true,
      _GalleryMediaFilter.photos => type == AnchorMediaType.cameraPhoto ||
          type == AnchorMediaType.importedPhoto,
      _GalleryMediaFilter.arSnapshots =>
        type == AnchorMediaType.arSnapshot || type == AnchorMediaType.arModel,
      _GalleryMediaFilter.arRecordings => type == AnchorMediaType.arRecording,
      _GalleryMediaFilter.qualityIssues =>
        attachment.recordingQualityWarningLabel != null,
    };
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.anchor,
    required this.index,
  });

  final AnchorMemory anchor;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaAttachment = anchor.mediaAttachment;
    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.surfaceContainerHighest,
    ];

    return Card(
      key: ValueKey('gallery_tile_${anchor.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.memoryDetails,
          arguments: anchor.id,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnchorMediaPreview(
                        anchor: anchor,
                        backgroundColor: colors[index % colors.length],
                        foregroundColor: colorScheme.onPrimaryContainer,
                        borderRadius: BorderRadius.zero,
                        iconSize: 44,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _GalleryPill(
                        icon: Icons.near_me_outlined,
                        label: anchor.distanceLabel,
                      ),
                    ),
                    if (anchor.isPrivate)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: _GalleryIconPill(
                          icon: Icons.lock,
                          tooltip: 'Private memory',
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnchorHealthChip(anchor: anchor, compact: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anchor.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anchor.capturedAgo,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mediaAttachment != null) ...[
                    AnchorMediaPill(
                      attachment: mediaAttachment,
                      compact: true,
                      onTap: () => showAnchorMediaDetailSheet(
                        context,
                        memory: anchor,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        color: colorScheme.outline,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${anchor.reactions} reactions',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

class _GallerySpatialTrail extends StatelessWidget {
  const _GallerySpatialTrail({
    required this.points,
    required this.onOpenMemory,
    required this.onStartArTrail,
  });

  final List<AnchorMapPoint> points;
  final ValueChanged<AnchorMemory> onOpenMemory;
  final VoidCallback? onStartArTrail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Spatial trail',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('gallery_start_ar_trail_button'),
                  onPressed: onStartArTrail,
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('AR trail'),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.near_me_outlined,
                  color: colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Nearest first',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${points.length} stops',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final point = points[index];
                return _GalleryTrailChip(
                  point: point,
                  onTap: () => onOpenMemory(point.memory),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTrailChip extends StatelessWidget {
  const _GalleryTrailChip({
    required this.point,
    required this.onTap,
  });

  final AnchorMapPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final memory = point.memory;

    return SizedBox(
      width: 176,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('gallery_trail_${memory.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      memory.isPrivate
                          ? Icons.lock_outline
                          : Icons.place_outlined,
                      color: colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${point.distanceLabel} ${point.directionLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  memory.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  memory.anchorHealthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryPill extends StatelessWidget {
  const _GalleryPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryIconPill extends StatelessWidget {
  const _GalleryIconPill({
    required this.icon,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ),
    );
  }
}

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState({
    required this.view,
    required this.onShowAll,
  });

  final String view;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = view.toLowerCase();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: colorScheme.outline,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'No $label memories',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Try another gallery filter or return to all memories.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.clear_all),
              label: const Text('Show all'),
            ),
          ],
        ),
      ),
    );
  }
}
