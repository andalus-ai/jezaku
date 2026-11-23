import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/widgets/anchor_media_preview.dart';
import 'package:material_ui/material_ui.dart';

/// One square tile of the own-frames grid: the photo, with small badges for
/// private, video, 3D and not-yet-synced frames.
class MyFrameTile extends StatelessWidget {
  const MyFrameTile({required this.frame, required this.onTap, super.key});

  final AnchorMemory frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: myFrameSemanticLabel(frame),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: AnchorMediaPreview(
                anchor: frame,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                borderRadius: BorderRadius.zero,
                iconSize: 28,
                showAvailabilityBadge: false,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (frame.mediaAttachment?.type ==
                        AnchorMediaType.arRecording)
                      const _TileBadge(icon: Icons.videocam),
                    if (frame.mediaAttachment?.type == AnchorMediaType.arModel)
                      const _TileBadge(icon: Icons.view_in_ar),
                    if (frame.isPrivate) const _TileBadge(icon: Icons.lock),
                  ],
                ),
              ),
            ),
            if (frame.syncStatus != AnchorSyncStatus.synced)
              const Positioned(
                left: 6,
                bottom: 6,
                child: ExcludeSemantics(
                  child: _TileBadge(icon: Icons.cloud_upload_outlined),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Spoken label for a tile: title first, then the facts a badge would show.
String myFrameSemanticLabel(AnchorMemory frame) {
  return [
    frame.title,
    if (frame.isPrivate) 'Private',
    if (frame.mediaAttachment?.type == AnchorMediaType.arRecording) 'Video',
    if (frame.mediaAttachment?.type == AnchorMediaType.arModel) '3D object',
    if (frame.syncStatus != AnchorSyncStatus.synced) frame.syncStatusLabel,
    frame.capturedAgo,
  ].join(', ');
}

class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0x99000000),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
