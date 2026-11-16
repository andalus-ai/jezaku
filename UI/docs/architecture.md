# Jezaku UI Architecture

## 1. Purpose and technology

The UI is the cross-platform Flutter client for Jezaku's spatial-social camera experience. The application lives in `UI/jezaku/`; reusable Dart/Flutter capabilities live in `UI/Packages/`.

The app currently uses:
- Flutter and Dart (SDK constraint is defined in `UI/jezaku/pubspec.yaml`).
- Riverpod for state management.
- Dio for HTTP networking.
- Geolocator, compass, and sensor packages for location and device orientation.
- Camera and image/EXIF packages for capture workflows.
- Google Maps Flutter for map presentation.
- Local preferences and path-provider storage for lightweight settings and device files.
- Local AR packages: `ar_engine`, `ar_model_cache`, `jezaku_ar`, and `ar_engine_testkit`.

Treat the checked-in dependency manifest as the source of truth; this document describes architectural intent, not permission to add dependencies.

## 2. Repository map

```text
UI/
├── AGENTS.md
├── docs/
└── Packages/
    ├── ar_engine/
    ├── ar_engine_testkit/
    ├── ar_model_cache/
    └── jezaku_ar/
    UI/jezaku/
        ├── lib/
        │   ├── app/
        │   ├── features/
        │   └── main.dart
        ├── test/
        ├── integration_test/
        ├── assets/
        └── platform projects (android, ios, web, desktop)
```

The `lib/app/` area owns application composition and cross-cutting concerns. The `lib/features/` area owns product capabilities. Keep feature code cohesive and avoid importing another feature's internal implementation; expose stable interfaces when cross-feature collaboration is needed.

## 3. Responsibility boundaries

### Application (`UI/jezaku/lib/app`)

Owns app bootstrap, dependency/provider composition, navigation, global theme, app lifecycle integration, and cross-cutting error handling.

### Features (`UI/jezaku/lib/features`)

Owns product-facing screens, feature state/controllers, feature-specific domain models, and orchestration for user journeys. A feature should not directly own reusable low-level AR runtime mechanics.

### Reusable packages (`UI/Packages`)

- `ar_engine`: platform-neutral AR runtime contracts and orchestration abstractions.
- `ar_engine_testkit`: test fakes, fixtures, and utilities for consumers of the AR engine.
- `ar_model_cache`: local model/asset caching concerns.
- `jezaku_ar`: Jezaku-specific integration/adapters that connect app needs to reusable AR capabilities.

Keep the AR engine neutral and reusable. Avoid importing Jezaku product concepts into generic engine APIs. Platform implementations should be hidden behind package interfaces and capability checks.

## 4. Recommended feature organization

As features evolve, keep each feature organized around clear responsibilities. A practical shape is:

```text
features/<feature>/
├── presentation/   # screens, widgets, view models
├── application/    # controllers, providers, use-case orchestration
├── domain/         # entities, value objects, repository contracts
└── data/           # API/local adapters, DTOs, repository implementations
```

Do not create empty layers for their own sake. Small features may remain simpler, but keep UI, domain decisions, and infrastructure concerns distinguishable.

## 5. State and data flow

- Widgets render state and forward user intent; they should not own long-running business workflows.
- Riverpod providers/controllers coordinate feature state and lifecycle.
- Domain/repository interfaces define what a feature needs; data adapters implement HTTP, local persistence, and platform integration.
- Dio clients should be configured centrally for base URL, timeouts, serialization, request IDs, and error mapping.
- Parse remote responses into typed models at the boundary. Avoid leaking raw JSON maps through the widget tree.
- Model loading, success, empty, recoverable error, offline/stale, and permission-required states explicitly.
- Cancel or invalidate in-flight work when a feature is disposed or its query context changes.

A typical request path is:

```text
Widget -> Riverpod controller/provider -> use case/repository
       -> remote or local data source -> typed result -> UI state
```

## 6. Key product workflows

### Capture

1. Explain the purpose of camera/location access before requesting permissions when appropriate.
2. Check camera, location, and sensor capability/permission independently.
3. Capture media and a timestamped metadata snapshot (coordinates, accuracy, altitude where available, heading/orientation where available).
4. Keep capture usable when optional sensors or network are unavailable; mark unavailable/low-confidence metadata rather than inventing values.
5. Persist a durable local capture/queue record before attempting background upload.
6. Present upload, retry, and sync state clearly.

### Discovery and map

- Keep map camera state, selected item, filters, and list/map presentation state coordinated.
- Handle location denial, approximate location, stale fixes, no nearby results, and network failures.
- Avoid frequent high-cost location updates when the screen does not need them.
- Use clustering or bounded result sets where density requires it.
- Respect server visibility decisions; never infer access from UI state alone.

### AR viewing

- Check device/platform capabilities before starting a session.
- Keep camera, tracking, location, and anchor confidence distinct in the UI.
- Handle unsupported devices, unavailable geospatial services, permission changes, tracking degradation, and lifecycle interruptions.
- Keep rendering and platform-specific mechanics inside AR package boundaries.
- Follow [AR viewer performance budgets](../../docs/AR_VIEWER_PERFORMANCE_BUDGETS.md) and [device validation](../../docs/AR_DEVICE_VALIDATION_V1.md).

## 7. Backend integration contract

- Backend services are independently owned modules under `Backend/`; see [backend architecture](../../Backend/docs/architecture.md).
- Use configured environment-specific base URLs; do not hardcode production hosts in feature code.
- Treat server authorization and visibility decisions as authoritative.
- Include request/correlation identifiers where supported and preserve them in diagnostics.
- Map API error envelopes into typed client errors without exposing stack traces or internal service details to users.
- Coordinate breaking changes with the backend owner and update API contract documentation.
- Do not log access tokens, signed media URLs, private content, exact coordinates, or sensitive profile data.

## 8. Offline and lifecycle requirements

- Persist capture intent and upload state before network operations.
- Use bounded retry with backoff and distinguish retryable from permanent failures.
- Make upload operations idempotent where the server contract supports it.
- Reconcile server-confirmed state before showing a queued item as published.
- Pause or release camera/sensor/AR resources on lifecycle transitions and reacquire safely on resume.
- Never delete user content merely because a sync attempt failed.

## 9. Testing strategy

- Unit tests: domain rules, mapping, providers/controllers, repository behavior, retry policies.
- Widget tests: visual states, interactions, accessibility labels, responsive behavior.
- Integration tests: sign-in/session, capture, upload/retry, map discovery, AR capability fallback, and navigation.
- Package tests: public contracts and platform adapter behavior using `ar_engine_testkit`.
- Physical device checks: camera lifecycle, permission flows, location accuracy, compass behavior, AR tracking, thermal load, and frame pacing.

## 10. Useful commands

Run from `UI/jezaku/`:

```bash
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test
```

Run package checks from the relevant `UI/Packages/<package>/` directory:

```bash
dart format lib test
flutter analyze
flutter test
```

Only run commands supported by the installed SDK and package configuration. Record unavailable hardware/device checks as outstanding rather than marking them complete.
