part of '../ar_viewer_screen.dart';

Color _radarDotColor(ARMemoryProjection anchor, bool isFocused) {
  if (isFocused) {
    return Colors.cyanAccent.shade100;
  }
  if (anchor.memory.needsCalibrationReview) {
    return Colors.redAccent.shade100;
  }
  if (anchor.memory.isPrivate) {
    return Colors.amberAccent;
  }
  if (anchor.projection.isVisible) {
    return Colors.lightBlueAccent;
  }
  return Colors.white54;
}

class _FocusedAnchorPanel extends StatelessWidget {
  const _FocusedAnchorPanel({
    required this.anchor,
    required this.linkedWalls,
    required this.onDetails,
    required this.onCalibrate,
    required this.onOpenWall,
    required this.onRecenter,
  });

  final ARMemoryProjection anchor;
  final List<ARWall> linkedWalls;
  final VoidCallback onDetails;
  final VoidCallback onCalibrate;
  final ValueChanged<ARWall> onOpenWall;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final memory = anchor.memory;
    final projection = anchor.projection;
    final healthColor = memory.needsCalibrationReview
        ? Colors.amberAccent.shade100
        : Colors.greenAccent.shade100;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Focused anchor',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              memory.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _HudPill(
                  icon: Icons.straighten,
                  label: projection.distanceLabel,
                  color: Colors.cyanAccent.shade100,
                  tooltip: 'Distance to focused anchor',
                ),
                _HudPill(
                  icon: Icons.explore_outlined,
                  label: projection.directionLabel,
                  color: Colors.lightBlueAccent.shade100,
                  tooltip: 'Direction to focused anchor',
                ),
                _HudPill(
                  icon: memory.needsCalibrationReview
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  label: memory.anchorHealthLabel,
                  color: healthColor,
                  tooltip: 'Anchor health',
                ),
              ],
            ),
            if (memory.needsCalibrationReview ||
                memory.captureMetadata.hasManualCorrection) ...[
              const SizedBox(height: 8),
              _FocusedAnchorCalibrationLine(
                memory: memory,
                onCalibrate: onCalibrate,
              ),
            ],
            if (linkedWalls.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Virtual walls',
                key: ValueKey('ar_linked_walls_label'),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final wall in linkedWalls)
                    ActionChip(
                      key: ValueKey('ar_linked_wall_${wall.id}'),
                      avatar: Icon(
                        wall.isPublic ? Icons.public : Icons.group,
                        color: Colors.black87,
                        size: 16,
                      ),
                      label: Text(
                        wall.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => onOpenWall(wall),
                      backgroundColor: Colors.cyanAccent.shade100,
                      labelStyle: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final detailsButton = OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                );
                final recenterButton = FilledButton.icon(
                  onPressed: onRecenter,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Recenter'),
                );
                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [detailsButton, recenterButton],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: detailsButton),
                    const SizedBox(width: 10),
                    Expanded(child: recenterButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedAnchorCalibrationLine extends StatelessWidget {
  const _FocusedAnchorCalibrationLine({
    required this.memory,
    required this.onCalibrate,
  });

  final AnchorMemory memory;
  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    final metadata = memory.captureMetadata;
    final hasCorrection = metadata.hasManualCorrection;
    final statusColor = hasCorrection
        ? Colors.greenAccent.shade100
        : Colors.amberAccent.shade100;
    final title = hasCorrection
        ? 'Manual correction active'
        : metadata.calibrationReasonLabel;
    final subtitle = hasCorrection
        ? metadata.manualCorrectionOffsetLabel
        : metadata.calibrationGuidanceLabel;

    return Row(
      key: const ValueKey('focused_anchor_calibration_line'),
      children: [
        Icon(
          hasCorrection ? Icons.check_circle_outline : Icons.warning_amber,
          color: statusColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('focused_anchor_adjust_calibration_button'),
          tooltip: 'Adjust calibration',
          onPressed: onCalibrate,
          icon: const Icon(Icons.tune),
          color: Colors.white,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ],
    );
  }
}

Color _qualityColor(JejakuPlacementQuality quality) {
  return switch (quality) {
    JejakuPlacementQuality.stable => Colors.greenAccent.shade100,
    JejakuPlacementQuality.usable => Colors.lightBlueAccent.shade100,
    JejakuPlacementQuality.needsCalibration => Colors.amberAccent.shade100,
    JejakuPlacementQuality.unreliable => Colors.redAccent.shade100,
  };
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
    final handleTap = onTap;
    if (handleTap != null) {
      pill = Semantics(
        button: true,
        onTap: handleTap,
        hint: 'Activate',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleTap,
            child: pill,
          ),
        ),
      );
    }
    final message = tooltip;
    if (message == null || message.isEmpty) {
      return pill;
    }
    return Tooltip(
      message: message,
      child: pill,
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsIssueTile extends StatelessWidget {
  const _DiagnosticsIssueTile({
    required this.issue,
    this.onTap,
  });

  final ARMemoryCloudAnchorIssue issue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final handleTap = onTap;
    Widget tile = Container(
      key: ValueKey('ar_scene_diagnostics_issue_${issue.memoryId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.redAccent.shade100,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issue.reasonLabel,
                  style: TextStyle(
                    color: Colors.redAccent.shade100,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      color: Colors.cyanAccent.shade100,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        issue.actionLabel,
                        style: TextStyle(
                          color: Colors.cyanAccent.shade100,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  issue.memoryId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (handleTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.center_focus_strong,
              color: Colors.cyanAccent.shade100,
              size: 18,
            ),
          ],
        ],
      ),
    );
    if (handleTap == null) {
      return tile;
    }
    tile = Semantics(
      button: true,
      onTap: handleTap,
      hint: 'Double tap to focus this diagnostic anchor',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handleTap,
          child: tile,
        ),
      ),
    );
    return tile;
  }
}

class _ArReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final radius in [72.0, 140.0, 220.0]) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawLine(
      Offset(center.dx - 26, center.dy),
      Offset(center.dx + 26, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 26),
      Offset(center.dx, center.dy + 26),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
