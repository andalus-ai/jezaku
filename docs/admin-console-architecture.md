# Jezaku Admin Console Architecture

> **Status:** Proposed architecture, grounded in the current repository inventory. This document does not claim that the described management APIs or screens are implemented.

## 1. Purpose

Jezaku Admin is the trusted operational interface for configuring, governing, and operating a Jezaku deployment. It is not a second implementation of product business logic and it is not a general-purpose database editor.

The existing Flutter application at `UI/jezaku_admin/` is the designated admin client. Its initial responsive navigation shell and honest, non-live overview placeholders are now present; authentication, service integrations, and management workflows remain unimplemented.

Primary goals:
- Give platform operators one coherent view of deployment health and operational state.
- Provide scoped administration for users, roles, content governance, spatial safety, commerce, extensions, and platform configuration as those capabilities become available.
- Preserve domain ownership in existing backend services.
- Make every privileged action authenticated, authorized, validated, and auditable.
- Keep administrative capabilities modular so a deployment can enable only the domains it operates.

Non-goals:
- Replacing the Jezaku end-user application.
- Bypassing service-level authorization or editing service databases directly.
- Making every operator a global super-admin.
- Exposing sensitive user location, camera media, private messages, or credentials by default.
- Promising operational controls before their backend contracts and safeguards exist.

## 2. Current repository baseline

Source-backed baseline at the time this document was written:
- `UI/jezaku_admin/` exists as a separate Flutter application.
- Its `lib/main.dart` now provides a responsive console shell, ten management-area destinations, and explicit not-connected/not-implemented states.
- Widget tests cover the overview, navigation, and compact drawer behavior; these tests have been authored but not executed in this environment.
- The README and app-scoped `AGENTS.md` now describe the admin purpose and engineering/security rules.
- Its dependency manifest includes Flutter and `material_ui`; do not introduce a second UI/state-management stack without review.
- The backend is a Maven multi-module Quarkus project.
- Existing service ownership is documented in `Backend/docs/service-catalog.md`: identity owns accounts/sessions; profile owns user profile/privacy; safety owns moderation and spatial restriction policy; commerce owns merchant/store/campaign/promotion/redemption truth; other services own their respective domains.
- No separate admin backend service is currently listed in the service catalog.

This baseline must be rechecked before implementation because code and service ownership may evolve.

## 3. Product and operator personas

| Persona | Scope | Typical responsibilities |
|---|---|---|
| Platform owner | Deployment-wide, tightly controlled | Bootstrap, operator assignment, global policy, emergency operations |
| Platform operator | Operational scopes | Health, incidents, jobs, configuration within grants |
| Trust & safety moderator | Moderation scopes | Reports, review, takedown, appeals and safety workflows |
| Spatial authority operator | Verified jurisdiction/property scope | Submit and manage authorized spatial restrictions |
| Commerce operator | Merchant/campaign scope | Verification, campaign review, offer operations |
| Extension reviewer | Marketplace review scope | Package provenance, permissions, compatibility and publication review |
| Support operator | Minimal support scope | Account lookup and support workflows with sensitive fields masked |
| Auditor | Read-only audit scope | Review privileged actions and evidence |

A person may hold multiple roles, but grants must be explicit, scoped, reviewable, and revocable. Tenant, jurisdiction, and resource ownership must be checked by the backend; client-supplied scope values are never proof of authorization.

## 4. Application and backend boundaries

```text
Flutter Admin Console (UI/jezaku_admin)
  - navigation, forms, dashboards, typed client models
  - capability-aware menus and permission-aware actions
  - no privileged business rules in widgets
                 |
                 | authenticated HTTPS / versioned contracts
                 v
Existing owning Quarkus services
  identity | profile | safety | commerce | media | spatial | ...
  - authenticate and authorize each request
  - enforce domain invariants and tenant/jurisdiction scope
  - persist domain truth and emit domain events
                 |
                 v
Service-owned persistence and infrastructure

Cross-cutting operational telemetry:
  health / metrics / logs / traces -> approved observability interfaces
  (read-only and redacted by default)
```

### Backend facade decision

Do not create a new admin microservice in the first implementation slice. The repository already has domain services and a clear ownership catalog. Admin operations should initially be exposed by the service that owns the domain.

A thin aggregation/BFF layer may be considered later if measured UI needs justify it. It must compose existing contracts and must not become a second source of domain truth. Record an ADR before introducing a new deployable service.

### Service ownership map

| Admin capability | Authoritative owner | Initial integration posture |
|---|---|---|
| Operator identity and account lifecycle | identity | Reuse identity contracts; privileged operator provisioning requires a dedicated safe workflow |
| User profile/privacy overview | profile | Minimize fields; mask sensitive values |
| Social/family context | social | Restricted support use only; no broad browsing |
| Reports, moderation, spatial restrictions | safety | Dedicated scoped moderation/authority operations |
| Merchant/store/campaign/promotion | commerce | Use commerce APIs; verified operator scope |
| Media review state | media | Use media-owned moderation contracts |
| Spatial anchors, trails, places | spatial-trails-places | Use domain APIs and safety checks |
| Discovery diagnostics | discovery | Aggregated/redacted diagnostics |
| Messaging | messaging | No private message content in routine admin views |
| Jobs/events/notifications | owning service | Operational metadata only; explicit retry/replay safeguards |

Do not infer a missing endpoint from a module name. Before connecting a screen, inspect the owning module's implementation, OpenAPI contract, tests, and authorization behavior.

## 5. Shared Flutter foundation: Alhambra

Alhambra is the preferred shared foundation for generic Flutter presentation and compiled extension-host composition, subject to clean-checkout dependency and target-platform validation. Jezaku Admin remains the product application: it owns its navigation semantics, operator workflows, API clients, and Jezaku-specific permissions. Alhambra UI components may provide the shell, responsive layout and reusable presentation primitives; they must not become an authorization authority.

Do not add Alhambra as a dependency until its exact revision, SDK constraints, nested path dependencies and supported targets have been validated from a clean Jezaku checkout. Pin an immutable Git commit or release. Do not add Alhambra Dart identity to Quarkus backend modules. The Quarkus identity and domain services remain authoritative for admin grants, tenant/jurisdiction scope and audit.

The Alhambra Flutter plugin runtime supports compiled host contributions; it is not a sandbox for arbitrary marketplace downloads. Jezaku marketplace extensions require a separately designed isolation boundary, publisher trust, permission review, resource limits and revocation enforcement. See [Alhambra platform integration](alhambra-platform-integration.md) and [ADR-0004](decisions/ADR-0004-alhambra-platform-foundation.md).

## Console information architecture

Top-level navigation is capability- and permission-aware. Hidden navigation is a usability aid, not a security boundary.

1. **Overview**
   - Deployment status, service health, recent incidents, pending queues, recent admin activity.
   - Clear distinction between unavailable telemetry and healthy status.
2. **People & Access**
   - Operator accounts, role grants, permission catalog, scoped assignments, sessions.
   - User support lookup with data minimization and masking.
3. **Trust & Safety**
   - Reports, moderation queue, review decisions, takedown, appeals/corrections.
   - Spatial restriction status, provenance, effective windows, jurisdiction and audit history.
4. **Spatial Operations**
   - Anchors/places/trails diagnostics and publishing status.
   - Safety-policy state takes precedence over discovery and rendering controls.
5. **Commerce**
   - Merchant verification, stores/branches, campaigns, promotions and redemption diagnostics.
   - Paid content and campaign status must be clearly identified.
6. **Extensions & Marketplace**
   - Publisher review, package provenance/signature, declared capabilities, permission review, compatibility, publication, suspension and revocation.
7. **Operations**
   - Service health, background jobs, event delivery, logs and incidents.
   - Read-only by default; retry/replay is a separately authorized action.
8. **Configuration**
   - Deployment-scoped settings, feature flags, configuration versions and rollback proposals.
   - Secrets are write-only references to a secret manager, never readable values.
9. **Audit**
   - Searchable immutable administrative activity, actor, scope, action, reason, outcome, request ID and timestamp.
10. **System**
   - Deployment metadata, integration status, backup/restore status and maintenance controls where safely supported.

Menus may be grouped differently at narrow widths, but capability names and permission semantics remain consistent.

## 6. Authorization and privileged actions

Use deny-by-default RBAC with resource scopes and explicit capabilities. Suggested permission identifiers are illustrative and must be aligned with the identity service's actual model before implementation:

- `admin.dashboard.read`
- `admin.operators.read`, `admin.operators.manage`
- `admin.roles.read`, `admin.roles.assign`
- `admin.moderation.read`, `admin.moderation.review`, `admin.moderation.takedown`
- `admin.safety.restrictions.read`, `admin.safety.restrictions.propose`, `admin.safety.restrictions.approve`, `admin.safety.emergency.activate`
- `admin.commerce.merchants.review`, `admin.commerce.campaigns.manage`
- `admin.extensions.review`, `admin.extensions.publish`, `admin.extensions.revoke`
- `admin.operations.read`, `admin.operations.jobs.retry`
- `admin.configuration.read`, `admin.configuration.propose`, `admin.configuration.approve`
- `admin.audit.read`

Requirements:
- Enforce permission checks in the owning backend service for every request, including list, export, batch, retry, and mutation paths.
- Scope grants by tenant, jurisdiction, deployment, or resource as applicable.
- Separate proposal from approval for high-impact actions; require dual control for emergency, global, or destructive actions where appropriate.
- Require a reason for privileged state changes.
- Use step-up authentication for sensitive operations where supported.
- Make destructive actions explicit, previewable, and confirmed.
- Never allow the UI to grant itself capabilities or trust a role name sent by the client.

## 7. Audit model

Every privileged action must emit a durable audit record. Minimum conceptual fields:
- event ID and schema version;
- actor subject and authenticated client;
- action and target resource type/ID;
- deployment, tenant, jurisdiction or scope;
- reason/justification;
- before/after version references or redacted diff;
- outcome and stable result code;
- request/correlation ID;
- server timestamp;
- approval chain for dual-control operations.

Do not store passwords, access tokens, secrets, raw private message content, camera media, or unnecessary precise location in audit records. Audit access is itself permission-controlled. Audit history must not be editable through the console.

## 8. API and client conventions

- Use the owning service's versioned REST/OpenAPI contracts.
- Use typed request/response models; avoid raw JSON maps crossing widget boundaries.
- Apply bounded pagination, sorting allowlists, filters, and explicit export limits.
- Carry request/correlation IDs where supported.
- Model loading, empty, forbidden, unavailable, stale, and partial-data states separately.
- Do not present missing metrics as zero or an unavailable service as healthy.
- Use optimistic concurrency/version checks for configuration and moderation changes.
- Use idempotency for retryable create/redeem/approval operations where appropriate.
- Never place service credentials or admin tokens in source, local fixtures, logs, analytics, or screenshots.

## 9. Safety, privacy and governance

- Spatial restrictions and emergency policy are authoritative in the safety service and cannot be overridden by ranking, advertising, extension preference, or UI controls.
- Authority actions require authenticated principals, verified jurisdiction/property scope, provenance, effective/expiry times, audit, and revocation.
- Uncertain critical safety state fails safely; do not provide a console control that silently weakens enforcement.
- Admin access to precise location, private media, family/guardian data, and private conversations is exceptional, purpose-bound, minimized, and audited.
- Support access should prefer pseudonymous identifiers and masked fields.
- Proximity advertising requires consent, frequency caps, paid-placement disclosure, sensitive-location suppression, and server-authoritative eligibility.
- Extension review must check provenance, signature/integrity, declared permissions, compatibility, resource budgets, moderation, and revocation.
- Admin console must not encourage unsafe field validation or physical-world interference.

## 10. Shared platform foundation: Alhambra

Alhambra is the preferred reusable foundation for shared Flutter UI composition and, after separate validation, generic plugin contracts/runtime. Jezaku and Alhambra remain separate repositories. Jezaku owns product workflows, domain policy and backend enforcement.

Integration rules:
- Consume only the Alhambra packages needed by the admin client; do not add the complete plugin runtime merely because it exists.
- Pin dependencies to an immutable Git revision or released package version and validate resolution from a clean checkout.
- Keep Quarkus services authoritative for operator grants, scopes, approvals, domain decisions and durable audit. Alhambra UI/runtime capability state is not authorization.
- Do not treat the Flutter plugin runtime as a sandbox for arbitrary marketplace-delivered Dart/native code. Third-party executable extensions require a separately approved isolation design.
- Treat Alhambra identity authorization as unavailable for production enforcement until fail-closed behavior, trusted-principal boundaries, durable persistence and audit guarantees are reviewed and tested.

See [ADR-0004: Alhambra as the shared platform foundation](decisions/ADR-0004-alhambra-platform-foundation.md) and the [Alhambra host integration contract](https://github.com/andalus-ai/alhambra/blob/main/Docs/JEZAKU_HOST_INTEGRATION_CONTRACT.md).

## 11. Frontend structure (target)

Keep the existing Flutter app as the single admin client. Proposed feature organization, to be adapted to actual code and manifest:

```text
UI/jezaku_admin/
  lib/
    app/                 # bootstrap, router, theme, shell
    core/
      auth/              # session and permission context
      api/               # configured HTTP client, error mapping
      navigation/        # capability-aware navigation
      widgets/           # shared admin components
    features/
      overview/
      access/
      trust_safety/
      spatial/
      commerce/
      extensions/
      operations/
      configuration/
      audit/
      system/
    main.dart
  test/
```

This is a target organization, not a claim that these directories currently exist. Reuse dependencies and patterns only after checking the admin app manifest and the main app's actual conventions. Prefer responsive desktop/tablet layouts for operator workflows while preserving usable narrow-screen layouts. Do not add a state-management or routing package until the first implementation slice demonstrates the need.

## 12. Operational and reliability requirements

- Separate liveness, readiness, dependency health, and degraded state.
- Show last successful refresh and data freshness.
- Use bounded polling/backoff; avoid aggressive dashboard refresh.
- Redact sensitive fields in logs and diagnostic exports.
- Keep operational endpoints read-only unless an explicit mutation contract exists.
- Job retry/replay requires idempotency or a documented duplicate-side-effect strategy.
- Maintenance mode, backup/restore, and service restart are not generic UI toggles; each requires deployment-specific contracts and safeguards.

## 13. Testing and release gates

Frontend:
- permission-aware navigation and disabled/hidden actions;
- loading/empty/error/forbidden/stale/partial states;
- responsive layout, accessibility semantics and keyboard navigation;
- confirmation and reason capture for privileged actions;
- no sensitive values in diagnostics or test output.

Backend:
- unauthenticated and unauthorized denial;
- cross-tenant and cross-jurisdiction isolation;
- approval and dual-control requirements;
- audit emitted on success and failure where required;
- idempotency, concurrency and replay behavior;
- redaction and least-privilege response fields;
- emergency restriction precedence and fail-safe behavior.

Release gates:
- No admin screen may claim a capability is live until its backend contract and authorization are implemented.
- No privileged action ships without server-side authorization, validation, audit, and tests.
- No operational write control ships without idempotency/rollback or explicit risk treatment.
- Validate with seeded non-production data and test operators; never use real user private data in fixtures.

## 14. Related documents

- [Admin implementation plan](admin-console-implementation-plan.md)
- [Backend service catalog](../Backend/docs/service-catalog.md)
- [Backend architecture](../Backend/docs/architecture.md)
- [Security and safety](security-and-safety.md)
- [API standards](api-standards.md)
