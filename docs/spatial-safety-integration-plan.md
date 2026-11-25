# Spatial Safety Integration Plan

> **Status:** Updated 2026-11-24 against the repository source and tests. Safety policy APIs, PostgreSQL schema/adapter, authority authorization, request-scoped snapshots, batch and route evaluation, and the shared fail-closed enforcer exist. Discovery and core Memory read/publish paths are integrated. PostgreSQL-backed repository verification and remaining navigation/interaction/commerce call sites are still open. This plan does not claim that all spatial operations are protected.

## 1. Goal

Make spatial restrictions an enforceable backend invariant before Jezaku enables broader public spatial publishing, merchant advertising, route guidance, or third-party extensions.

The existing `Backend/safety` module remains the sole policy owner. Do not create another policy service, policy store, evaluator, or client-side authority boundary.

## 2. Current implementation baseline

The following foundations are present on the inspected main-branch baseline:

| Component | Current status |
|---|---|
| `SpatialRestriction` and `AuthorityPrincipal` | Implemented: circular, activity-scoped, time-bounded restrictions and server-managed authority grants |
| `AuthorityAuthorizationPolicy` | Implemented: verification, validity, permission and jurisdiction checks |
| `SpatialPolicyRepository` / JDBC adapter | Implemented: PostgreSQL persistence, version-guarded writes, audit, monotonic revision and durable change outbox; real-PostgreSQL integration coverage not yet found |
| `SpatialSafetyPolicy` | Implemented: precedence, time/activity evaluation and bounded spherical route-segment checks against circular restrictions |
| `SpatialSafetyService` / REST resource | Implemented: authority operations, evaluation, batch, route alternatives and policy change feed |
| `SpatialSafetyEnforcer` | Implemented: shared fail-closed application-level enforcement entry point |
| Discovery candidate paths | Integrated: nearby, search, trending and for-you use batch `DISCOVER` evaluation; blocking outcomes are omitted and CAUTION is retained with a caution outcome |
| Memory publishing | Integrated: existing single-coordinate `PUBLISH` evaluation path before media resolution and persistence |
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
| Memory creation | Persist a new geotagged memory/frame | `PUBLISH` | Validated canonical memory anchor | Integrated before media resolution/persistence; maintain denial-before-write tests |
| Memory anchor refinement | Move a published anchor | `PUBLISH` | Proposed validated new anchor | Integrated before record/history writes; add remote Safety HTTP contract coverage |
| Discovery nearby/search/trending/for-you | Return spatial candidates | `DISCOVER` | Candidate's canonical stored position | Integrated with batch evaluation; maintain failure and authorization tests |
| Memory feed/minimap/nearby dots | Return candidate memories for spatial presentation | `DISCOVER` | Each memory's stored anchor | Integrated with bounded ordered batch evaluation; add outage contract tests and pagination above 500 |
| Memory detail / AR placement eligibility | Authorize content for physical AR presentation | `RENDER` | Stored object anchor; viewer location remains a separate input | Backend detail and profile-feed render gates integrated; verify UI placement call site and remote contract tests |
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
- [x] Audit Memory feed, nearby, minimap, user-profile feed and detail read paths.
- [x] Integrate ordered, bounded batch `DISCOVER` evaluation into feed, nearby dots and minimap (maximum 500 candidates).
- [x] Integrate single-point `RENDER` for non-owner detail and batch `RENDER` for another user's profile feed; owner gallery remains intentionally exempt.
- [x] Preserve audience, blocks, moderation, owner access and on-site radius checks as independent requirements.
- [x] Keep restriction geometry and authority records out of ordinary memory responses.
- [x] Add service-level tests for filtering, caution retention, render suppression, owner behavior and listing projections.
- [ ] Add production-like HTTP contract tests for batch endpoint outages and oversized candidate behavior.
- [ ] Define bounded pagination/query limits for candidate sets above 500; current behavior fails closed rather than truncating or partially evaluating.

**Exit:** core Discovery and Memory read surfaces are integrated. HTTP contract coverage and candidate pagination remain release follow-ups.

### SAF-INT-03 — Publish and anchor mutation hardening
- [x] Existing memory creation path uses the Safety `PUBLISH` evaluation.
- [x] Verify create checks the requested anchor after validation and before media resolution, persistence or anchor-history writes.
- [x] Verify anchor refinement checks the destination before saving the updated record and history event.
- [x] Add regression tests proving denied creation leaves no frame and denied relocation preserves the original anchor and history.
- [x] Preserve owner authorization and existing media/visibility behavior.
- [ ] Add production-like HTTP contract tests proving Safety 403 and 503 prevent create/relocation.
- [ ] Decide explicitly whether restricted-area private drafts are allowed; until then, do not publish a spatial placement that fails policy.

**Exit:** domain-level denial-before-side-effect behavior is implemented and tested; remote HTTP contract coverage and the private-draft product decision remain open.

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
- [x] Define and implement relational storage for authority principals, jurisdiction scopes, permissions, restrictions, restriction activities and audit snapshots.
- [x] Add Flyway migrations for authority/restriction storage, authority audit, global policy revision and durable policy-change outbox.
- [x] Implement optimistic restriction version checks and atomic restriction/activity/audit/revision/outbox writes in the JDBC adapter.
- [x] Implement one-statement policy snapshot reads that return the global revision and active restrictions from a consistent PostgreSQL statement snapshot.
- [x] Implement server-side authority checks for verified status, validity window, jurisdiction scope and permission.
- [x] Add a dedicated PostgreSQL Testcontainers resource and repository integration test without changing the datasource-free default `%test` profile.
- [x] Add a concurrent first-provisioning regression test asserting one `CREATED` and one `UPDATED` authority audit event, plus persisted authority visibility.
- [ ] Run the PostgreSQL integration test and expand coverage to concurrent restriction writes, rollback on audit/outbox failure, revocation, revision monotonicity and change-feed ordering.
- [ ] Review authority provisioning as a controlled administrative workflow, including identity proofing, dual approval where appropriate, suspension and revocation.
- [ ] Review public restriction reads/history and evaluation endpoints for information disclosure, abuse controls and rate limits.
- [ ] Verify production authentication configuration, least-privilege service-token scopes, database credentials/rotation and deployment migration procedure.
- [ ] Add readiness signals proving migrations and policy storage are available; protected features must not serve when policy storage is unavailable.
- [ ] Define and measure emergency-lockdown propagation objectives, including consumer lag and alerting.
- [ ] Keep raw coordinates and sensitive legal-basis details out of ordinary logs.

**Audit findings and test infrastructure:** the original module had no PostgreSQL-backed JDBC test and its default `%test` configuration disables datasource activation and Flyway startup. The module now includes Testcontainers JUnit/PostgreSQL dependencies, `PostgresSpatialPolicyTestResource`, and `JdbcSpatialPolicyRepositoryPostgresTest`. The dedicated resource starts PostgreSQL 16, enables the datasource, and runs the module's Flyway migrations; the ordinary datasource-free test profile remains unchanged. The first integration test coordinates two independent worker threads to provision the same authority and asserts exactly one `CREATED` and one `UPDATED` audit event plus persisted authority visibility. It deliberately does not assume an ordering between concurrent transactions' timestamps. This test and container startup have been added to the repository but have **not yet been executed**; Docker availability, dependency resolution and Quarkus test-resource configuration remain unverified. The adapter uses transactional methods and direct `DataSource` connections; atomicity must be demonstrated against the actual Quarkus/PostgreSQL transaction manager. `saveAuthority` now acquires a transaction-scoped PostgreSQL advisory lock keyed by principal ID before the existence check and upsert, serializing classification for the same authority while allowing unrelated authorities to proceed independently. The next verification must run this test with Docker, then add independent transaction tests for restriction version conflicts and audit/revision/outbox rollback.

**Exit:** authority and policy operations are production-configurable, audited, observable and abuse-resistant, with real PostgreSQL evidence for atomicity and concurrency.

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

The next focused slice is **SAF-INT-05B: execute and expand PostgreSQL repository verification**. The dedicated Testcontainers resource and first authority-provisioning concurrency test are now present, while the default fast test profile remains datasource-free. Run the focused test from `Backend/` (`./mvnw -pl safety -am -Dtest=JdbcSpatialPolicyRepositoryPostgresTest -Dsurefire.failIfNoSpecifiedTests=false test`) in an environment with Docker. A broader backend test run exposed a separate Commerce configuration issue: its base datasource URL defaulted to `localhost:5432` even while test Dev Services started PostgreSQL on a dynamic port. The Commerce JDBC URL and credentials have now been scoped to `dev` and `prod`, allowing `%test` to use Dev Services. Re-run the Commerce repository test and the focused Safety test independently, then resolve any test-resource or transaction-enlistment failures before adding more cases. Then add restriction optimistic-version conflict tests, audit/outbox failure rollback tests, revocation/revision monotonicity tests, and change-feed ordering/pagination tests. Finally add readiness/health behavior and operational deployment guidance.

Do not treat in-memory repository tests as evidence of JDBC transaction correctness. Keep the current Safety module as the sole policy owner.
