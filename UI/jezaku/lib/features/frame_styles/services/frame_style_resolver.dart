import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/frame_styles/models/frame_look.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

/// Turns a frame's look and colour choice into what the AR scene and the
/// Flutter previews need. Pure: no widgets, no state.
class FrameStyleResolver {
  const FrameStyleResolver._();

  /// The colour that wins: the frame's own override, else the look's colour,
  /// else null (the preset's own materials).
  static int? effectiveColorValue(String? lookId, int? colorValue) {
    return colorValue ?? frameLookById(lookId).colorValue;
  }

  /// Scene anchor metadata for the `jezaku_ar` photo frame. Empty for the
  /// untouched classic look, so existing frames produce exactly what they did
  /// before this feature existed.
  static Map<String, Object?> sceneMetadata({
    required String? lookId,
    int? colorValue,
  }) {
    final look = frameLookById(lookId);
    final color = effectiveColorValue(look.id, colorValue);
    if (look.id == defaultFrameLookId && color == null) {
      return const <String, Object?>{};
    }
    final metadata = <String, Object?>{'photoFramePreset': look.preset.name};
    if (color == null) {
      return metadata;
    }
    final base = JejakuHangingPhotoFrameStyle.fromPreset(look.preset);
    final frameColor = _arColor(color);
    metadata['photoFrameStyle'] = <String, Object?>{
      'preset': look.preset.name,
      'frameMaterial': base.frameMaterial.copyWith(baseColor: frameColor).toMap(),
      'backingMaterial': base.backingMaterial
          .copyWith(baseColor: _mix(frameColor, 0, 0.45))
          .toMap(),
      'highlightMaterial': base.highlightMaterial
          .copyWith(baseColor: _mix(frameColor, 1, 0.22))
          .toMap(),
    };
    return metadata;
  }

  /// ARGB colour to draw a flat preview of the frame with.
  static int previewColorValue(String? lookId, int? colorValue) {
    final override = effectiveColorValue(lookId, colorValue);
    if (override != null) {
      return override;
    }
    final preset = frameLookById(lookId).preset;
    final base = JejakuHangingPhotoFrameStyle.fromPreset(preset);
    // The presets' own colours are very dark; lift them so a preview is
    // readable against a dark or a light surface.
    final lifted = _mix(base.frameMaterial.baseColor, 1, 0.3);
    return _argb(lifted, alpha: base.frameMaterial.opacity < 1 ? 0.55 : 1);
  }

  /// The frame border as a fraction of the photo's short side, for previews.
  static double previewBorderFraction(String? lookId) {
    final style = JejakuHangingPhotoFrameStyle.fromPreset(
      frameLookById(lookId).preset,
    );
    return (style.borderMeters / 0.9).clamp(0.03, 0.12).toDouble();
  }

  static ARMaterialColor _arColor(int value) {
    return ARMaterialColor(
      r: ((value >> 16) & 0xFF) / 255,
      g: ((value >> 8) & 0xFF) / 255,
      b: (value & 0xFF) / 255,
    );
  }

  /// Mixes [color] toward [target] (0 black, 1 white) by [amount].
  static ARMaterialColor _mix(ARMaterialColor color, double target, double amount) {
    double channel(double value) => value + (target - value) * amount;
    return ARMaterialColor(
      r: channel(color.r),
      g: channel(color.g),
      b: channel(color.b),
      a: color.a,
    );
  }

  static int _argb(ARMaterialColor color, {double alpha = 1}) {
    int byte(double value) => (value.clamp(0, 1) * 255).round();
    return (byte(alpha) << 24) |
        (byte(color.r) << 16) |
        (byte(color.g) << 8) |
        byte(color.b);
  }
}
