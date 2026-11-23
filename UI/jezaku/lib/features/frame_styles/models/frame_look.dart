import 'package:jezaku_ar/jezaku_ar.dart';

/// One named look a photo frame can have: an AR frame preset (shape, depth,
/// materials) and, optionally, a base colour of its own.
///
/// The catalog below is the built-in set. Each look has a stable [id] that is
/// stored with the frame, so looks can later come from the extension
/// marketplace (an appearance extension) without changing how a frame refers
/// to its look.
class FrameLook {
  const FrameLook({
    required this.id,
    required this.label,
    required this.preset,
    this.colorValue,
  });

  final String id;
  final String label;
  final JejakuHangingPhotoFramePreset preset;

  /// ARGB base colour that replaces the preset's own, or null to keep it.
  final int? colorValue;
}

const defaultFrameLookId = 'classic';

/// The built-in frame looks, in the order the gallery shows them.
const builtInFrameLooks = <FrameLook>[
  FrameLook(
    id: defaultFrameLookId,
    label: 'Classic',
    preset: JejakuHangingPhotoFramePreset.classic,
  ),
  FrameLook(
    id: 'oak',
    label: 'Oak',
    preset: JejakuHangingPhotoFramePreset.classic,
    colorValue: 0xFFB5865A,
  ),
  FrameLook(
    id: 'gold',
    label: 'Gold',
    preset: JejakuHangingPhotoFramePreset.classic,
    colorValue: 0xFFD4AF37,
  ),
  FrameLook(
    id: 'gallery_white',
    label: 'Gallery white',
    preset: JejakuHangingPhotoFramePreset.thin,
    colorValue: 0xFFF5F2EA,
  ),
  FrameLook(
    id: 'thin',
    label: 'Thin',
    preset: JejakuHangingPhotoFramePreset.thin,
  ),
  FrameLook(
    id: 'dark_gallery',
    label: 'Dark gallery',
    preset: JejakuHangingPhotoFramePreset.darkGallery,
  ),
  FrameLook(
    id: 'glass',
    label: 'Floating glass',
    preset: JejakuHangingPhotoFramePreset.floatingGlass,
  ),
];

/// The look with [id]; the classic look for a null or unknown id, so a frame
/// that refers to a look this build does not know still renders.
FrameLook frameLookById(String? id) {
  for (final look in builtInFrameLooks) {
    if (look.id == id) {
      return look;
    }
  }
  return builtInFrameLooks.first;
}

/// Colours offered for recolouring any look (ARGB). The gallery also offers
/// "Original", which clears the override.
const frameColorChoices = <int>[
  0xFFF5F2EA, // white
  0xFF1A1A1A, // black
  0xFFB5865A, // oak
  0xFFD4AF37, // gold
  0xFFC0C0C0, // silver
  0xFFC0392B, // red
  0xFF2E6FD8, // blue
  0xFF2E8B57, // green
  0xFFE58FA8, // pink
];
