# UI Agent Instructions

These instructions apply to everything under `UI/`. Read this file before changing UI code.

## Scope and architecture

- The product application is the Flutter app in `UI/jezaku/`.
- Reusable AR capabilities are maintained as local Dart packages under `UI/Packages/` (currently including `ar_engine`, `ar_engine_testkit`, `ar_model_cache`, and `jezaku_ar`).
- Keep application-specific screens, navigation, product workflows, and composition in the app. Keep reusable AR engine behavior and package-level abstractions in the appropriate package.
- Keep platform-specific code in the corresponding Flutter platform folders and behind explicit, documented interfaces.
- Consult `UI/docs/architecture.md` and the root `docs/UI_UX_POLISH_PLAN.md` before substantial UI or interaction work.

## Required engineering practices

1. Inspect the existing feature, its state management, routing, theme, and tests before editing. Extend established patterns instead of introducing parallel frameworks.
2. Use Flutter and Dart versions compatible with `UI/jezaku/pubspec.yaml`. Do not upgrade dependencies or SDK constraints without a concrete reason.
3. Use Riverpod for app state where the existing app uses it. Keep widgets focused; move domain logic and side effects into providers, controllers, or services.
4. Keep widgets declarative and reusable. Avoid business rules, network calls, permission orchestration, or persistence logic embedded in build methods.
5. Use the shared design tokens and components. Do not add one-off colors, spacing, typography, radii, or elevation values when a semantic token exists.
6. Treat loading, empty, error, offline, permission-denied, and stale-data states as first-class UI states.
7. Design for compact phones, larger phones, tablets, text scaling, safe areas, keyboard navigation where applicable, and screen readers.
8. Respect privacy and safety: explain location/camera permissions in context, request only when needed, and never expose private location or social data in UI logs.
9. Keep AR lifecycle and camera resources deterministic. Dispose controllers, subscriptions, sensors, streams, and platform resources; handle app pause/resume and permission revocation.
10. Preserve offline-first behavior and user-created content. Do not silently discard queued captures or pending sync work.

## UI/UX quality bar

- Every screen has a clear primary action and a predictable back/navigation path.
- Touch targets are comfortable and controls have clear labels and accessible semantics.
- Motion is purposeful, brief, and respects reduced-motion/accessibility settings where supported.
- Map and AR overlays preserve camera/map legibility and do not obscure critical controls.
- Permission, accuracy, tracking, upload, and sync status must be understandable without exposing implementation jargon.
- Destructive, public-sharing, and location-sensitive actions require clear confirmation or scope disclosure.

## Testing and validation

Run commands from `UI/jezaku/` unless noted:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

- Add widget tests for visible behavior and state transitions.
- Add unit tests for providers, repositories, formatters, and domain logic.
- Add integration tests for critical capture, permission, navigation, and sync journeys when feasible.
- For reusable packages, run tests from each changed package directory and test the consuming app.
- Do not claim a test passed unless it was actually run. If Flutter tooling or platform hardware is unavailable, state that explicitly.
- For AR/camera changes, document the physical-device validation still required; simulator success is not proof of sensor or tracking correctness.

## Change discipline

- Keep changes focused and avoid unrelated refactors.
- Update relevant docs when public behavior, package contracts, setup, or architecture changes.
- Do not commit generated build output, secrets, local device data, or credentials.
- Never hardcode API keys, signing credentials, private endpoints, or user identifiers.
- Prefer explicit typed models and error handling over dynamic maps and swallowed exceptions.
- When changing an API integration, coordinate request/response changes with `Backend/` and update the contract documentation.
