# Jezaku Admin Console Implementation Plan

> **Status:** Proposed phased plan. Tasks are not complete until implemented, tested, and reflected in source-backed status notes.

## 1. Delivery strategy

Build on the existing `UI/jezaku_admin/` Flutter app. The first responsive shell has been committed; continue by validating it locally, auditing backend contracts, and connecting one backend-owned capability at a time. Avoid a large all-at-once admin rewrite and avoid introducing an admin microservice before a concrete aggregation need exists.

Each slice must include:
- UI route/navigation and responsive behavior;
- typed API client/repository integration when a real endpoint exists;
- backend authorization and validation for any privileged operation;
- audit behavior for privileged changes;
- unit/widget/API tests;
- documentation and operational notes.

## 2. Phase 0 — Baseline and contracts

**Goal:** establish what exists and what can safely be managed.

Tasks:
1. Recheck `UI/jezaku_admin` source, manifest, test setup, target platforms and build configuration.
2. Inventory identity, safety, commerce, media, spatial, and operational endpoints from source and OpenAPI; mark each read/write capability as implemented, partial, or absent.
3. Inspect authentication/session flows and determine the supported admin authentication mechanism; do not assume an admin role claim exists.
4. Define permission identifiers, scope model, operator bootstrap, step-up authentication, approval requirements and audit event contract.
5. Decide deployment topology and allowed origins/base URLs without committing environment secrets.
6. [x] Inspect the Alhambra package boundaries and define the shared-foundation ownership/security decision in ADR-0004. [ ] Validate the exact UI dependency graph, SDK constraints and immutable revision from a clean Jezaku checkout before adding the dependency.
7. [x] Record ADR-0004 for Alhambra adoption. [ ] Record any cross-service admin facade ADR only if measured integration needs justify it.

Exit criteria:
- Capability matrix references actual source files, OpenAPI operations and tests.
- No UI control is mapped to an assumed endpoint.
- Authentication and authorization gaps are explicitly recorded.

## 3. Phase 1 — Console foundation

**Goal:** replace the Flutter counter starter with a secure, navigable, non-destructive admin shell.

Tasks:
1. [x] Replace the counter starter with app identity, title, theme, responsive navigation shell.
2. [ ] Add sign-in/session-expired/unauthorized states only after confirming the backend auth contract; use a clearly marked development placeholder only in local non-production mode if the auth contract is absent.
3. [x] Add capability-area navigation with explicit not-implemented states.
4. [x] Add overview placeholders that clearly say not connected/not available instead of displaying fake health data.
5. [ ] Add common table/list, filter, pagination, detail panel, empty/error/loading and confirmation patterns.
6. [ ] Add typed environment configuration; never hardcode production URLs or secrets.
7. [ ] Evaluate and integrate only the required Alhambra UI package(s), pinned to an immutable revision, after SDK/dependency compatibility validation.
8. [ ] Execute and extend tests for shell, responsive navigation, unavailable modules, and auth boundary states.

Exit criteria:
- Admin app builds on its declared target platforms (not yet verified).
- No fake health/usage numbers or live-looking controls.
- All initial areas are discoverable; backend permission-aware routing remains pending authentication integration.
- No privileged backend operation is possible from this phase.

## 4. Phase 2 — Operator identity and access

**Goal:** safely manage admin operators and their scoped grants.

Tasks:
1. Confirm identity service account/session model and add an explicit admin operator/grant contract if missing.
2. Model permission catalog, deployment/tenant/jurisdiction scope, grant lifecycle and revocation.
3. Implement operator list/detail, invite/provision, suspend/revoke, role assignment and session revocation only where supported.
4. Add approval/step-up requirements for privilege escalation.
5. Audit every grant, revocation and sensitive lookup.
6. Test cross-scope denial, self-escalation denial, last-owner protection and audit completeness.

Exit criteria:
- Backend is authoritative for every grant and scope.
- No client-side-only role checks.
- Bootstrap and recovery are documented and tested.

## 5. Phase 3 — Trust, safety and moderation

**Goal:** provide controlled workflows for content governance and spatial restrictions.

Tasks:
1. Inventory existing safety/report/moderation APIs and enforcement points.
2. Build report queue, detail/review, reason codes, decision history and appeal/correction views.
3. Build spatial restriction inspection with provenance, scope, geometry summary, effective/expiry window and policy version.
4. Add restriction proposal/approval and emergency activation only for verified authority roles and supported contracts.
5. Ensure restriction changes invalidate relevant caches and propagate to enforcement points.
6. Test precedence, unauthorized authority, stale policy, revocation, audit and emergency propagation.

Exit criteria:
- Safety policy remains authoritative and fail-safe.
- Every authority action is scoped and auditable.
- Console never offers a general "disable safety" switch.

## 6. Phase 4 — Commerce and spatial operations

**Goal:** manage domain-owned merchant and spatial resources without moving their truth into the console.

Tasks:
1. Inspect commerce and spatial service contracts and their maturity.
2. Add merchant verification and store/branch review using commerce-owned endpoints.
3. Add campaign/promotion review, eligibility diagnostics and redemption support only where the backend validates outcomes.
4. Add spatial object/anchor/place diagnostics and publishing state using owning APIs.
5. Show paid/promoted content disclosure and campaign lifecycle clearly.
6. Test tenant isolation, merchant verification, offer timing and server-authoritative redemption.

Exit criteria:
- Commerce truth remains in commerce.
- Discovery and UI never self-assert merchant verification or redemption success.
- Spatial changes respect safety restrictions and ownership.

## 7. Phase 5 — Extensions and marketplace governance

**Goal:** review extension and marketplace submissions safely.

Tasks:
1. Confirm extension manifest, package format, signature/provenance and compatibility contracts.
2. Add submission queue, publisher profile, declared capabilities/permissions, dependency and resource-budget review.
3. Add approval, rejection with reason, suspension and revocation workflows.
4. Integrate scanning/moderation status where implemented; do not imply a scan occurred if it did not.
5. Test malicious/invalid package metadata, permission escalation, revocation and compatibility.

Exit criteria:
- Untrusted extensions cannot execute arbitrary native code in the core process.
- Publication is separate from runtime permission grants.
- Revocation is enforceable and auditable.

## 8. Phase 6 — Operations, configuration and audit

**Goal:** give operators safe visibility and controlled operational workflows.

Tasks:
1. Aggregate health/readiness and dependency status from approved endpoints.
2. Add job/event queue views and delivery diagnostics.
3. Add retry/replay only for idempotent or explicitly compensated operations.
4. Add versioned configuration proposals, diff, approval, rollout status and rollback.
5. Add searchable audit history and protected export.
6. Add backup/restore and maintenance controls only after deployment-specific runbooks and APIs exist.

Exit criteria:
- Health is based on real telemetry and includes freshness.
- Missing telemetry is never displayed as healthy or zero.
- Mutations are authorized, reasoned, audited and recoverable.
- Secrets remain in secret-management infrastructure.

## 9. Cross-cutting work

### Alhambra platform integration
- Keep Alhambra and Jezaku repositories separate and maintain the consumer contract in both.
- Pin exact Alhambra revisions/releases; avoid moving branch dependencies.
- Use Alhambra for reusable presentation/composition where validated; do not treat its UI or plugin runtime as backend authorization or a sandbox for untrusted code.
- Keep Jezaku Quarkus services authoritative for operator grants, scopes, domain invariants and audit.
- Require a separate isolation architecture and release gate before marketplace-delivered executable extensions are enabled.

### Security
- Deny by default, server-side permission checks, scoped grants, step-up authentication and dual control for high-impact operations.
- Redact tokens, private location, private content and secrets.
- Rate-limit high-risk lookup/export and mutation operations.
- Protect against CSRF/session theft as applicable to the chosen auth and web deployment model.

### UX and accessibility
- Desktop-first operator workspace with responsive tablet/narrow layouts.
- Keyboard navigation, semantic labels, focus management and readable status text.
- Distinguish stale, degraded, forbidden, unavailable and empty states.
- Confirm destructive and public-impact actions with scope and consequence summaries.

### Quality
- Widget tests for each route and state.
- API contract tests for every connected operation.
- Authorization and tenant isolation tests.
- Seeded non-production fixtures only.
- Run Flutter analyze/tests and focused Maven module tests; record commands and outcomes.

## 10. Initial backlog ordering

| Priority | Work item | Depends on |
|---|---|---|
| P0 | Capability inventory and auth contract audit | None |
| P0 | Replace starter app with admin shell and route tests | UI baseline |
| P0 | Define operator permission/scope/audit contract | Identity and security review |
| P1 | Read-only overview with real health data | Approved health endpoints |
| P1 | Operator and role management | Identity admin contract |
| P1 | Moderation queue | Safety API inventory |
| P1 | Restriction inspection and authority workflow | Safety authority model |
| P2 | Merchant and campaign management | Commerce APIs |
| P2 | Spatial resource diagnostics | Spatial service APIs |
| P2 | Extension review | Extension package contract |
| P3 | Jobs, configuration rollout, backup/restore | Operational API/runbooks |

## 11. Definition of done

A capability is complete only when:
- its owning backend contract exists and is documented;
- backend authentication, authorization, scope validation and domain rules are enforced;
- sensitive access is minimized and audit behavior is verified;
- UI loading/empty/error/forbidden/stale states are implemented;
- tests cover success, denial, cross-scope access and failure;
- documentation describes the actual implementation, limitations and operational procedure;
- relevant Flutter and Maven checks have been run and outcomes reported.
