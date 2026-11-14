part of '../ar_viewer_screen.dart';

class _AnchorBubble extends ConsumerWidget {
  const _AnchorBubble({
    required this.anchor,
    required this.isFocused,
    required this.stopNumber,
    required this.wallTitles,
    required this.onTap,
  });

  final ARMemoryProjection anchor;
  final bool isFocused;
  final int? stopNumber;
  final List<String> wallTitles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = anchor.memory;
    final projection = anchor.projection;
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));
    final qualityColor = memory.needsCalibrationReview
        ? Colors.redAccent.shade100
        : _qualityColor(projection.quality);
    final stopNumber = this.stopNumber;
    final showMediaPlane =
        memory.mediaAttachment != null || wallTitles.isNotEmpty;

    return Semantics(
      button: true,
      label: stopNumber == null
          ? 'Focus ${memory.title}'
          : 'Focus ${memory.title}, stop $stopNumber',
      child: GestureDetector(
        key: ValueKey('ar_anchor_bubble_${memory.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMediaPlane) ...[
              _AnchorMediaPlane(
                anchor: anchor,
                resolvedMedia: resolvedMedia,
                wallTitles: wallTitles,
                isFocused: isFocused,
                qualityColor: qualityColor,
              ),
              const SizedBox(height: 6),
            ],
            _AnchorStatusChip(
              anchor: anchor,
              isFocused: isFocused,
              stopNumber: stopNumber,
              qualityColor: qualityColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorMediaPlane extends StatelessWidget {
  const _AnchorMediaPlane({
    required this.anchor,
    required this.resolvedMedia,
    required this.wallTitles,
    required this.isFocused,
    required this.qualityColor,
  });

  final ARMemoryProjection anchor;
  final AnchorResolvedMedia? resolvedMedia;
  final List<String> wallTitles;
  final bool isFocused;
  final Color qualityColor;

  @override
  Widget build(BuildContext context) {
    final memory = anchor.memory;
    final attachment = memory.mediaAttachment;
    final previewBytes = resolvedMedia?.previewBytes;
    final width = isFocused ? 218.0 : 188.0;
    final previewHeight = isFocused ? 130.0 : 108.0;

    return Container(
      key: ValueKey('ar_floating_anchor_${memory.id}'),
      width: width,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFocused ? Colors.cyanAccent.shade100 : qualityColor,
          width: isFocused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: previewHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewBytes != null)
                  Image.memory(
                    previewBytes,
                    key: ValueKey('ar_floating_media_${memory.id}'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _AnchorMediaPlaceholder(
                        memory: memory,
                        attachment: attachment,
                      );
                    },
                  )
                else
                  _AnchorMediaPlaceholder(
                    key: ValueKey('ar_floating_media_${memory.id}'),
                    memory: memory,
                    attachment: attachment,
                  ),
                if (wallTitles.isNotEmpty)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: _AnchorWallBadge(
                      key: ValueKey('ar_floating_virtual_wall_${memory.id}'),
                      title: wallTitles.first,
                      extraCount: wallTitles.length - 1,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: Row(
              children: [
                Icon(
                  attachment == null
                      ? Icons.view_in_ar
                      : anchorMediaIconFor(attachment.type),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    attachment?.type.label ??
                        (wallTitles.isNotEmpty ? 'Virtual wall' : 'AR memory'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchorMediaPlaceholder extends StatelessWidget {
  const _AnchorMediaPlaceholder({
    super.key,
    required this.memory,
    required this.attachment,
  });

  final AnchorMemory memory;
  final AnchorMediaAttachment? attachment;

  @override
  Widget build(BuildContext context) {
    final isRecording = attachment?.type == AnchorMediaType.arRecording;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueGrey.shade900,
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isRecording ? Icons.video_file_outlined : Icons.photo_outlined,
          color: Colors.white70,
          size: 38,
        ),
      ),
    );
  }
}

class _AnchorWallBadge extends StatelessWidget {
  const _AnchorWallBadge({
    super.key,
    required this.title,
    required this.extraCount,
  });

  final String title;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final label = extraCount <= 0 ? title : '$title +$extraCount';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_week, color: Colors.cyanAccent, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorStatusChip extends StatelessWidget {
  const _AnchorStatusChip({
    required this.anchor,
    required this.isFocused,
    required this.stopNumber,
    required this.qualityColor,
  });

  final ARMemoryProjection anchor;
  final bool isFocused;
  final int? stopNumber;
  final Color qualityColor;

  @override
  Widget build(BuildContext context) {
    final memory = anchor.memory;
    final projection = anchor.projection;
    final foreground = projection.isVisible ? Colors.black87 : Colors.white;
    final secondary = projection.isVisible
        ? Colors.black54
        : Colors.white.withValues(alpha: 0.72);

    return Container(
      width: 164,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: projection.isVisible
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFocused
              ? Colors.cyanAccent.shade100
              : projection.isVisible
                  ? qualityColor
                  : Colors.white30,
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (stopNumber == null)
                Icon(
                  isFocused
                      ? Icons.center_focus_strong
                      : memory.needsCalibrationReview
                          ? Icons.warning_amber
                          : projection.isVisible
                              ? Icons.photo
                              : projection.relativeHeadingDegrees > 0
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                  color: foreground,
                  size: 16,
                )
              else
                Container(
                  key: ValueKey('ar_anchor_bubble_stop_${memory.id}'),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isFocused
                        ? Colors.cyanAccent.shade100
                        : Colors.black.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                  child: Text(
                    '$stopNumber',
                    style: TextStyle(
                      color: isFocused ? Colors.black87 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  memory.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${projection.distanceLabel} • ${projection.directionLabel} • '
            '${memory.anchorHealthLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectedAnchorTile extends StatelessWidget {
  const _ProjectedAnchorTile({
    super.key,
    required this.anchor,
    required this.isFocused,
    required this.stopNumber,
    required this.onFocus,
  });

  final ARMemoryProjection anchor;
  final bool isFocused;
  final int? stopNumber;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final projection = anchor.projection;
    final memory = anchor.memory;
    final qualityColor = memory.needsCalibrationReview
        ? Colors.redAccent.shade100
        : _qualityColor(projection.quality);
    final stabilityLabel = memory.anchorHealthLabel;
    final stopNumber = this.stopNumber;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onFocus,
      leading: stopNumber == null
          ? Icon(
              projection.isVisible
                  ? Icons.center_focus_strong
                  : Icons.navigation,
              color: projection.isVisible ? qualityColor : Colors.white54,
            )
          : CircleAvatar(
              key: ValueKey('ar_trail_stop_marker_${memory.id}'),
              radius: 15,
              backgroundColor:
                  isFocused ? Colors.cyanAccent.shade100 : Colors.white12,
              child: Text(
                '$stopNumber',
                style: TextStyle(
                  color: isFocused ? Colors.black87 : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      title: Text(
        memory.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${stopNumber == null ? '' : 'Stop $stopNumber • '}'
        '${projection.distanceLabel} • ${projection.directionLabel} • '
        '${projection.assessment.label} '
        '${(projection.confidenceScore * 100).round()}% • $stabilityLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: memory.needsCalibrationReview
          ? TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.memoryCalibration,
                  arguments: memory.id,
                );
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Calibrate'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent.shade100,
              ),
            )
          : isFocused
              ? Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.center_focus_strong, size: 16),
                  label: const Text('Focused'),
                  backgroundColor: Colors.cyanAccent.shade100,
                )
              : memory.isPrivate
                  ? const Icon(Icons.lock, color: Colors.orangeAccent, size: 18)
                  : null,
    );
  }
}
