part of '../ar_viewer_screen.dart';

enum _TrailTimelineStatus {
  completed,
  current,
  missing,
  upcoming;

  String get key {
    return switch (this) {
      _TrailTimelineStatus.completed => 'completed',
      _TrailTimelineStatus.current => 'current',
      _TrailTimelineStatus.missing => 'missing',
      _TrailTimelineStatus.upcoming => 'upcoming',
    };
  }

  String stopLabel(int stopNumber) {
    return switch (this) {
      _TrailTimelineStatus.completed => 'Stop $stopNumber completed',
      _TrailTimelineStatus.current => 'Stop $stopNumber current',
      _TrailTimelineStatus.missing => 'Stop $stopNumber missing before finish',
      _TrailTimelineStatus.upcoming => 'Stop $stopNumber upcoming',
    };
  }
}

class _NextStopDirectionCue extends StatelessWidget {
  const _NextStopDirectionCue({
    required this.step,
    required this.headingDegrees,
  });

  final AnchorJourneyStep step;
  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    final bearingDegrees = step.nextLegBearingDegrees;
    final directionLabel = step.nextLegDirectionLabel;
    if (bearingDegrees == null || directionLabel == null) {
      return const SizedBox.shrink();
    }

    final relativeDegrees = _relativeBearingDegrees(
      bearingDegrees,
      headingDegrees,
    );

    return DecoratedBox(
      key: const ValueKey('ar_journey_direction_cue'),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.shade100.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.cyanAccent.shade100.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: relativeDegrees * math.pi / 180,
              child: Icon(
                Icons.navigation,
                color: Colors.cyanAccent.shade100,
                size: 17,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_turnLabel(relativeDegrees)} toward $directionLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.cyanAccent.shade100,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _relativeBearingDegrees(double bearingDegrees, double headingDegrees) {
  return ((bearingDegrees - headingDegrees + 540) % 360) - 180;
}

String _turnLabel(double relativeDegrees) {
  final absoluteDegrees = relativeDegrees.abs();
  if (absoluteDegrees <= 15) {
    return 'Ahead';
  }
  if (absoluteDegrees <= 60) {
    return relativeDegrees >= 0 ? 'Slight right' : 'Slight left';
  }
  if (absoluteDegrees <= 125) {
    return relativeDegrees >= 0 ? 'Turn right' : 'Turn left';
  }
  return 'Behind you';
}

Offset _arRadarOffsetFor({
  required Size size,
  required double radiusFraction,
  required double bearingDegrees,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (math.min(size.width, size.height) / 2 - 9) * radiusFraction;
  final radians = bearingDegrees * math.pi / 180;
  return center +
      Offset(math.sin(radians) * radius, -math.cos(radians) * radius);
}

double _radarRadiusFraction(
  ARMemoryProjection anchor,
  double radiusMeters,
) {
  return (anchor.projection.horizontalDistanceMeters / radiusMeters)
      .clamp(0.12, 1)
      .toDouble();
}
