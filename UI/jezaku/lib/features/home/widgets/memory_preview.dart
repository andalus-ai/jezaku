import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:material_ui/material_ui.dart';

/// The frame's photo at 4:3, or a typed placeholder when no preview bytes are
/// available. Shared by the memory details and the photo page.
class MemoryPreview extends StatelessWidget {
  const MemoryPreview({
    super.key,
    required this.memory,
    this.resolvedMedia,
  });

  final AnchorMemory memory;
  final AnchorResolvedMedia? resolvedMedia;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaAttachment = memory.mediaAttachment;

    final imageBytes = resolvedMedia?.previewBytes;
    if (imageBytes != null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageBytes,
            key: ValueKey('memory_media_image_${memory.id}'),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return MemoryPreviewFallback(
                memory: memory,
                colorScheme: colorScheme,
                mediaAttachment: mediaAttachment,
              );
            },
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: MemoryPreviewFallback(
        memory: memory,
        colorScheme: colorScheme,
        mediaAttachment: mediaAttachment,
      ),
    );
  }
}

class MemoryPreviewFallback extends StatelessWidget {
  const MemoryPreviewFallback({
    super.key,
    required this.memory,
    required this.colorScheme,
    required this.mediaAttachment,
  });

  final AnchorMemory memory;
  final ColorScheme colorScheme;
  final AnchorMediaAttachment? mediaAttachment;

  @override
  Widget build(BuildContext context) {
    final attachment = mediaAttachment;
    final icon = attachment == null
        ? memory.hasArExperience
            ? Icons.view_in_ar
            : Icons.photo
        : anchorMediaIconFor(attachment.type);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: memory.isPrivate
            ? colorScheme.tertiaryContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: colorScheme.onPrimaryContainer,
              size: 72,
            ),
            if (attachment != null) ...[
              const SizedBox(height: 8),
              Text(
                attachment.detailLabel,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
