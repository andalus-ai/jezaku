# UI Reusable Package Catalog

This catalog describes the package boundaries currently represented in `UI/Packages/`. Each package's `pubspec.yaml`, exported library, source, and tests remain authoritative.

## Dependency direction

The intended layering is:

```text
UI/jezaku (product app)
    | uses
    +--> jezaku_ar (Jezaku-specific AR integration)
    |       | uses
    |       +--> ar_engine (generic AR runtime)
    |       +--> ar_model_cache (asset preparation)
    |
    +--> ar_engine_testkit (development/test dependency only)

ar_engine_testkit ---> test consumers; production packages must not depend on it
```

Keep the generic engine free of product-specific memory, social, account, or backend concepts. The application coordinates product workflows; packages expose reusable capabilities.

## Package responsibilities

### `ar_engine`

Generic multi-platform Flutter AR runtime and scene capabilities. Its public surface includes session/controller abstractions, platform implementations, scene/model/material primitives, spatial math, animation/physics helpers, and capability-aware operations.

**Contract expectations:** expose capabilities before optional operations; report unsupported features explicitly; keep lifecycle and platform resource cleanup deterministic; distinguish native implementation from fallback behavior; keep platform-specific details behind the public API.

### `ar_engine_testkit`

Deterministic test doubles and harnesses for consumers of `ar_engine`. It provides an in-memory platform implementation and helpers to install/restore it, inspect requests, gate asynchronous operations, and inject failures.

**Contract expectations:** tests must be repeatable without native AR hardware; restore global/platform state during teardown; provide explicit controls for races and error paths.

### `ar_model_cache`

Model asset preparation and cache management before assets are passed to renderers. It handles bundled assets, local files, network downloads through injectable fetchers, optional conditional revalidation/freshness policies, cache metadata, inspection, and retention/pruning.

**Contract expectations:** cache behavior must be explicit and inspectable; default offline cache-hit behavior must remain predictable; validation and network failures must be represented without silently corrupting source assets.

### `jezaku_ar`

Jezaku-specific geospatial AR integration built on the generic engine. It translates engine capabilities into product-level session decisions and supports memory anchors, local ENU projection fallback, cloud-anchor workflows, capture/recording helpers, and model-cache preflight.

**Contract expectations:** keep product-specific semantics here; preserve deterministic fallback paths for development and unsupported devices; expose confidence and downgrade information to the app instead of implying unsupported precision.

## Adding or changing a package

Before adding a package, explain why the responsibility cannot live cleanly in the app or an existing package. Define its public API, dependency direction, supported platforms, lifecycle, error model, and tests before implementation. Update this catalog, the package README, and the UI architecture document in the same change.
