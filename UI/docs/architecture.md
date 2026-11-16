# Jezaku UI Architecture

## 1. Purpose and technology

The UI is the cross-platform Flutter client for Jezaku's spatial-social camera experience. The main application lives in `UI/jezaku/`; reusable Dart/Flutter packages live in `UI/Packages/`.

The app currently uses Flutter/Dart, Riverpod, Dio, geolocation and sensor packages, camera/image/EXIF packages, Google Maps Flutter, local preferences/path-provider storage, and the local AR packages. Exact versions and supported SDK constraints are defined by the checked-in manifests, especially `UI/jezaku/pubspec.yaml`.

Treat manifests and exported package APIs as the source of truth; this document describes architectural intent, not permission to add dependencies or claim unsupported platform behavior.

## 2. Repository map

```text
UI/
├── AGENTS.md
├── docs/
│   ├── README.md
│   ├── architecture.md
│   ├── app-structure.md
│   ├── package-catalog.md
│   └── design-system-and-ux.md
├── jezaku/
│   ├── AGENTS.md
│   ├── lib/
│   │   ├── app/
│   │   ├── features/
│   │   └── main.dart
│   ├── test/
│   ├── integration_test/
│   ├── assets/
│   └── platform projects (android, ios, web, desktop)
└── Packages/
    ├── AGENTS.md
    ├── ar_engine/
    ├── ar_engine_testkit/
    ├── ar_model_cache/
    └── jezaku_ar/
```

See [application structure](app-structure.md) and [package catalog](package-catalog.md) for detailed ownership.

## 3. Responsibility boundaries

### Application (`UI/jezaku`)

The application owns product composition, bootstrap, navigation, global provider/theme wiring, app lifecycle integration, product screens, and user workflows. Within `lib/`, `app/` contains cross-cutting app composition and `features/` contains product capabilities. Keep feature internals cohesive.

### Reusable packages (`UI/Packages`)

- `ar_engine`: generic multi-platform AR runtime, scene, and spatial primitives.
- `ar_engine_testkit`: deterministic platform fakes, fixtures, and test harnesses.
- `ar_model_cache`: model asset staging, caching, freshness, inspection, and retention.
- `jezaku_ar`: Jezaku-specific geospatial AR and memory integration built on the generic engine.

The intended dependency direction is app -> product integration/generic capability packages. Keep `ar_engine` free of Jezaku product concepts and keep testkit out of production dependency graphs.

## 4. Feature organization

Use the existing feature layout as the source of truth. As a feature grows, separate presentation, application orchestration, domain rules, and data adapters where this improves clarity. Do not create empty layers for their own sake. Avoid importing another feature's internal implementation; expose a stable interface when cross-feature collaboration is necessary.

## 5. State and data flow

- Widgets render state and forward user intent; they should not own long-running business workflows.
- Riverpod providers/controllers coordinate feature state and lifecycle, following existing app patterns.
- Domain/repository interfaces define what a feature needs; data adapters implement HTTP, local persistence, and platform integration.
- Configure Dio centrally for environment-specific base URLs, timeouts, serialization, request IDs, and error mapping.
- Parse remote responses into typed models at boundaries. Avoid leaking raw JSON maps through the widget tree.
- Model loading, success, empty, recoverable error, offline/stale, and permission-required states explicitly.
- Cancel or invalidate in-flight work when a feature is disposed or its query context changes.

Typical request path:

```text
Widget -> Riverpod controller/provider -> feature use case/repository
       -> remote or local data source -> typed result -> UI state
```

## 6. Product workflow requirements

### Capture

Explain camera/location access in context; check permissions and capabilities independently; capture timestamped metadata only when available; represent accuracy/confidence honestly; persist durable capture/queue state before upload where required; and make upload/retry state understandable.

### Discovery and map

Coordinate map camera, selection, filters, and list/map state. Handle denied/approximate/stale location, empty results, and network failures. Use bounded results or clustering where appropriate. The backend remains authoritative for visibility and authorization.

### AR viewing

Check platform/device capability before starting a session. Keep camera availability, tracking state, location quality, and anchor confidence distinct. Handle unsupported features, service unavailability, permission changes, tracking degradation, and lifecycle interruptions. Keep low-level rendering and platform mechanics inside package boundaries. Follow the [AR viewer performance budgets](../../docs/AR_VIEWER_PERFORMANCE_BUDGETS.md) and [device validation guide](../../docs/AR_DEVICE_VALIDATION_V1.md).

## 7. Backend integration

Backend services are independently owned modules under `Backend/`; see [backend architecture](../../Backend/docs/architecture.md). Use configured environment-specific base URLs, treat server authorization and visibility as authoritative, preserve request/correlation IDs where supported, and map API errors to user-safe typed client errors. Coordinate contract changes with the owning service and update both client and backend documentation. Never log tokens, signed media URLs, private content, exact private coordinates, or sensitive profile data.

## 8. Offline and lifecycle requirements

Persist capture intent and upload state before network operations where required. Use bounded retry/backoff and distinguish retryable from permanent failures. Make uploads idempotent where the server contract supports it. Reconcile server-confirmed state before showing queued content as published. Pause/release camera, sensor, and AR resources on lifecycle transitions and reacquire safely on resume. Never delete user content merely because sync failed.

## 9. Testing strategy

- Unit tests: domain rules, mapping, providers/controllers, repository behavior, and retry policies.
- Widget tests: visible states, interactions, semantics, and responsive behavior.
- Integration tests: critical session, capture, upload/retry, map discovery, AR fallback, and navigation journeys.
- Package tests: public contracts and platform adapter behavior using `ar_engine_testkit`.
- Physical-device checks: camera lifecycle, permissions, location accuracy, compass behavior, AR tracking, thermal load, and frame pacing.

## 10. Useful commands

Run app checks from `UI/jezaku/`:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Run package checks from the relevant `UI/Packages/<package>/` directory:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Only report commands that were actually run. Record unavailable hardware/device checks as outstanding rather than marking them complete.
