import 'package:flutter/material.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

IconData anchorMediaIconFor(AnchorMediaType type) {
  return switch (type) {
    AnchorMediaType.cameraPhoto => Icons.photo_camera_outlined,
    AnchorMediaType.importedPhoto => Icons.photo_library_outlined,
    AnchorMediaType.arSnapshot => Icons.view_in_ar,
    AnchorMediaType.arRecording => Icons.video_file_outlined,
    AnchorMediaType.arModel => Icons.view_in_ar_outlined,
  };
}

String anchorMediaSummaryLabel(AnchorMediaAttachment attachment) {
  return attachment.summaryLabel;
}

String? anchorMediaQualityWarningLabel(AnchorMediaAttachment attachment) {
  final warning = attachment.recordingQualityWarningLabel;
  final detail = attachment.recordingQualityDetailLabel;
  if (warning == null || detail == null) {
    return null;
  }
  return '$warning - $detail';
}

class AnchorMediaPill extends StatelessWidget {
  const AnchorMediaPill({
    super.key,
    required this.attachment,
    this.includeDetail = false,
    this.compact = false,
    this.overlay = false,
    this.onTap,
  });

  final AnchorMediaAttachment attachment;
  final bool includeDetail;
  final bool compact;
  final bool overlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = includeDetail
        ? anchorMediaSummaryLabel(attachment)
        : attachment.typeLabel;
    final qualityWarning = anchorMediaQualityWarningLabel(attachment);
    final hasQualityWarning = qualityWarning != null;
    final backgroundColor = overlay
        ? Colors.black.withValues(alpha: 0.54)
        : hasQualityWarning
            ? colorScheme.errorContainer
            : colorScheme.tertiaryContainer;
    final foregroundColor = overlay
        ? Colors.white
        : hasQualityWarning
            ? colorScheme.onErrorContainer
            : colorScheme.onTertiaryContainer;
    final warningColor =
        overlay ? Colors.amberAccent.shade100 : colorScheme.error;

    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasQualityWarning) ...[
              Icon(
                Icons.warning_amber_rounded,
                color: warningColor,
                size: compact ? 13 : 14,
              ),
              SizedBox(width: compact ? 4 : 5),
            ],
            Icon(
              anchorMediaIconFor(attachment.type),
              color: foregroundColor,
              size: compact ? 13 : 14,
            ),
            SizedBox(width: compact ? 4 : 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final tapHandler = onTap;

    return Tooltip(
      message: [
        anchorMediaSummaryLabel(attachment),
        if (qualityWarning != null) qualityWarning,
      ].join('\n'),
      child: tapHandler == null
          ? pill
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(compact ? 6 : 8),
                onTap: tapHandler,
                child: pill,
              ),
            ),
    );
  }
}
