# Jezaku Admin App Instructions

These instructions apply to the Flutter application in this directory. Also follow repository-root `AGENTS.md` and `UI/AGENTS.md`.

## Product role
- This app is the operator-facing Jezaku Admin Console, separate from the end-user Jezaku app.
- Use it for administrative workflows, operational visibility, and governance; do not embed product business rules or bypass backend service ownership.
- Consult `../../docs/admin-console-architecture.md` and `../../docs/admin-console-implementation-plan.md` before substantial changes.

## Architecture
- Shared UI foundation: use the pinned `alhambra_ui` package for generic theme and reusable presentation components where appropriate. Keep Jezaku-specific navigation, operator workflows, and domain semantics in this app. Update the pinned Git SHA only through a reviewed dependency change.
- Do not treat Alhambra UI permission gates or plugin capabilities as backend authorization. Do not add Alhambra Dart identity as a Quarkus backend dependency.
- Alhambra's compiled Flutter plugin runtime is not a sandbox for arbitrary downloaded marketplace code.
- Keep the Flutter app as the admin client; do not create a new backend service solely for UI aggregation.
- Existing Quarkus services remain authoritative for their domains. Identity owns accounts, Safety owns moderation/restriction policy, Commerce owns merchant/campaign truth, and other services retain their documented ownership.
- Inspect the current manifest and source before adding routing, state management, networking, or UI dependencies.
- Keep widgets declarative; move API calls and workflows into typed repositories/controllers.
- Model loading, empty, error, forbidden, stale, partial and unavailable states explicitly.
- Capability-aware navigation is not authorization. The backend must authorize every request.

## Security and privacy
- Deny by default. Never trust client role names, tenant IDs, jurisdiction IDs, or resource ownership as proof of permission.
- Never hardcode credentials, tokens, production URLs, signing keys or user identifiers.
- Do not expose precise private location, private camera media, private messages, guardian/family details or secrets in ordinary admin views or logs.
- Require explicit scope/reason/confirmation for privileged actions. High-impact actions need server-side approval/dual-control where defined.
- Every privileged mutation must be audited by the owning backend service.
- Never add a generic "disable safety" or unrestricted database-editing feature.

## UX
- Prioritize responsive desktop/tablet operator workflows while retaining usable narrow layouts.
- Support keyboard navigation, semantic labels, focus handling and clear status text.
- Distinguish unavailable telemetry from healthy/zero values.
- Destructive, public-impact and location-sensitive actions need clear consequence and scope confirmation.

## Testing
- Add widget tests for navigation, permission states, loading/empty/error states and privileged-action confirmation.
- Add unit tests for typed models, repositories and controllers.
- Run `dart format`, `flutter analyze`, and `flutter test` from this directory when tooling is available.
- Do not claim a build, test, or deployment succeeded unless actually run.
- Report platform, auth, API and infrastructure checks that remain outstanding.
