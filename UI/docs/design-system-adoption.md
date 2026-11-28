# Adopting the Jezaku design system (JzDS)

The shared design system lives in [`andalus-ai/jezaku-ds`](https://github.com/andalus-ai/jezaku-ds)
(package `jezaku_ds`: tokens, Material 3 themes, `JzButton`, `JzCard`, `JzBadge`,
`JzTextField`, `JzEmptyState`). This page records how the end-user app consumes
it and what is still to do. See [design-system-and-ux.md](design-system-and-ux.md)
for the UX standards the tokens serve.

## Dependency

`UI/jezaku/pubspec.yaml` takes `jezaku_ds` as a git dependency **pinned to a
reviewed commit** (`3159d82`), as the design system's own adoption plan
requires. Bump the `ref` deliberately, after reading the design system's
changes; do not point it at a branch.

## The `material_ui` type split

The app imports `package:material_ui/material_ui.dart` (see the import
convention in `AGENTS.md`). `jezaku_ds` is written against
`package:flutter/material.dart`. Flutter treats these as **different types**
with identical names, so:

- `JzTheme.light()` returns a `flutter/material` `ThemeData` and cannot be given
  to the app's `MaterialApp`.
- `JzThemeTokens` is a `flutter/material` `ThemeExtension` and cannot be added
  to the app's `ThemeData.extensions`.
- Anything built only from `Color`, `double` and other `dart:ui`/Dart values
  (`JzColors`, `JzSpacing`, `JzRadius`, `JzElevation`, `JzTypography`) crosses
  the boundary freely.
- `jezaku_ds` widgets (`JzButton`, …) read `Theme.of(context)` from
  `flutter/material`; inside a `material_ui` app they only see the right theme
  through `MaterialUiCompatibilityBridge`, which Flutter documents as a
  temporary, deprecated aid.

The durable fix is for `jezaku_ds` to migrate to `material_ui` itself (a change
in that repository). Until then the app adopts the design system through the
values that cross cleanly.

## What is adopted (slice 1)

| Area | How |
| --- | --- |
| Seed colour | `JejakuTheme` uses `JzColors.seed` (previously `0xFF6366F1`, now `0xFF5146D8`). This is a visible brand-colour change. |
| Shape / elevation | FAB, card and input shapes use `JzRadius`; elevations use `JzElevation`; input padding uses `JzSpacing`. |
| Card and input themes | Same as `JzTheme`: flat bordered cards, filled inputs with a subtle surface and focus ring. |
| Status colours | `JezakuStatusColors` (a `material_ui` `ThemeExtension`) exposes `success`, `warning`, `danger`, `info`, `surfaceSubtle` and `border`, read from `JzTheme` so light/dark values never fork. Use `JezakuStatusColors.of(context)` — never a raw hex — and pair colour with text or an icon. |

`test/app_theme_test.dart` asserts the app's colour scheme equals
`JzTheme`'s for the same brightness and that the status colours mirror
`JzThemeTokens`, so drift from the design system fails CI.

## Not yet done

- Migrating screens from raw colours/paddings to `JezakuStatusColors`,
  `JzSpacing` and `JzRadius` (do it per feature, one PR each).
- Using `JzButton` / `JzCard` / `JzBadge` / `JzTextField` / `JzEmptyState`
  directly (blocked on the type split above: either `jezaku_ds` moves to
  `material_ui`, or the app wraps in `MaterialUiCompatibilityBridge`).
- Contrast review: the design system states formal contrast review is pending.
- Spatial/AR overlays: `jezaku_ds_ar` is planned but does not exist yet; AR HUD
  widgets stay in the app.
- `pubspec.lock` must be regenerated (`flutter pub get`) and committed.

## Validation status

Not run locally: the authoring environment has no Flutter SDK. Verify with
`flutter pub get`, `flutter analyze`, `flutter test`, then compare light and
dark themes on a physical device (cards, text fields, FAB, navigation bar,
dialogs, and any screen with status colours) because the card/input/seed
changes alter the look of every screen.
