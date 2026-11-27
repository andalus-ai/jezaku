# Frame styles (frame gallery)

A frame's **look** is separate from its **visibility**. Looks are cosmetic and never change who may see a frame or from where: the owner/on-site rules in [frame-visibility-and-roadmap.md](frame-visibility-and-roadmap.md) are untouched.

## What users can do

- Pick the **default frame** in Settings → Default frame. New frames get it; existing frames keep theirs.
- After publishing, the **author** opens the photo page (or the focused-frame panel in AR) and taps **Change frame** to pick another look or just recolour it. Frames owned by someone else show no such control.
- A restyle is local and cosmetic: it does not queue the frame for upload.

## Built-in looks

Classic, Oak, Gold, Gallery white, Thin, Dark gallery, Floating glass, plus nine recolour swatches and "Original colour". Each look maps to an existing `jezaku_ar` photo-frame preset (`JejakuHangingPhotoFramePreset`); a colour rewrites the frame, backing and highlight materials.

## Code map (`lib/features/frame_styles/`)

| File | Role |
|---|---|
| `models/frame_look.dart` | `FrameLook`, the built-in catalog, `frameLookById` (unknown id falls back to classic), colour choices |
| `services/frame_style_resolver.dart` | Pure: look + colour → AR scene metadata (`photoFramePreset`, `photoFrameStyle`) and preview colours. Classic with no colour emits nothing, so existing frames render exactly as before |
| `widgets/frame_look_preview.dart`, `frame_style_picker.dart` | Reusable thumbnail and the gallery (look strip + colour swatches, 44 px targets, semantics) |
| `widgets/frame_style_sheet.dart` | Bottom sheet plus `changeFrameStyle` / `changeDefaultFrameStyle` |

Storage: `AnchorMemory.frameLookId` and `frameColorValue` (persisted as `frameLook` / `frameColor`; older records default to classic), `AppSettings.defaultFrameLookId` / `defaultFrameColorValue`. The AR scene already fingerprints metadata, so a restyle re-syncs the node.

## Fit with the platform roadmap

The look is referenced by a **stable id**, not by enum index or by materials. This is the seed of the platform's *object appearance* reference ([spatial-core](../../docs/spatial-core.md)) and of an *appearance extension* ([extension-architecture](../../docs/extension-architecture.md)): a marketplace look would be another catalog entry resolved by id. Nothing here weakens the frame visibility policy.

## Known limits

- Not synced yet: the memory service accepts and returns an optional `frameStyle` (the look id, see Backend/memory/README.md "Frame look"), and the owner can change a published frame's look with `PATCH /memories/{id}/frame-style`. The app sends the look when it publishes (through the outbox) but does not read it for other people's frames and does not call the change endpoint yet, so other devices still see the author's frame with the default look. The app side is the next step.
- Not validated on a physical device (see the checklist in [ar-device-demo-lab.md](ar-device-demo-lab.md)).
- Only built-in looks; no custom frame images or marketplace looks yet.
