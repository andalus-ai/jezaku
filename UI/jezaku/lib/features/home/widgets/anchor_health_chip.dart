import 'package:flutter/material.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

class AnchorHealthChip extends StatelessWidget {
  const AnchorHealthChip({
    super.key,
    required this.anchor,
    this.compact = false,
  });

  final AnchorMemory anchor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final healthColor = _healthColor(colorScheme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: healthColor.container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: compact ? 13 : 15, color: healthColor.onColor),
            const SizedBox(width: 5),
            Text(
              anchor.anchorHealthLabel,
              style: TextStyle(
                color: healthColor.onColor,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    if (anchor.needsCalibrationReview) {
      return Icons.warning_amber;
    }
    if (anchor.captureMetadata.hasManualCorrection) {
      return Icons.tune;
    }
    return Icons.verified_outlined;
  }

  _HealthColor _healthColor(ColorScheme colorScheme) {
    if (anchor.needsCalibrationReview) {
      return _HealthColor(
        container: colorScheme.errorContainer,
        onColor: colorScheme.onErrorContainer,
      );
    }
    if (anchor.captureMetadata.hasManualCorrection) {
      return _HealthColor(
        container: colorScheme.tertiaryContainer,
        onColor: colorScheme.onTertiaryContainer,
      );
    }
    return _HealthColor(
      container: colorScheme.primaryContainer,
      onColor: colorScheme.onPrimaryContainer,
    );
  }
}

class _HealthColor {
  const _HealthColor({
    required this.container,
    required this.onColor,
  });

  final Color container;
  final Color onColor;
}
