# Spatial Safety Integration Plan

> **Status:** Updated 2026-11-24 against the repository capability inventory and current Safety API/enforcement contracts. The Safety policy API, PostgreSQL persistence, authority authorization, immutable request-scoped snapshots, bounded batch evaluation, route-alternative evaluation, and shared fail-closed enforcer exist. Discovery candidate paths are integrated. Memory publish uses the existing single-coordinate check. Memory presentation/render and remaining feature call sites are not yet fully integrated. This plan does not claim that all spatial operations are protected.

## 1. Goal

Make spatial restrictions an enforceable backend invariant before Jezaku enables broader public spatial publishing, merchant advertising, route guidance, or third-party extensions.

The existing `Backend/safety` module remains the sole policy owner. Do not create another policy service, policy store, evaluator, or client-side authority boundary.

## 2. Current implementation baseline

The following foundations are present on the inspected main-branch baseline:

| Component | Current status |
|---|---|
| `SpatialRestriction` and `AuthorityPrincipal` | Implemented: circular, activity-scoped, time-bounded restrictions and server-managed authority grants |
| `AuthorityAuthorizationPolicy` | Implemented: verification, validity, permission and jurisdiction checks |
| `SpatialPolicyRepository` / JDBC adapter | Implemented: PostgreSQL persistence, optimistic versioning, audit and policy revision |
| `SpatialSafetyPolicy` | Implemented: precedence, time/activity evaluation and bounded spherical route-segment checks against circular restrictions |
| `SpatialSafetyService` / REST resource | Implemented: authority operations, evaluation, batch, route alternatives and policy change feed |
| `SpatialSafetyEnforcer` | Implemented: shared fail-closed application-level enforcement entry point |
| Discovery candidate paths | Integrated: nearby, search, trending and for-you use batch `DISCOVER` evaluation; blocking outcomes are omitted and CAUTION is retained with a caution outcome |
| Memory publishing | Integrated: existing single-coordinate `PUBLISH` evaluation path |
| Memory feed/minimap/nearby projections | Integrated: feed, nearby dots and minimap apply existing audience/on-site/moderation filters, then one ordered batch `DISCOVER` evaluation (maximum 500) |
| Memory detail / AR placement eligibility | Integrated for backend memory read surfaces: non-owner detail uses single-point `RENDER`; another user's profile feed uses batch `RENDER`; owner gallery is intentionally exempt |
| Navigation consumer | Safety route-alternative API exists; routing-provider orchestration and live navigation-session enforcement remain incomplete |
| Interaction and commerce | No general-purpose server-side interaction or merchant redemption call sites are established as fully protected |

Source-of-truth implementation contracts:
- [Spatial Safety API](../Backend/safety/API.md)
- [Spatial Safety Enforcement Contract](../Backend/safety/ENFORCEMENT.md)
- [Repository Capability Inventory](repository-capability-inventory.md)

Before changing a feature, inspect its current source, tests, OpenAPI output, configuration and scoped `AGENTS.md`. The inventory is a targeted baseline, not a substitute for subsystem-level review.

## 3. Policy vs enforcement

A policy endpoint or evaluator does not automatically protect a product operation. Each feature must call the shared enforcer or the authenticated Safety API before returning protected content or performing a side effect.

Required decisions:
- `ALLOWED`: proceed, subject to other product policies.
- `CAUTION`: proceed only with the required caution UX and any applicable confirmation.
- `RESTRICTED`, `PROHIBITED`, `EMERGENCY_LOCKDOWN`: suppress or reject the affected operation.
- Policy unavailable, missing, malformed, stale beyond its contract, or incomplete: fail closed for policy-dependent operations.

For candidate lists, evaluate a bounded set against one immutable request-scoped snapshot. Do not reintroduce per-item repository reads or mix decisions from different policy snapshots. Do not retain a request snapshot as a distributed cache.

## 4. Feature enforcement matrix

| Feature path | Operation | Activity | Coordinate source | Current status / next action |
|---|---|---|---|---|
| Memory creation | Persist a new geotagged memory/frame | `PUBLISH` | Validated canonical memory anchor | Existing single-coordinate integration; add/maintain denial-before-write tests |
| Memory anchor refinement | Move a published anchor | `PUBLISH` | Proposed validated new anchor | Audit exact mutation paths and ensure check occurs before anchor/history writes |
| Discovery nearby/search/trending/for-you | Return spatial candidates | `DISCOVER` | Candidate's canonical stored position | Integrated with batch evaluation; maintain failure and authorization tests |
| Memory feed/minimap/nearby dots | Return candidate memories for spatial presentation | `DISCOVER` | Each memory's stored anchor | Next priority: audit every projection and integrate batch evaluation without bypasses |
| Memory detail / AR placement eligibility | Authorize content for physical AR presentation | `RENDER` | Stored object anchor; viewer location remains a separate input | Not fully integrated; add explicit render-eligibility enforcement |
| Trail/route guidance | Start or continue route instructions | `NAVIGATE` | Validated route geometry/segments | Safety route API exists; consumer integration and live-session re-evaluation remain |
| Server-side spatial action | Execute a spatial interaction | `INTERACT` | Target object's canonical location | Integrate only at actual server-side action handlers |
| Promotion discovery/redemption | Select or redeem a location-based offer | `DISCOVER` / `REDEEM` | Merchant location plus separately validated user eligibility context | Future commerce scope; do not create placeholder services |

Do not classify all reads as `DISCOVER`. Returning a candidate and authorizing its actual AR rendering are distinct operations. Re-evaluate at stage boundaries because policy may change after publication or discovery.

A point check does not establish route safety. Route checks must evaluate route geometry against applicable restrictions. Current route evaluation supports bounded WGS84 polylines against circular restrictions only; it is not a routing engine and does not account for road topology, terrain, closures or all physical hazards.

## 5. Delivery sequence

### SAF-INT-00 — Policy foundation and API
- [x] Authority principal is resolved from authenticated request context; clients cannot self-assert authority identity or grants.
- [x] Persist restrictions, authority grants and audit history in the existing Safety repository.
- [x] Implement optimistic version checks and transactional policy revision updates.
- [x] Expose service-authenticated evaluation and policy-change endpoints.
- [x] Keep policy evaluation in the existing Safety module.

**Exit:** policy ownership and evaluation APIs are established. This does not prove all feature paths are protected.

### SAF-INT-01 — Request-scoped snapshot and batch evaluation
- [x] Immutable policy snapshot loaded once for a request.
- [x] Bounded batch point evaluation with stable input ordering and one evaluation timestamp.
- [x] Bounded route-alternative evaluation against one snapshot.
- [x] Fail-closed behavior for missing or failed policy evaluation.
- [x] Policy revision and short validity deadline exposed for consumers.

**Exit:** consumers can evaluate bounded candidate sets consistently without N+1 policy reads. Do not add distributed caching until invalidation and maximum staleness are explicitly designed.

### SAF-INT-02 — Discovery and memory presentation
- [x] Integrate batch `DISCOVER` evaluation into Discovery nearby, search, trending and for-you candidate paths.
- [ ] Audit memory feed, minimap, nearby and every derived memory projection for alternate/bypass paths.
- [ ] Integrate `DISCOVER` into all relevant memory spatial projections using bounded batches and one snapshot per request.
- [ ] Integrate `RENDER` for memory detail and AR placement eligibility before returning content intended for physical presentation.
- [ ] Preserve memory audience, blocks, moderation, owner access and on-site radius checks as independent requirements.
- [ ] Do not expose restriction geometry or authority records to ordinary clients.
- [ ] Add endpoint-level positive, negative, policy-outage and cross-surface regression tests.

**Exit:** no prohibited spatial memory can be returned through a covered discovery projection or authorized for AR presentation. All relevant read paths are inventoried and tested.

### SAF-INT-03 — Publish and anchor mutation hardening
- [x] Existing memory creation path uses the Safety `PUBLISH` evaluation.
- [ ] Verify the check occurs after domain validation but before all durable/external side effects.
- [ ] Audit anchor refinement and every operation that can move a published anchor.
- [ ] Ensure denied operations create no memory update, media association, anchor history, event or notification side effect.
- [ ] Preserve moderation, owner authorization, visibility and offline queue semantics.
- [ ] Decide explicitly whether restricted-area private drafts are allowed; until then, do not publish a spatial placement that fails policy.

**Exit:** every supported memory publish/move path has denial-before-side-effect integration tests.

### SAF-INT-04 — Navigation, interaction and commerce gates
- [x] Implement bounded spherical segment-to-circle evaluation in Safety.
- [x] Expose service-authenticated route-alternative evaluation.
- [x] Provide a bounded Jezaku-side HTTP adapter with ordered-result validation and fail-closed behavior.
- [ ] Audit route/target ownership in journeys and spatial-trails-places before selecting consumer call sites.
- [ ] Integrate the configured routing provider's validated route geometry and route-preview orchestration.
- [ ] Re-evaluate before guidance and on route change, meaningful deviation, expiry, app resume and policy invalidation.
- [ ] Integrate `INTERACT` only at real server-side action handlers.
- [ ] Add `DISCOVER` and `REDEEM` when merchant/campaign endpoints exist; do not create placeholder commerce services.
- [ ] Test policy changes between discovery, route start, interaction and redemption.

**Exit:** every implemented route/action/offer operation has a concrete enforcement point and integration test, or is explicitly marked unsupported.

### SAF-INT-05 — Authority and operational hardening
- [ ] Define trusted authority provisioning, identity proofing, approval, suspension and grant-revocation workflows.
- [ ] Review restriction read/history and evaluation endpoints for information disclosure, abuse and rate limits.
- [ ] Verify production authentication configuration and least-privilege service-token scopes.
- [ ] Add PostgreSQL-backed tests for migrations, concurrency, revocation, revision and audit atomicity.
- [ ] Add health/readiness signals for policy persistence; protected features must not serve when policy storage is unavailable.
- [ ] Define and measure emergency lockdown propagation objectives.
- [ ] Keep raw coordinates and sensitive legal-basis details out of ordinary logs.

**Exit:** authority and policy operations are production-configurable, audited, observable and abuse-resistant.

### SAF-INT-06 — Geometry, invalidation and offline evolution
- [x] Bounded route corridor/segment evaluation for circular restrictions.
- [x] Monotonic restriction-policy revision and durable polling change feed.
- [ ] Define ADR for WGS84, units, circle boundary behavior, route corridor semantics and future geometry representation.
- [ ] Add polygon/multipolygon support only after a concrete use case and data ownership decision.
- [ ] Integrate change-feed polling and live-session invalidation in navigation consumers.
- [ ] Define maximum policy staleness before introducing any distributed cache.
- [ ] Define offline behavior: stale or missing critical policy suppresses high-risk publishing/navigation; never treat missing policy as allowed.
- [ ] Sign/authenticate policy bundles if bounded offline policy distribution is later required.

**Exit:** geometry, invalidation and offline behavior are explicit and tested; no cache or offline path silently weakens policy.

## 6. Cross-cutting rules

1. Server-side enforcement is authoritative; client suppression is defense in depth.
2. Coordinate provenance matters. Use canonical object coordinates for publish/render and validated route geometry for navigation.
3. Check before side effects. Denied operations must not partially publish or mutate state.
4. Re-check at stage boundaries; publish-time approval does not authorize later rendering, navigation or redemption.
5. Use one request-scoped snapshot for bounded candidate sets; avoid N+1 policy reads.
6. No permissive fallback for database failure, stale critical policy or incomplete responses.
7. Preserve memory audience, block, moderation, on-site radius, guardian and existing safety behavior.
8. Return decisions and safe reason codes, not sensitive authority records or restriction geometry.
9. Do not introduce a second safety service or speculative microservices.
10. Distinguish unit-test evidence, feature integration evidence, PostgreSQL-backed evidence and operational/field validation.

## 7. Test strategy and release gates

### Unit tests
- Snapshot immutability, evaluation timestamp and revision behavior.
- Activity/time-window/outcome precedence and circle boundary behavior.
- Empty/oversized batches and malformed coordinate handling.
- Route geometry bounds, segment intersection and corridor behavior.
- Repository failure and missing/invalid result handling.

### Integration tests
- Discovery endpoints filter prohibited candidates and retain caution metadata.
- Memory feed/minimap/nearby/detail do not leak restricted objects.
- Memory create/anchor update fail before persistence/history/event side effects.
- Policy-store outage denies protected operations.
- Cross-tenant and private-memory access remain denied independently of spatial policy.
- Authority endpoints reject unauthenticated, unverified, expired, out-of-scope and under-permissioned callers.
- PostgreSQL migrations, optimistic concurrency, revocation and audit/revision atomicity work against PostgreSQL.

### Release acceptance
- Every implemented spatial operation maps to a concrete enforcement call site.
- Every call site has positive and negative integration coverage.
- No protected endpoint returns or acts on a prohibited/restricted/emergency result.
- Policy-store outage cannot silently allow a protected operation.
- Existing privacy, moderation, on-site radius and offline behavior has regression coverage.
- Navigation is not declared safe until route geometry and route-session lifecycle are integrated.
- No public third-party publishing, marketplace, spatial advertising or general route-guidance launch before its relevant enforcement gates pass.

## 8. Next implementation slice

The next focused slice is **SAF-INT-02: memory spatial projection and render-eligibility enforcement**, beginning with a source audit of memory feed, nearby, minimap, detail and AR placement paths. Implement each endpoint family with batch evaluation and explicit tests. Do not add a per-item database lookup or rely on client-only suppression.

After those focused contract tests and product decisions, complete SAF-INT-05 PostgreSQL/operational validation before enabling public extensibility.
