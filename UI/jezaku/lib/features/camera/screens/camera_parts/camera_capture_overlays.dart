part of '../camera_screen.dart';

class _ImportCandidateTile extends StatelessWidget {
  const _ImportCandidateTile({
    required this.candidate,
    required this.onTap,
  });

  final ImportedCaptureCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.photo_library_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(candidate.title),
      subtitle: Text(
        '${candidate.description}\n${candidate.metadataSummary}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _CaptureARObjectsOverlay extends StatelessWidget {
  const _CaptureARObjectsOverlay({
    required this.anchors,
    required this.wallTitlesByMemoryId,
  });

  final List<ARMemoryProjection> anchors;
  final Map<String, List<String>> wallTitlesByMemoryId;

  @override
  Widget build(BuildContext context) {
    if (anchors.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasVisibleProjection = anchors.any(
      (anchor) => anchor.projection.isVisible,
    );
    return Stack(
      children: [
        for (var index = anchors.length - 1; index >= 0; index--)
          _CaptureProjectedObject(
            anchor: anchors[index],
            wallTitlesByMemoryId: wallTitlesByMemoryId,
            forceCenter: !hasVisibleProjection && index == 0,
          ),
      ],
    );
  }
}

class _CaptureProjectedObject extends StatelessWidget {
  const _CaptureProjectedObject({
    required this.anchor,
    required this.wallTitlesByMemoryId,
    required this.forceCenter,
  });

  final ARMemoryProjection anchor;
  final Map<String, List<String>> wallTitlesByMemoryId;
  final bool forceCenter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: forceCenter
          ? const Alignment(0, -0.12)
          : Alignment(
              anchor.projection.alignmentX,
              anchor.projection.alignmentY,
            ),
      child: Opacity(
        opacity:
            forceCenter ? 0.96 : anchor.projection.opacity.clamp(0.64, 1.0),
        child: Transform.scale(
          scale: forceCenter ? 1.0 : anchor.projection.scale,
          child: _CaptureARObjectCard(
            anchor: anchor,
            wallTitles: wallTitlesByMemoryId[anchor.memory.id] ?? const [],
          ),
        ),
      ),
    );
  }
}

class _CaptureARObjectCard extends ConsumerWidget {
  const _CaptureARObjectCard({
    required this.anchor,
    required this.wallTitles,
  });

  final ARMemoryProjection anchor;
  final List<String> wallTitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = anchor.memory;
    final attachment = memory.mediaAttachment;
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));
    final previewBytes = resolvedMedia?.previewBytes;
    final isWall = wallTitles.isNotEmpty;
    final borderColor =
        isWall ? Colors.amberAccent.shade100 : Colors.cyanAccent.shade100;

    return Container(
      key: ValueKey('camera_ar_object_${memory.id}'),
      width: 174,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 104,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewBytes != null)
                  Image.memory(
                    previewBytes,
                    key: ValueKey('camera_ar_object_media_${memory.id}'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _CaptureARObjectPlaceholder(
                        attachment: attachment,
                        isWall: isWall,
                      );
                    },
                  )
                else
                  _CaptureARObjectPlaceholder(
                    key: ValueKey('camera_ar_object_media_${memory.id}'),
                    attachment: attachment,
                    isWall: isWall,
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _CaptureARObjectDistanceBadge(anchor: anchor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
            child: Row(
              children: [
                Icon(
                  isWall
                      ? Icons.view_column_outlined
                      : attachment == null
                          ? Icons.view_in_ar
                          : anchorMediaIconFor(attachment.type),
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isWall ? wallTitles.first : memory.title,
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

class _CaptureARObjectPlaceholder extends StatelessWidget {
  const _CaptureARObjectPlaceholder({
    super.key,
    required this.attachment,
    required this.isWall,
  });

  final AnchorMediaAttachment? attachment;
  final bool isWall;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isWall
              ? const [Color(0xFF78350F), Color(0xFF111827)]
              : const [Color(0xFF075985), Color(0xFF111827)],
        ),
      ),
      child: Center(
        child: Icon(
          isWall
              ? Icons.view_column_outlined
              : attachment == null
                  ? Icons.view_in_ar
                  : anchorMediaIconFor(attachment!.type),
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _CaptureARObjectDistanceBadge extends StatelessWidget {
  const _CaptureARObjectDistanceBadge({required this.anchor});

  final ARMemoryProjection anchor;

  @override
  Widget build(BuildContext context) {
    final projection = anchor.projection;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${projection.distanceLabel} • ${projection.directionLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
