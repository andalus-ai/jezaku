# Jezaku Flutter Feature Catalog

This catalog reflects the feature directories currently present under `UI/jezaku/lib/features/`. Directory names identify ownership boundaries; inspect each feature's implementation and tests before assuming a workflow is complete or assigning new behavior.

## Application shell

| Path | Responsibility boundary |
| --- | --- |
| `lib/app/navigation/` | Application route definitions and navigation policy |
| `lib/app/screens/` | App-level shell and screen composition |
| `lib/app/utils/` | Cross-feature app utilities; keep feature-specific helpers inside their feature |
| `lib/app/app_error_handling.dart` | App-wide error presentation and handling |

The app currently has a central route definition in `lib/app/navigation/app_routes.dart` and a main shell in `lib/app/screens/main_screen.dart`. Keep route registration centralized and avoid creating parallel navigation systems.

## Feature ownership

| Feature directory | Owns | Boundary guidance |
| --- | --- | --- |
| `ar_viewer/` | AR viewing session UI, viewer state, presentation, and viewer-specific services | Delegate generic runtime behavior to `Packages/ar_engine`; use `jezaku_ar` for product-specific AR integration. Which frames may be shown (audience, moderation, physical radius) is decided only by `ar_viewer/visibility/`; see [frame visibility](frame-visibility-and-roadmap.md). Which HUD panels are shown is `ar_viewer/hud/ar_hud_state.dart` (one switch per `ARHudPanel`, plus Hide UI); add a panel there and it appears in the HUD settings sheet. The chosen preset and panels are remembered between launches by `hud/ar_hud_store.dart`; Hide UI is deliberately not remembered |
| `calibration/` | Device/environment calibration flows and related state | Keep sensor math reusable only when it is not tied to a product journey |
| `camera/` | Camera preview, capture interaction, and camera-specific state/services | Own camera UX and orchestration; do not duplicate low-level AR engine camera/session internals |
| `docs/` | In-app documentation/help content | Keep user-facing help distinct from engineering docs under `UI/docs/` |
| `auth/` | Sign-in: gateway to the identity service, session state, sign-in screen and gate, account tile | Required only in strict builds that have an identity URL; demo bypasses it. Feeds `currentUserIdProvider`; see [sign-in](sign-in.md) |
| `api/` | Shared HTTP plumbing for authenticated service clients (`AuthInterceptor`) | Adds the bearer token and reports a rejected one; see [sign-in](sign-in.md) |
| `remote_frames/` | Frames from the memory service: `RemoteFrame` wire model, `MemoryApi` (nearby, a user's frames), provider | Read-only and not yet used by the UI; the service decides visibility, unknown visibility parses as private |
| `frame_styles/` | The frame gallery: built-in frame looks (stable ids), look/colour resolver to AR scene metadata, picker and sheets | Cosmetic only; never decides who may see a frame. Looks are referenced by id so marketplace looks can join later; see [frame styles](frame-styles.md) |
| `gallery/` | Browsing and managing captured media | Respect media ownership, privacy, and local/offline state |
| `home/` | Main landing/discovery experience | Coordinate entry points without absorbing other feature implementations |
| `moderation/` | Reporting, review, and moderation-facing UI | Server-side moderation and enforcement remain authoritative |
| `parent/` | Parent/guardian-facing experiences | Treat family relationships and child data as sensitive; enforce server authorization |
| `profile/` | User profile and account-facing presentation | Do not treat client-side profile fields as authorization claims |
| `publish/` | Publish/review flow and audience selection | Make visibility and audience explicit before submission |
| `settings/` | User preferences and app configuration UI | Keep secret-bearing configuration out of user-visible settings and logs |
| `social/` | Social interactions and related presentation | Respect block, relationship, audience, and moderation rules returned by backend |
| `sync/` | Offline synchronization, queue state, and sync-related UI/services | Preserve pending user content; make retry and conflict states visible |
| `trails/` | Trail-oriented geospatial experiences | Represent location freshness and uncertainty honestly |
| `virtual_wall/` | Virtual wall/anchored content experience | Keep product presentation here; delegate reusable AR primitives to packages |

## Feature structure

Several features currently use subdirectories such as `models/`, `presentation/`, `screens/`, `services/`, `states/`, and `widgets/`. Use only the layers that the feature needs:

- `models/`: typed feature data structures and serialization boundaries.
- `presentation/`: presentation coordination where a feature has a distinct presentation layer.
- `screens/`: route-level pages and screen composition.
- `services/`: I/O, platform integration, and feature-level orchestration that does not belong in widgets.
- `states/`: feature state and state-management types; follow existing Riverpod patterns.
- `widgets/`: feature-scoped reusable UI pieces.

Do not force every feature to have every directory. Avoid generic `utils/` dumping grounds and cross-feature imports of private implementation files. Promote a component or service to app-wide scope only when multiple features genuinely share the same contract.

## Adding a feature

Before creating a new feature:
1. Check whether an existing feature already owns the user journey.
2. Define the user-facing responsibility and explicit non-goals.
3. Decide which state, service, model, and UI pieces belong inside the feature.
4. Identify backend endpoints and package dependencies; do not reproduce server authorization in the client.
5. Define loading, empty, error, offline/stale, permission, and success states relevant to the journey.
6. Add unit/widget/integration tests at the appropriate boundary.
7. Update this catalog and architecture docs when a new durable feature boundary is introduced.
