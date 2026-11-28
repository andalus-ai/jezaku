# JzDS adoption in Jezaku

## Decision

Jezaku adopts the standalone **Jezaku Design System (JzDS)** package, `jezaku_ds`, from `andalus-ai/jezaku-ds`. The consuming applications pin an immutable Git commit so dependency updates are deliberate and reviewable.

Current pilot pin: `3159d821b1fe1ee5c5f0b5c4ddaf27f93d993163`.

## Responsibilities

- JzDS owns reusable presentation primitives, semantic design tokens, and theme foundations.
- The end-user app owns product journeys, navigation, app state, and AR-specific presentation.
- The Admin app continues to use Alhambra for platform foundations and adopts JzDS for shared Jezaku UI components.
- Backend services remain authoritative for permissions, visibility, moderation, and privileged operations.
- JzDS must not depend on ARCore, Jezaku app code, backend APIs, Riverpod, or Alhambra.

## Pilot scope

- End-user app: replace the two action buttons in `MemoryEmptyState` with `JzButton` while preserving its existing semantics and callbacks.
- Admin app: use `JzButton` for the retry action in `AdminFeedbackState`.
- Widget tests cover the existing end-user actions and the Admin retry callback.

## Theme tokens and the `material_ui` type split

The app theme itself (seed colour, radii, status colours) is adopted separately;
see [design-system-adoption.md](design-system-adoption.md), which also explains
why `JzTheme` and `JzThemeTokens` cannot be installed on this app's
`material_ui` `ThemeData`, and what that means for `Jz*` widgets (they read the
`flutter/material` theme, not the app's).

## Dependency policy

Use the same immutable commit in both app manifests and lockfiles. Do not depend on a moving branch. Upgrade only after reviewing the JzDS changelog, API compatibility, package CI, and both consuming-app test suites. Move to a release tag when JzDS establishes a stable release process.

## Migration sequence

1. Validate the pilot in both apps and refine component APIs from real usage.
2. Migrate shared, low-risk controls and feedback states before complex feature screens.
3. Migrate app theme tokens gradually; preserve app-specific color roles and camera/AR contrast requirements.
4. Add optional AR-specific components in a separate package that depends on JzDS; never put AR dependencies in the core design system.
5. Remove duplicated app-level primitives only after equivalent JzDS coverage and tests exist.

## Validation

Run `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test` independently in `UI/jezaku` and `UI/jezaku_admin`. Physical-device AR validation is not part of this UI-only pilot.
