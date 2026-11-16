# Jezaku Flutter Application Instructions

These instructions apply to the Flutter product application in this directory. Also follow [UI/AGENTS.md](../AGENTS.md) and the repository-level [AGENTS.md](../../AGENTS.md).

## Ownership

- This application owns product composition, user journeys, screens, navigation, app-level state wiring, and integrations with backend APIs and reusable packages.
- Keep reusable low-level AR runtime behavior in `../Packages/ar_engine/`; use `jezaku_ar` for Jezaku-specific AR adapters and workflows.
- Keep app-only orchestration and presentation here; do not move generic package functionality into the app merely to avoid defining a package contract.

## Implementation practices

1. Inspect the relevant feature under `lib/features/`, app composition under `lib/app/`, and related tests before editing.
2. Follow the existing Flutter/Dart SDK constraints and established Riverpod, routing, theme, and networking patterns. Verify manifests before adding dependencies.
3. Keep widgets declarative. Move asynchronous work, business decisions, and side effects into existing providers/controllers/services.
4. Parse API responses into typed models at boundaries; do not pass unvalidated dynamic JSON through presentation widgets.
5. Represent loading, empty, error, offline/stale, permission-denied, and partial-capability states where relevant.
6. Respect backend authorization and visibility decisions. Client-side filters are presentation controls, not security boundaries.
7. Request camera, location, and sensor permissions contextually and only when needed. Never expose exact private coordinates, tokens, or private content in logs.
8. Persist user capture intent before network upload where the workflow requires offline resilience. Do not discard pending user content on transient failures.
9. Release camera, AR, sensor, stream, and subscription resources deterministically; handle app pause/resume and permission revocation.
10. Use semantic design tokens and accessible labels. Validate text scaling, safe areas, touch targets, contrast, and supported screen sizes.

## Validation

Run from this directory when the Flutter SDK and dependencies are available:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Run integration tests with `flutter test integration_test` when the target environment supports them. Physical-device AR/camera/location validation remains necessary for hardware-dependent changes; simulator tests do not prove sensor or tracking correctness.

Do not report checks as passed unless they were run.
