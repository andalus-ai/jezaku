# Spatial Safety Integration Plan

> **Status:** Engineering plan based on the repository state inspected on 2026-11-23. The safety policy API, persistence adapter, evaluator, and shared enforcer already exist. This plan focuses on production hardening and wiring feature call sites. It does not claim that all spatial product operations are protected.

## 1. Goal

Make spatial restrictions an enforceable backend invariant before Jezaku enables public third-party spatial publishing, merchant advertising, route guidance, or an extension marketplace.

The existing `Backend/safety` module remains the policy owner. Do not create another service, policy store, evaluator, or client-side authority boundary.

## 2. Existing implementation to reuse

The following code already exists on `main`:

| Component | Current responsibility |
|---|---|
| `SpatialRestriction` | Circular, activity-scoped, time-bounded restriction model |
| `AuthorityPrincipal` | Server-managed authority status, validity, jurisdiction scopes and permissions |
| `AuthorityAuthorizationPolicy` | Deterministic permission, validity and jurisdiction checks |
| `SpatialPolicyRepository` | Persistence contract for authority, restrictions and audit |
| `JdbcSpatialPolicyRepository` | PostgreSQL persistence and transactional audit snapshots |
| `SpatialSafetyPolicy` | Pure evaluator with precedence and time/activity checks |
| `SpatialSafetyService` | Create/update/revoke/read/history/evaluate application operations |
| `SpatialSafetyResource` | REST API at `/safety/spatial` |
| `SpatialSafetyEnforcer` | Fail-closed enforcement primitive for feature services |

Existing tests cover the authorization policy, service logic, pure evaluator and enforcer. `Backend/safety/API.md` documents the public API shape; `Backend/safety/ENFORCEMENT.md` documents the required call order and activity mapping.

### Existing REST operations

- `POST /safety/spatial/restrictions`
- `PUT /safety/spatial/restrictions/{restrictionId}`
- `POST /safety/spatial/restrictions/{restrictionId}/revoke`
- `GET /safety/spatial/restrictions/{restrictionId}`
- `GET /safety/spatial/restrictions/{restrictionId}/history`
- `POST /safety/spatial/evaluate`

Authority identity is resolved from the authenticated request context and then looked up in the authority repository. Authority onboarding/grant provisioning remains out-of-band. The evaluator supports circular geofences and now includes an internal bounded route-segment intersection primitive for those circles. No route-evaluation HTTP endpoint or navigation consumer integration exists yet.

## 3. Important distinction: policy API vs enforcement

A working endpoint that evaluates a point does not automatically protect another service. Each product operation must call the shared enforcer before returning protected content or performing a side effect.

The enforcer currently loads active restrictions for each point evaluation. Avoid naively invoking it once per item in a large discovery response: that would cause repeated repository reads and could evaluate items against different snapshots. Before bulk discovery integration, add a bounded snapshot/batch evaluation API that loads one policy snapshot per request and evaluates all relevant item positions consistently.

The enforcer must remain fail-closed:
- `ALLOWED`: proceed.
- `CAUTION`: proceed only with the appropriate caution UX.
- `RESTRICTED`, `PROHIBITED`, `EMERGENCY_LOCKDOWN`: reject.
- Repository unavailable, missing result, or invalid critical policy state: deny; never silently treat it as allowed.

## 4. Feature enforcement matrix

| Feature path | Operation | Activity | Coordinate source | Integration priority |
|---|---|---|---|---|
| Memory creation | Persist a new geotagged memory/frame | `PUBLISH` | Validated memory anchor in request; enforce only after domain validation and before persistence | P0 |
| Memory anchor refinement | Move an existing published anchor | `PUBLISH` | Proposed updated anchor | P0 |
| Discovery nearby/search/trending/for-you | Return spatially discoverable catalog entries | `DISCOVER` | Each candidate object's canonical position | P0 |
| Memory feed/minimap/nearby dots | Return candidate memories for spatial presentation | `DISCOVER` | Each memory's stored anchor | P0 |
| Memory detail / AR placement eligibility | Return object to render at a physical position | `RENDER` | Stored memory anchor; viewer location is separate and must not be confused with object location | P0 |
| Trail/route guidance | Return or continue route instructions | `NAVIGATE` | Route geometry/segments, not only a start or destination point | P1, after route contract audit |
| In-world action | Execute a spatial interaction | `INTERACT` | Target object's canonical location | P1, when such server actions exist |
| Promotion discovery/redemption | Select or redeem a location-based offer | `DISCOVER` / `REDEEM` | Merchant/store location plus separately validated user eligibility context | Future commerce scope |

**Do not classify all reads as `DISCOVER`.** A spatial query that returns candidate content is discovery; a request that authorizes actual AR placement/rendering is render eligibility. Both may need separate checks because policy can change between requests.

**Do not claim route safety from a point check.** A route must be checked along its geometry or bounded segments against all applicable restrictions. Current circle-only point evaluation is insufficient for a route crossing a restricted area.

## 5. Delivery sequence

### SAF-INT-00 — Correct the integration baseline

- [x] Confirm the existing REST resource and application service.
- [x] Confirm repository-backed evaluation and audit persistence.
- [x] Confirm the shared enforcer and fail-closed behavior.
- [ ] Keep the repository capability inventory synchronized with the actual main-branch code.
- [ ] Document which APIs are intentionally public and which require authenticated service/user context.

**Exit:** current-state docs no longer describe the REST API as missing; remaining work is clearly labeled as feature enforcement and operational hardening.

### SAF-INT-01 — Enforcer snapshot and bulk evaluation

- [ ] Introduce an immutable policy snapshot abstraction loaded once per request.
- [ ] Add batch evaluation for a bounded list of points and one concrete activity.
- [ ] Ensure each result is derived from the same snapshot timestamp/version.
- [ ] Bound candidate count and reject oversized batches.
- [ ] Preserve fail-closed behavior if snapshot loading fails.
- [ ] Unit-test duplicate points, empty input, invalid coordinates, mixed outcomes, and deterministic ordering.
- [ ] Do not add caching yet; one-request snapshot consistency is not a distributed cache.

**Exit:** callers can evaluate a bounded candidate set without N+1 database reads or inconsistent policy snapshots.

### SAF-INT-02 — Discovery and memory presentation enforcement

- [ ] Integrate batch `DISCOVER` evaluation in `DiscoveryService` for nearby, search, trending and for-you results.
- [ ] Integrate `DISCOVER` in memory feed/minimap/nearby projections.
- [ ] Integrate `RENDER` for memory detail/placement eligibility before returning content intended for AR placement.
- [ ] Keep memory audience, blocks, moderation and on-site radius checks authoritative and independent.
- [ ] Do not leak restriction geometry or identifiers to ordinary discovery clients; filter blocked candidates or return safe reason codes only where product UX requires them.
- [ ] Test every route and projection with a matching restriction and with policy storage unavailable.
- [ ] Verify no fallback query or secondary feed bypasses the check.

**Exit:** a prohibited spatial item cannot be returned through any covered discovery or render-eligibility endpoint.

### SAF-INT-03 — Publish and anchor mutation enforcement

- [ ] Inject the enforcer into `MemoryService`.
- [ ] Enforce `PUBLISH` for new memory creation using the validated anchor before repository writes.
- [ ] Enforce `PUBLISH` for anchor refinement using the proposed new anchor before updating persistence/history.
- [ ] Preserve media moderation, owner authorization, visibility and offline queue semantics.
- [ ] Define whether an owner may keep a private draft in a restricted area; default to no public/published spatial placement until an explicit policy decision exists.
- [ ] Add tests proving denied operations produce no memory write and no anchor-history event.

**Exit:** no new or moved published memory anchor can bypass an applicable publish restriction.

### SAF-INT-04 — Navigation, interaction and commerce gates

- [ ] Audit route/target endpoints in `spatial-trails-places`, journeys and any direction/Qibla feature before choosing call sites.
- [x] Add an internal bounded spherical segment-to-circle evaluator in Safety; a point-only call is insufficient.
- [ ] Expose a service-authenticated route-evaluation API and integrate it with a real routing-provider geometry contract before marking navigation safe.
- [ ] Integrate `INTERACT` at actual server-side spatial action handlers, not generic client tap events.
- [ ] Add `DISCOVER` and `REDEEM` only when merchant/campaign endpoints exist; do not create placeholder commerce services solely for the safety plan.
- [ ] Test restriction changes between discovery, route start, interaction and redemption.

**Exit:** every implemented route/action/offer operation has a documented enforcement point and integration test, or is explicitly marked not yet supported.

### SAF-INT-05 — Authority and operational hardening

- [ ] Define trusted authority provisioning workflow, identity proofing and approval; do not expose self-service grant creation.
- [ ] Review public restriction read and evaluation endpoints for information disclosure, abuse, rate limits and response minimization.
- [ ] Confirm production authentication configuration and service-token scopes for authority operations.
- [ ] Add PostgreSQL-backed tests for migrations, optimistic concurrency, revocation and audit atomicity.
- [ ] Add operational health/readiness signal for policy persistence; policy-dependent features must not serve protected content when policy storage is unavailable.
- [ ] Define emergency lockdown propagation objective and measure it.
- [ ] Keep raw coordinates out of ordinary logs and audit snapshots unless a documented, access-controlled need exists.

**Exit:** authority and policy operations are production-configurable, audited, observable and abuse-resistant.

### SAF-INT-06 — Geometry and offline policy evolution

- [ ] Record ADR for WGS84, units, circle boundary behavior and future geometry representation.
- [ ] Add polygon/multipolygon support only when a concrete use case and PostGIS ownership are agreed.
- [ ] Add route corridor/segment evaluation for navigation.
- [ ] Design policy versioning, invalidation and maximum staleness before adding distributed cache.
- [ ] Define offline behavior: cached restrictions may be used only within a bounded validity period; missing/stale policy suppresses high-risk publish/navigation and must not be interpreted as safe.
- [ ] Sign/authenticate policy bundles if they are distributed to offline clients.

**Exit:** geometry and offline behavior are explicit, tested and cannot silently weaken policy.

## 6. Cross-cutting engineering rules

1. **Server-side is authoritative.** Client overlays and local suppression are defense in depth only.
2. **Coordinate provenance matters.** Use stored object coordinates for publish/render. A client-provided viewer coordinate is not proof of an object's location or user presence.
3. **Check before side effects.** A denied publish must not write the object, media association, audit/history side effect or event.
4. **Re-check at stage boundaries.** Publish-time approval does not guarantee later render, navigation or redemption remains allowed.
5. **Avoid N+1 policy reads.** Batch candidate evaluation against one request snapshot.
6. **No permissive fallback.** Database failure, stale critical policy or unknown activity must not yield an implicit allow.
7. **Preserve existing controls.** Memory audience, blocked users, moderation, on-site radius and guardian safety zones remain separate checks.
8. **Minimize disclosure.** Consumers need the decision, not the full authority record or sensitive policy geometry.
9. **No speculative microservices.** The existing Safety module owns policy evaluation and persistence.
10. **Evidence-based readiness.** Unit tests prove the component; integration tests prove the feature path; production metrics and operational exercises prove propagation.

## 7. Test strategy and release gates

### Unit tests
- Snapshot loading and immutable evaluation.
- Activity, time window, geometry boundary and outcome precedence.
- Empty/oversized batch and malformed coordinate handling.
- Repository failure and null/invalid result handling.

### Integration tests
- Discovery endpoint filters prohibited candidates.
- Memory feed/minimap/detail do not leak restricted objects.
- Memory create/anchor update fail before persistence/history writes.
- Policy storage outage returns denial for all protected operations.
- Authority endpoints reject unauthenticated, unverified, expired, out-of-scope and under-permissioned callers.
- Concurrent update/revoke requests honor expected version and preserve audit consistency.
- PostgreSQL migrations and repository semantics work against a real PostgreSQL test database.

### Release acceptance
- Enforcement matrix maps every implemented spatial operation to a concrete call site.
- Every call site has at least one positive and one negative integration test.
- No protected endpoint returns content when the applicable decision is prohibited/restricted/emergency.
- A policy-store outage cannot silently allow a protected operation.
- Existing privacy, moderation, on-site and offline behavior has regression coverage.
- Route safety is not declared complete until geometry is evaluated, not just endpoints.
- No marketplace, public third-party publishing, spatial advertising or route-guidance launch before the relevant enforcement gates pass.

## 8. First implementation slice

Start with **SAF-INT-01: request-scoped immutable policy snapshot and bounded batch evaluation**. This is a prerequisite for integrating discovery and memory projections without N+1 database access. Then implement SAF-INT-02 and SAF-INT-03 in separate focused changes with integration tests.

Do not start by wiring a per-item database lookup into every list endpoint. That would be functionally simple but operationally expensive and could produce inconsistent decisions within one response.
