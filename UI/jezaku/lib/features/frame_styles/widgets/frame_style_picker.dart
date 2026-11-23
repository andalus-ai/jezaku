import 'package:jejaku/features/frame_styles/models/frame_look.dart';
import 'package:jejaku/features/frame_styles/widgets/frame_look_preview.dart';
import 'package:material_ui/material_ui.dart';

/// The frame gallery: pick a look from the catalog, then optionally recolour
/// it. Stateless; the owner keeps the selection.
class FrameStylePicker extends StatelessWidget {
  const FrameStylePicker({
    required this.lookId,
    required this.colorValue,
    required this.onLookChanged,
    required this.onColorChanged,
    super.key,
  });

  final String lookId;
  final int? colorValue;
  final ValueChanged<String> onLookChanged;

  /// Null clears the colour override ("Original").
  final ValueChanged<int?> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedLook = frameLookById(lookId).id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frame style', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 136,
          child: ListView.separated(
            key: const ValueKey('frame_look_list'),
            scrollDirection: Axis.horizontal,
            itemCount: builtInFrameLooks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final look = builtInFrameLooks[index];
              final selected = look.id == selectedLook;
              return Semantics(
                button: true,
                selected: selected,
                label: '${look.label} frame',
                child: InkWell(
                  key: ValueKey('frame_look_${look.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onLookChanged(look.id),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: selected ? 2 : 1,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        FrameLookPreview(
                          lookId: look.id,
                          colorValue: colorValue,
                          size: 56,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          look.label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Colour', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Swatch(
              key: const ValueKey('frame_color_original'),
              label: 'Original colour',
              selected: colorValue == null,
              onTap: () => onColorChanged(null),
              child: const Icon(Icons.format_color_reset_outlined, size: 18),
            ),
            for (final value in frameColorChoices)
              _Swatch(
                key: ValueKey('frame_color_$value'),
                label: 'Colour ${value.toRadixString(16)}',
                selected: colorValue == value,
                color: Color(value),
                onTap: () => onColorChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.child,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          // 44 px keeps the touch target at the accessibility minimum.
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? scheme.surfaceContainerHighest,
            border: Border.all(
              width: selected ? 3 : 1,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
