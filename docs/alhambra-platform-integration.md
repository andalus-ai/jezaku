# Alhambra Platform Integration

> **Status:** Accepted direction; initial Alhambra UI integration is committed. Clean-checkout dependency resolution and app validation are pending.

See [ADR-0004](decisions/ADR-0004-alhambra-platform-foundation.md) for the architecture decision.

## Current Alhambra capabilities and constraints

| Package | Potential Jezaku use | Adoption constraint |
|---|---|---|
| `alhambra_core` | Generic identifiers, result and resource primitives | Adopt only if shared contracts reduce duplication |
| `alhambra_ui` | Theme, responsive shell, widgets and UI composition | First integration candidate for Jezaku Admin |
| `alhambra_plugin_api` | Compiled plugin contribution contracts | Validate lifecycle and version compatibility |
| `alhambra_plugin_runtime` | Host-side plugin lifecycle and capability composition | Not a sandbox for arbitrary downloaded code |
| `alhambra_sdk` | Developer-facing extension SDK | Integrate only after Jezaku extension contracts exist |
| `alhambra_identity` | Generic identity, organization, membership and RBAC contracts | Optional; not a replacement for Quarkus authorization |
| `alhambra_identity_sqlite` | SQLite membership, role and audit adapters | Deliberate single-host deployments only; not automatically a clustered grant store |

Alhambra is a separate repository: [andalus-ai/alhambra](https://github.com/andalus-ai/alhambra).

## Ownership contract

### Alhambra owns

- Generic Flutter design system, responsive layouts, reusable widgets and application shell composition.
- Generic plugin manifests/contracts, compiled contribution lifecycle, capability negotiation and extension-host UI infrastructure.
- Optional generic identity and data abstractions that do not encode Jezaku-specific semantics.

### Jezaku owns

- Spatial objects, anchors, placement, coordinate/reference systems, scene lifecycle and visibility.
- AR/device integration, geospatial discovery and navigation.
- Safety policy, moderation, public authority and jurisdiction-specific restrictions.
- Merchant/store/tenant lifecycle, advertising, campaigns, offers, disclosures and redemption.
- Jezaku marketplace catalogue, publisher onboarding, package review, publication and suspension.
- Jezaku operator roles, scoped grants, approval workflows and domain-specific audit semantics.
- Backend authorization and resource-scope enforcement in Quarkus services.

### Non-negotiable boundaries

- UI visibility and Alhambra capability declarations are not authorization.
- Quarkus services remain authoritative for identity/session validation and privileged domain actions.
- Do not add a Dart runtime dependency to Quarkus modules.
- Do not move spatial/commerce/safety domain truth into Alhambra.
- Do not run arbitrary downloaded Dart/native code inside the Flutter host.
- Do not make Alhambra depend on Jezaku.

## Dependency and release policy

1. Prefer a published immutable release when available; otherwise pin an exact Git commit SHA.
2. Never depend on `main`, a moving branch, or an unverified floating tag.
3. Keep the selected Alhambra revision visible in the consuming pubspec and review dependency updates as code changes.
4. Verify that Alhambra's internal relative path dependencies resolve from the package's Git checkout in a clean environment.
5. Run `flutter pub get`, `flutter analyze`, and `flutter test` for the consumer app; run the target-platform builds required by release.
6. Record Flutter/Dart SDK constraints and platform-specific dependencies before adoption.
7. Adopt the smallest package set. Jezaku Admin should initially evaluate `alhambra_ui`; plugin runtime and identity are separate decisions.

## Staged integration

### Stage A — Architecture and compatibility

- [x] Inspect Alhambra UI, plugin API/runtime and identity package boundaries.
- [x] Identify plugin runtime isolation limitation.
- [x] Harden Alhambra identity authorization fail-closed behavior.
- [x] Add SQLite membership, role and audit adapters with package CI.
- [x] Record the exact Alhambra UI commit in the Jezaku Admin pubspec (`1f861193950419a5d43a4a442c18dd83252ae225`).
- [ ] Verify dependency resolution, analyzer, widget tests and supported target builds in CI from a clean consumer checkout.

### Stage B — Jezaku Admin UI

- [x] Add the pinned `alhambra_ui` Git dependency to Jezaku Admin.
- [x] Adopt Alhambra theme, card and badge components while retaining Jezaku's ten-destination responsive navigation.
- [x] Keep unavailable backend sections explicitly unavailable.
- [x] Add a dedicated `flutter-admin` validation job to repository CI.
- [ ] Confirm clean-checkout dependency resolution, analyzer, widget tests and supported target builds.

### Stage C — Extension architecture

- [x] Map Jezaku extension manifest and capability requirements to Alhambra plugin contracts in [Jezaku–Alhambra Extension Contract](jezaku-alhambra-extension-contract.md); add draft manifest schema v1.0.0.
- [ ] Define Jezaku-specific permissions, spatial scopes, safety policy and moderation gates in Jezaku.
- [ ] Choose the execution boundary for untrusted extensions; compiled in-process plugins are trusted host code only.
- [ ] Define package provenance, publisher trust, signature/revocation, compatibility and resource-budget controls.
- [ ] Test capability denial, revocation and host failure behavior.

## Security and operations

Alhambra's identity authorization and SQLite adapters are reusable building blocks, not a complete production identity deployment. Hosts must supply trusted authentication, database lifecycle, migrations, backup/restore, access control, retention, and monitoring. Multi-instance deployments need an appropriate shared persistence adapter and revocation consistency strategy.

Jezaku must continue to validate actor credentials in Quarkus, resolve target-resource scope from trusted records, enforce domain authorization on every request, and persist grants and audit through its own backend-owned persistence and transaction boundaries.

## Current integration snapshot

Jezaku Admin currently pins `alhambra_ui` to Alhambra commit `1f861193950419a5d43a4a442c18dd83252ae225`. It uses `AlhambraTheme`, `AlhambraCard`, and `AlhambraBadge`. The app retains its own navigation shell because Jezaku owns the ten-area admin information architecture; Alhambra's generic shell is not adopted blindly. The latest Jezaku CI run is queued, so dependency resolution and Flutter checks are not yet reported as passing.

## Exit criteria

Integration is complete only when the selected Alhambra revision resolves from a clean Jezaku checkout, Admin builds and tests pass, no backend authority has migrated into the Flutter client, and all extension security assumptions are documented and tested.
