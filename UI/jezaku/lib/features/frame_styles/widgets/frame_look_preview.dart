import 'package:jejaku/features/frame_styles/models/frame_look.dart';
import 'package:jejaku/features/frame_styles/services/frame_style_resolver.dart';
import 'package:material_ui/material_ui.dart';

/// A small flat picture of a frame look: a mat and a photo stand-in inside the
/// look's border colour. Used by the gallery and anywhere a frame style needs
/// a thumbnail.
class FrameLookPreview extends StatelessWidget {
  const FrameLookPreview({
    required this.lookId,
    this.colorValue,
    this.size = 72,
    super.key,
  });

  final String lookId;
  final int? colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Color(FrameStyleResolver.previewColorValue(lookId, colorValue));
    final borderWidth =
        size * FrameStyleResolver.previewBorderFraction(lookId) + 2;
    return Container(
      width: size,
      height: size * 1.2,
      decoration: BoxDecoration(
        color: border,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(borderWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.landscape_outlined,
            size: size * 0.36,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// The catalog entry for [lookId], for labels next to previews.
String frameLookLabel(String lookId) => frameLookById(lookId).label;
