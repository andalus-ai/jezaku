import 'package:flutter/material.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

/// HUD chip that tells the user whether memories are placed precisely
/// (native geospatial lock) or approximately (GPS and compass only).
///
/// Tap or long-press shows the reason, for example "Locating you" or
/// "Position is not accurate enough yet".
class ARPlacementQualityChip extends StatelessWidget {
  const ARPlacementQualityChip({super.key, required this.assessment});

  final JejakuGeospatialAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    // The camera HUD stays dark in both app themes. Use container accents in
    // light mode and their brighter foreground counterparts in dark mode so
    // the status remains legible against the translucent HUD background.
    final color = assessment.isPrecise
        ? (isDark ? colorScheme.primary : colorScheme.primaryContainer)
        : (isDark ? colorScheme.tertiary : colorScheme.tertiaryContainer);

    return Tooltip(
      message: assessment.detailLabel,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: Semantics(
        liveRegion: true,
        label: 'Placement ${assessment.shortLabel}. ${assessment.detailLabel}',
        hint: 'Tap for placement accuracy details',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  assessment.isPrecise ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  assessment.shortLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
