# Flutter Application Structure

The product application is `UI/jezaku/`. Reusable Dart packages live separately in `UI/Packages/`; this is not a single Flutter package containing all application and library code.

## Current top-level shape

```text
UI/
├── AGENTS.md
├── docs/
│   ├── README.md
│   ├── architecture.md
│   ├── app-structure.md
│   ├── design-system-and-ux.md
│   └── package-catalog.md
├── jezaku/
│   ├── AGENTS.md
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── app/
│   │   ├── features/
│   │   └── main.dart
│   ├── test/
│   ├── integration_test/
│   ├── assets/
│   └── Flutter platform projects
└── Packages/
    ├── AGENTS.md
    ├── ar_engine/
    ├── ar_engine_testkit/
    ├── ar_model_cache/
    └── jezaku_ar/
```

## Application areas

- `lib/main.dart`: application entry point; keep startup work and global composition understandable.
- `lib/app/`: app-wide composition and cross-cutting concerns such as providers, navigation, theme, lifecycle, and error presentation. Follow the existing implementation rather than introducing duplicate app frameworks.
- `lib/features/`: product capabilities and their user-facing workflows. Keep feature internals cohesive and avoid reaching into another feature's private implementation.
- `test/`: unit and widget tests for app behavior.
- `integration_test/`: end-to-end journeys that require a running Flutter app or platform integration.
- `assets/`: checked-in app assets referenced by the Flutter manifest.
- Platform directories: native project configuration and platform-specific integration. Change only when required and document platform-specific setup.

## Feature organization guidance

Use the existing feature structure as the source of truth. Where a feature grows, separate presentation, application orchestration, domain rules, and data adapters without creating empty layers for their own sake. Keep widgets focused on rendering and user intent; keep network, persistence, permission, and long-running workflow logic outside build methods.

## Where code belongs

| Concern | Preferred owner |
| --- | --- |
| Product screens and navigation | `UI/jezaku` |
| App-level provider/theme/bootstrap composition | `UI/jezaku/lib/app` |
| Feature-specific workflow and UI state | `UI/jezaku/lib/features` |
| Generic AR session/runtime/scene contracts | `UI/Packages/ar_engine` |
| Deterministic AR platform fakes and harnesses | `UI/Packages/ar_engine_testkit` |
| 3D asset caching and preflight | `UI/Packages/ar_model_cache` |
| Jezaku geospatial memory AR integration | `UI/Packages/jezaku_ar` |
| Server authorization and visibility policy | Owning module under `Backend/` |

When uncertain, keep product orchestration in the app and move functionality into a package only when it is genuinely reusable or has a distinct lifecycle/platform boundary.
