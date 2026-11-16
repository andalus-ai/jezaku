# Reusable Dart Package Instructions

These instructions apply to packages under `UI/Packages/`. Also follow [UI/AGENTS.md](../AGENTS.md) and the repository-level [AGENTS.md](../../AGENTS.md).

## Package design

- A package must have a clear, reusable responsibility and a documented public API.
- Keep `ar_engine` platform-neutral at its public contract boundary. Platform-specific implementations belong behind explicit interfaces and capability checks.
- Keep Jezaku product concepts and geospatial memory workflows in `jezaku_ar`, not in the generic AR engine.
- Keep test-only fakes and harnesses in `ar_engine_testkit`; do not make production packages depend on testkit.
- Keep asset staging, validation, freshness, and retention concerns in `ar_model_cache`; rendering remains the responsibility of the engine/consumer.
- Avoid circular dependencies and dependencies from lower-level packages toward app code.
- Prefer small typed contracts, explicit capability reporting, deterministic lifecycle behavior, and documented fallback behavior.

## Required changes

1. Inspect `pubspec.yaml`, exported library files, implementation, tests, and README before editing.
2. Treat exported symbols as public API. Document behavior, errors, platform support, lifecycle, and compatibility implications.
3. Keep platform support claims tied to implemented and tested adapters; distinguish native capability from deterministic fallback.
4. Add deterministic tests for success, unsupported capability, failure, disposal, and concurrency/race paths as appropriate.
5. Update the package README and [package catalog](../docs/package-catalog.md) when responsibilities, dependencies, exports, or platform support change.
6. Avoid adding app-specific dependencies or backend/network policy to generic engine contracts.

## Validation

Run from the changed package directory:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Then run relevant consuming-app tests from `UI/jezaku/`. Report hardware/platform checks that could not be performed.
