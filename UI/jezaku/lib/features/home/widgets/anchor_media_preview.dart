import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';

class AnchorMediaPreview extends ConsumerWidget {
  const AnchorMediaPreview({
    super.key,
    required this.anchor,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.iconSize = 32,
    this.fit = BoxFit.cover,
    this.showAvailabilityBadge = true,
  });

  final AnchorMemory anchor;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius borderRadius;
  final double iconSize;
  final BoxFit fit;
  final bool showAvailabilityBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(anchor));
    final imageBytes = resolvedMedia?.previewBytes;
    final fallback = _AnchorMediaPreviewFallback(
      anchor: anchor,
      resolvedMedia: resolvedMedia,
      foregroundColor: foregroundColor ?? colorScheme.onPrimaryContainer,
      iconSize: iconSize,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: backgroundColor ?? colorScheme.primaryContainer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageBytes == null
                ? fallback
                : Image.memory(
                    imageBytes,
                    key: ValueKey('anchor_media_preview_image_${anchor.id}'),
                    fit: fit,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
            if (showAvailabilityBadge &&
                resolvedMedia?.isPreviewCacheMissing == true)
              Positioned(
                top: 6,
                right: 6,
                child: _AnchorMediaAvailabilityBadge(
                  anchorId: anchor.id,
                  label: resolvedMedia!.availabilityLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnchorMediaAvailabilityBadge extends StatelessWidget {
  const _AnchorMediaAvailabilityBadge({
    required this.anchorId,
    required this.label,
  });

  final String anchorId;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: DecoratedBox(
        key: ValueKey('anchor_media_preview_missing_cache_badge_$anchorId'),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.surface, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.cloud_off_outlined,
            size: 14,
            color: colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _AnchorMediaPreviewFallback extends StatelessWidget {
  const _AnchorMediaPreviewFallback({
    required this.anchor,
    required this.resolvedMedia,
    required this.foregroundColor,
    required this.iconSize,
  });

  final AnchorMemory anchor;
  final AnchorResolvedMedia? resolvedMedia;
  final Color foregroundColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        resolvedMedia == null
            ? anchor.hasArExperience
                ? Icons.view_in_ar
                : Icons.photo
            : anchorMediaIconFor(resolvedMedia!.type),
        color: foregroundColor,
        size: iconSize,
      ),
    );
  }
}
