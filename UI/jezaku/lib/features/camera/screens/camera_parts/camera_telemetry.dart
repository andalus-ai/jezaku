part of '../camera_screen.dart';

class _CaptureTelemetry extends StatelessWidget {
  const _CaptureTelemetry({
    required this.snapshot,
    required this.statusLabel,
  });

  final CaptureSensorSnapshot snapshot;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TelemetryBadge(
                    icon: Icons.radio_button_checked,
                    label: statusLabel,
                  ),
                  _TelemetryBadge(
                    icon: Icons.verified_outlined,
                    label: snapshot.qualityLabel,
                  ),
                  _TelemetryBadge(
                    icon: Icons.insights_outlined,
                    label: snapshot.placementConfidencePercentLabel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CaptureReadinessPanel(snapshot: snapshot),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TelemetryMetric(
                    icon: Icons.place_outlined,
                    label: 'Lat/Long',
                    value: snapshot.locationLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.terrain_outlined,
                    label: 'Altitude',
                    value: snapshot.altitudeLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.navigation,
                    label: 'Direction',
                    value: snapshot.compassLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.gps_fixed,
                    label: 'Accuracy',
                    value: snapshot.accuracyLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.screen_rotation_alt_outlined,
                    label: 'Pitch/Roll',
                    value: snapshot.attitudeLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.auto_graph_outlined,
                    label: 'Confidence',
                    value: snapshot.placementConfidenceLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.sensors_outlined,
                    label: 'Source',
                    value: snapshot.captureSource,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureReadinessPanel extends StatelessWidget {
  const _CaptureReadinessPanel({required this.snapshot});

  final CaptureSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (snapshot.captureReadinessLevel) {
      CaptureReadinessLevel.ready => Colors.greenAccent,
      CaptureReadinessLevel.steady => Colors.amberAccent,
      CaptureReadinessLevel.calibrate => Colors.orangeAccent,
    };

    return DecoratedBox(
      key: const ValueKey('capture_readiness_panel'),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconForReadiness(snapshot.captureReadinessLevel),
                  color: accentColor,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    snapshot.captureReadinessLabel,
                    key: const ValueKey('capture_readiness_label'),
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
            const SizedBox(height: 4),
            Text(
              snapshot.captureGuidanceLabel,
              key: const ValueKey('capture_guidance_label'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SensorStatusChip(
                  key: const ValueKey('capture_gps_status_chip'),
                  icon: Icons.gps_fixed,
                  label: snapshot.gpsStabilityLabel,
                ),
                _SensorStatusChip(
                  key: const ValueKey('capture_compass_status_chip'),
                  icon: Icons.explore_outlined,
                  label: snapshot.compassStabilityLabel,
                ),
                _SensorStatusChip(
                  key: const ValueKey('capture_tilt_status_chip'),
                  icon: Icons.screen_rotation_alt_outlined,
                  label: snapshot.attitudeStabilityLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForReadiness(CaptureReadinessLevel level) {
    return switch (level) {
      CaptureReadinessLevel.ready => Icons.check_circle_outline,
      CaptureReadinessLevel.steady => Icons.motion_photos_pause_outlined,
      CaptureReadinessLevel.calibrate => Icons.warning_amber_outlined,
    };
  }
}

class _SensorStatusChip extends StatelessWidget {
  const _SensorStatusChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryBadge extends StatelessWidget {
  const _TelemetryBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryMetric extends StatelessWidget {
  const _TelemetryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 126, maxWidth: 178),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

Map<String, List<String>> _wallTitlesByMemoryId(Iterable<ARWall> walls) {
  final titlesByMemoryId = <String, List<String>>{};
  for (final wall in walls) {
    for (final memoryId in wall.linkedMemoryIds) {
      titlesByMemoryId.update(
        memoryId,
        (titles) => [...titles, wall.title],
        ifAbsent: () => [wall.title],
      );
    }
  }
  return titlesByMemoryId;
}
