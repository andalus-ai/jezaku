import 'package:flutter/material.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/widgets/anchor_health_chip.dart';
import 'package:jejaku/features/home/widgets/anchor_media_detail_sheet.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/home/widgets/anchor_media_preview.dart';

class AnchorListTile extends StatelessWidget {
  const AnchorListTile({
    super.key,
    required this.anchor,
    this.linkedWallLabel,
    this.onTap,
  });

  final AnchorMemory anchor;
  final String? linkedWallLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaAttachment = anchor.mediaAttachment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: AnchorMediaPreview(
                  anchor: anchor,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  iconSize: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          anchor.distanceLabel,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (anchor.isPrivate) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.lock,
                            color: colorScheme.tertiary,
                            size: 14,
                          ),
                        ],
                        const Spacer(),
                        AnchorHealthChip(anchor: anchor, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      anchor.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      anchor.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (linkedWallLabel != null || mediaAttachment != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (linkedWallLabel != null)
                            _LinkedWallPill(label: linkedWallLabel!),
                          if (mediaAttachment != null)
                            AnchorMediaPill(
                              attachment: mediaAttachment,
                              includeDetail: true,
                              onTap: () => showAnchorMediaDetailSheet(
                                context,
                                memory: anchor,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: colorScheme.outline,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            anchor.locationLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          anchor.capturedAgo,
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 11,
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
      ),
    );
  }
}

class _LinkedWallPill extends StatelessWidget {
  const _LinkedWallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view,
              color: colorScheme.onSecondaryContainer,
              size: 14,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
