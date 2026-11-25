import 'package:flutter/material.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_access.dart';

/// "12 m", "340 m", "1.2 km"; null when the distance is not known.
String? formatFrameDistance(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) {
    return null;
  }
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

/// Why a surface cannot open a frame, in a sentence for a snackbar or screen
/// reader; null when it can ([FrameAccessOpen]). [fallbackPlace] names the place
/// when the frame itself is not loaded.
String? blockedFrameMessage(FrameAccess access, {String? fallbackPlace}) {
  return switch (access) {
    FrameAccessOpen() => null,
    FrameAccessUnavailable() => 'This frame is no longer available.',
    final FrameAccessLocked locked =>
      LockedFrameCard.messageFor(locked, fallbackPlace: fallbackPlace),
  };
}

/// What a surface shows instead of someone else's frame when the viewer is
/// not on site: the place and the distance, no photo and no comments.
class LockedFrameCard extends StatelessWidget {
  const LockedFrameCard({
    super.key,
    required this.access,
    this.fallbackPlace,
  });

  final FrameAccessLocked access;

  /// Used when the frame itself is not loaded, such as a post's own place
  /// label.
  final String? fallbackPlace;

  /// The text a screen reader (and a snackbar) gets for the card.
  static String messageFor(FrameAccessLocked access, {String? fallbackPlace}) {
    final place = access.placeLabel ?? fallbackPlace;
    final distance = formatFrameDistance(access.distanceMeters);
    final go = place == null ? 'Go to this frame' : 'Go to $place';
    return distance == null
        ? '$go to open it. Frames open only on site.'
        : '$go to open it. $distance away. Frames open only on site.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final place = access.placeLabel ?? fallbackPlace;
    final distance = formatFrameDistance(access.distanceMeters);
    return Semantics(
      container: true,
      label: messageFor(access, fallbackPlace: fallbackPlace),
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('locked_frame_card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: colors.primary, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place == null ? 'Go to this frame' : 'Go to $place',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distance == null
                          ? 'Frames open only on site.'
                          : '$distance away · Frames open only on site.',
                      style: Theme.of(context).textTheme.bodySmall,
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
