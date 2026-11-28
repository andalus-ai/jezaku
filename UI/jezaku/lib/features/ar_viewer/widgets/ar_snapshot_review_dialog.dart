import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jezaku_ds/jezaku_ds.dart' show JzRadius;
import 'package:jejaku/features/ar_viewer/services/photo_frame_placement_adjuster.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

/// What the user chose after taking an AR photo.
enum ARSnapshotReviewResult {
  /// Discard the photo and take another.
  retake,

  /// Publish at the pose shown, with default settings, skipping the form.
  publishNow,

  /// Continue to the publish form to add a caption, privacy and walls.
  review,
}

/// Lets the user check an AR photo and fine-tune where its frame will hang
/// before it is staged. Resolves to the chosen [ARSnapshotReviewResult], or
/// `null` if dismissed. [needsCalibration] marks a rough GPS/compass fix: the
/// frame still saves and hangs in this AR session, but "Publish now" becomes
/// "Publish anyway" with a note that it may drift later. [onPlacementChanged]
/// reports every adjusted pose so the caller keeps the latest one.
Future<ARSnapshotReviewResult?> showARSnapshotReviewDialog({
  required BuildContext context,
  required Uint8List bytes,
  required AnchorLocalPose? placement,
  required ValueChanged<AnchorLocalPose?> onPlacementChanged,
  ARVector3? cameraPosition,
  ARVector3 cameraForward = const ARVector3(0, 0, -1),
  bool needsCalibration = false,
}) {
  return showDialog<ARSnapshotReviewResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ARSnapshotReviewDialog(
      bytes: bytes,
      placement: placement,
      onPlacementChanged: onPlacementChanged,
      cameraPosition: cameraPosition,
      cameraForward: cameraForward,
      needsCalibration: needsCalibration,
    ),
  );
}

/// The wording for where a captured frame will hang.
String arSnapshotPlacementLabel(AnchorLocalPose? placement) {
  if (placement == null) {
    return 'Placement unavailable — the photo can still be published.';
  }
  final distance = placement.distanceMeters;
  final distanceText =
      distance == null ? 'nearby' : 'about ${distance.toStringAsFixed(1)} m';
  return placement.planeId == null
      ? 'Floating in space • $distanceText ahead'
      : 'Near a detected vertical surface • $distanceText away';
}

class ARSnapshotReviewDialog extends StatefulWidget {
  const ARSnapshotReviewDialog({
    required this.bytes,
    required this.placement,
    required this.onPlacementChanged,
    this.cameraPosition,
    this.cameraForward = const ARVector3(0, 0, -1),
    this.needsCalibration = false,
    super.key,
  });

  final Uint8List bytes;
  final AnchorLocalPose? placement;
  final ValueChanged<AnchorLocalPose?> onPlacementChanged;
  final ARVector3? cameraPosition;
  final ARVector3 cameraForward;
  final bool needsCalibration;

  @override
  State<ARSnapshotReviewDialog> createState() => _ARSnapshotReviewDialogState();
}

class _ARSnapshotReviewDialogState extends State<ARSnapshotReviewDialog> {
  late AnchorLocalPose? _placement = widget.placement;
  late double _distance =
      PhotoFramePlacementAdjuster.initialDistance(widget.placement);
  double _heightOffset = 0;
  double _yawDegrees = 0;

  void _update({double? distance, double? heightOffset, double? yawDegrees}) {
    final base = widget.placement;
    if (base == null) {
      return;
    }
    _distance = distance ?? _distance;
    _heightOffset = heightOffset ?? _heightOffset;
    _yawDegrees = yawDegrees ?? _yawDegrees;
    final updated = PhotoFramePlacementAdjuster(
      base: base,
      cameraPosition: widget.cameraPosition,
      cameraForward: widget.cameraForward,
    ).adjust(
      distance: _distance,
      heightOffset: _heightOffset,
      yawDegrees: _yawDegrees,
    );
    widget.onPlacementChanged(updated);
    setState(() => _placement = updated);
  }

  Widget _slider({
    required Key key,
    required String label,
    required double min,
    required double max,
    required int divisions,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        Slider(
          key: key,
          min: min,
          max: max,
          divisions: divisions,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('ar_snapshot_confirmation_dialog'),
      title: const Text('Review AR photo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(JzRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.memory(
                  widget.bytes,
                  key: const ValueKey('ar_snapshot_confirmation_image'),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(
                    height: 120,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.view_in_ar, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    arSnapshotPlacementLabel(_placement),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Publish now hangs the frame where you took the photo, with your '
              'default settings. Review & publish lets you add a caption, '
              'privacy and walls. Moving it away from a detected surface '
              'saves a free-space pose.',
              style: theme.textTheme.bodySmall,
            ),
            if (widget.needsCalibration) ...[
              const SizedBox(height: 6),
              Text(
                'GPS or compass is rough here. The frame will hang in this AR '
                'session but may drift when you come back.',
                key: const ValueKey('ar_snapshot_calibration_note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (widget.placement != null) ...[
              const SizedBox(height: 16),
              _slider(
                key: const ValueKey('ar_frame_review_distance_slider'),
                label: 'Distance • ${_distance.toStringAsFixed(1)} m',
                min: PhotoFramePlacementAdjuster.minDistanceMeters,
                max: PhotoFramePlacementAdjuster.maxDistanceMeters,
                divisions: 45,
                value: _distance,
                onChanged: (value) => _update(distance: value),
              ),
              _slider(
                key: const ValueKey('ar_frame_review_height_slider'),
                label: 'Height offset • ${_heightOffset.toStringAsFixed(1)} m',
                min: -PhotoFramePlacementAdjuster.heightRangeMeters,
                max: PhotoFramePlacementAdjuster.heightRangeMeters,
                divisions: 40,
                value: _heightOffset,
                onChanged: (value) => _update(heightOffset: value),
              ),
              _slider(
                key: const ValueKey('ar_frame_review_yaw_slider'),
                label: 'Yaw • ${_yawDegrees.toStringAsFixed(0)}°',
                min: -180,
                max: 180,
                divisions: 72,
                value: _yawDegrees,
                onChanged: (value) => _update(yawDegrees: value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('ar_snapshot_retake_button'),
          onPressed: () =>
              Navigator.of(context).pop(ARSnapshotReviewResult.retake),
          child: const Text('Retake'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('ar_snapshot_publish_now_button'),
          onPressed: () =>
              Navigator.of(context).pop(ARSnapshotReviewResult.publishNow),
          icon: const Icon(Icons.bolt),
          label: Text(widget.needsCalibration ? 'Publish anyway' : 'Publish now'),
        ),
        FilledButton.icon(
          key: const ValueKey('ar_snapshot_use_button'),
          onPressed: () =>
              Navigator.of(context).pop(ARSnapshotReviewResult.review),
          icon: const Icon(Icons.edit_note),
          label: const Text('Review & publish'),
        ),
      ],
    );
  }
}
