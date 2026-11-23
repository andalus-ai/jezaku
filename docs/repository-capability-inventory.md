# Jezaku Repository Capability Inventory

> **Baseline:** 2026-11-23. This is a source-backed inventory of the repository state inspected for the Spatial Platform Foundation work. It is not a claim that every file, test, endpoint, or device path has been exhaustively audited. Status labels distinguish implemented code from integration and validation gaps.

## 1. Executive assessment

Jezaku already has substantial AR, geospatial-memory, discovery, and safety building blocks. The correct next step is **consolidation and integration**, not creating a parallel Spatial Core, a second AR engine, or a new collection of microservices.

The repository currently has three complementary layers:

1. **Reusable device/runtime foundation:** `UI/Packages/ar_engine` provides a Flutter plugin and provider-facing AR contracts. `UI/Packages/jezaku_ar` contains Jezaku-specific geo-anchor, projection, capture, model placement, and memory-scene helpers.
2. **Current product experience:** `UI/jezaku` owns the app, AR viewer, memory/frame workflows, visibility policy, and UI composition. The memory/frame model remains product-specific.
3. **Backend capabilities:** the Quarkus modules own memories/media, spatial trails and places, discovery, presence, and safety. Existing contracts should be extended in their owning modules.

The most mature current spatial domain is geotagged memories/frames. Generic Spatial Object/Scene/Extension/Commerce contracts remain target architecture, not implemented platform-wide features.

## 2. Evidence and confidence

The inventory was prepared by inspecting the following representative source and guidance files on `main`:

- `AGENTS.md`, `UI/AGENTS.md`, `Backend/AGENTS.md`, and `docs/AGENTS.md`.
- `Backend/pom.xml` and module POMs for `memory`, `safety`, and `spatial-trails-places`.
- `Backend/docs/service-catalog.md`.
- `Backend/memory/README.md`, `MemoryResource.java`, `MemoryService.java`, and `MemoryAccessPolicy.java`.
- `Backend/spatial-trails-places/.../TrailResource.java` and `Backend/discovery/.../DiscoveryResource.java`.
- `Backend/safety/.../SpatialSafetyPolicy.java`, `SpatialPolicyRepository.java`, `JdbcSpatialPolicyRepository.java`, authority model code, and safety migrations.
- `UI/jezaku/pubspec.yaml`, `UI/Packages/ar_engine/pubspec.yaml`, `UI/Packages/ar_engine/lib/ar_engine.dart`, and `UI/Packages/jezaku_ar` exports and implementation.
- `UI/jezaku/lib/features/ar_viewer/visibility/` policy and rules, plus `UI/docs/frame-visibility-and-roadmap.md`.

This is a targeted architecture inventory. Before implementation in a specific subsystem, follow its scoped `AGENTS.md` and inspect the complete relevant source, tests, OpenAPI output, configuration, and migrations.

### Status vocabulary

- **Implemented:** concrete source/contracts exist for the stated behavior.
- **Partial:** a meaningful foundation exists, but integration, enforcement, or lifecycle is incomplete.
- **Planned:** target documentation describes the capability, but this inspection did not find an implementation.
- **Unknown / validate:** insufficient source or field evidence to make a reliable claim.

## 3. Current repository boundaries

### Flutter UI

- Product app: `UI/jezaku/`.
- Reusable AR packages: `UI/Packages/ar_engine`, `ar_engine_testkit`, `ar_model_cache`, and `jezaku_ar`.
- UI state guidance specifies Riverpod and keeps app workflows in the app, reusable AR behavior in packages.
- App dependencies include geolocation, compass, motion sensors, camera, image/EXIF, Dio, local preferences, and permissions.
- The UI agent guidance requires deterministic camera/AR lifecycle, offline-first preservation, and a single central frame visibility policy.

### Quarkus backend

The Maven aggregator `Backend/pom.xml` currently lists `common`, `identity`, `profile`, `social`, `engagement`, `discovery`, `journeys`, `messaging`, `rewards`, `memory`, `camera`, `media`, `presence`, `safety`, `spatial-trails-places`, `events`, and `notifications`.

The service catalog assigns the spatially relevant ownership as follows:

| Module | Current ownership relevant to the platform |
|---|---|
| `common` | Shared technical infrastructure and geospatial primitives |
| `memory` | Camera memories, anchor metadata, nearby memory feed, minimap dots, access and on-site visibility |
| `spatial-trails-places` | Trail completion/history/saved trails and place/anchor domain ownership (confirm detailed endpoint coverage before extending) |
| `discovery` | Nearby discovery, spatial search, trending and recommendation feedback |
| `presence` | Live location, altitude/compass context and nearby-user dots |
| `camera` | Camera HUD context, sessions, safety zones and minimap overlays |
| `media` | Upload slots, media inventory and moderation state |
| `safety` | Reports, moderation review, guardian safety zones, plus the new spatial restriction/authority foundation |

Do not interpret this catalog as a reason to add another service. Extend the owning module unless a concrete ownership or deployment requirement proves otherwise.

## 4. Capability matrix

| Capability | Status | Current evidence / boundary | Main gap |
|---|---|---|---|
| Cross-platform AR runtime abstraction | **Implemented / validate per provider** | `ar_engine` exports sessions, capabilities, anchors, nodes, scene manager, hit tests, planes, math, animation, image tracking, cloud/geospatial anchors, diagnostics and platform interface. Plugin targets Android, iOS, Web, macOS and Windows. | Registered targets do not imply equivalent tracking/features. Linux is not registered; Windows/macOS paths include synthetic/demo behavior. Verify capability and physical device matrix. |
| Jezaku-specific AR adapter | **Implemented** | `jezaku_ar` exports capability planning, capture, geo anchors/projector, cloud-anchor persistence, model placement/cache, photo frames and memory scene helpers. | Keep it memory/experience-specific until a reusable domain contract is justified; avoid moving product policy into the neutral engine. |
| Spatial Object domain model | **Planned / partial primitives** | AR runtime has `ARNode` and scene primitives; Jezaku has `JejakuGeoAnchor` and `JejakuPlacedMemory`. | No inspected platform-wide, server-backed Spatial Object contract covering owner/tenant, type registry, lifecycle, permissions, safety classification and versioning. |
| Spatial Scene composition | **Partial** | `ARSceneManager` and `JejakuMemorySceneSyncResult` support runtime scene composition/synchronization. | No generic persistent scene API/domain contract for multi-domain experiences. |
| Placement and coordinate primitives | **Implemented / partial** | Geo anchor carries lat/lon/altitude, heading/pitch/roll, ENU corrections and metadata. Engine exposes pose/vector/quaternion/matrix and geospatial contracts. | Canonical coordinate-frame/unit policy, uncertainty semantics, cross-provider persistence and interoperability need a formal shared contract. |
| Memory capture and anchor refinement | **Implemented** | `POST /memories`, `PATCH /memories/{id}/anchor`, anchor history, quality/readiness/revision/source fields, media linking and moderation snapshots. | Validate API contract and AR refinement loop end-to-end; generic spatial content must not be forced into the memory model. |
| Spatial discovery | **Implemented / partial** | `GET /discovery/nearby`, `/search`, `/trending`, `/users/{id}/for-you`; memory service also exposes nearby/feed/minimap. | Align eligibility and ranking with generic object lifecycle, device capability, policy and tenant filters; inspect all query paths for consistent enforcement. |
| Memory audience/privacy | **Implemented with integration/config caveats** | Backend `MemoryAccessPolicy` supports owner, public, friends and blocked relationship decisions. Social relationship context is integrated for friends visibility. | Auth/friends enforcement flags and service credentials must be production-configured; test failure/anonymous modes and every derived surface. |
| On-site frame visibility | **Implemented with known trust limitation** | Backend on-site rule defaults to 20 m when enabled; client central policy uses 20 m plus 5 m exit hysteresis in strict mode. Unknown client distance fails closed. | Client-reported coordinates can be spoofed. App identity/social providers and physical-device validation are called out as incomplete in UI docs. Do not weaken existing rules. |
| Offline capture and local frame experience | **Partial / existing product capability** | UI package/app and guidance preserve local capture and queued/offline behavior; device demo workflows exist. | Inventory the exact queue, retry, conflict, persistence and replay semantics before generalizing offline support to all Spatial Objects. |
| Spatial trails | **Implemented for current trail domain** | `spatial-trails-places` exposes completion, history, saved/unsaved trail endpoints. | Inspect place and anchor APIs and align trail guidance with generic NavigationTarget/Route contracts; validate safety against route geometry. |
| Navigation and Qibla | **Planned / partial primitives** | Geospatial coordinates, bearing helpers, compass/sensor dependencies and trail guidance provide primitives. | No evidence in this inventory of a complete route graph, safe route validation, generic target/instruction API or Qibla experience contract. Straight-line bearing is not a navigable route. |
| Spatial safety evaluator | **Implemented foundation** | `SpatialSafetyPolicy` evaluates circular restrictions, activity scope, active window and precedence: emergency lockdown, prohibited, restricted, caution, allowed. | Current evaluator handles supplied circular rules; polygon geometry, richer hazard geometry and all enforcement call sites remain gaps. |
| Authority identity and authorization | **Implemented foundation** | `AuthorityPrincipal` and authorization checks cover verified status, validity, jurisdiction scopes and permissions. | Authority onboarding, identity proofing/feed ingestion and operational workflows need integration and threat review. |
| Spatial policy persistence and audit | **Implemented foundation** | `SpatialPolicyRepository`, JDBC adapter and PostgreSQL/Flyway migrations persist authorities, scopes, permissions, restrictions and audit snapshots. PRs #121, #122 and #123 are merged. | The merged persistence slice explicitly does not yet wire spatial-policy REST endpoints or enforcement call sites to the repository. Verify migration in PostgreSQL-backed CI/integration tests. |
| Safety enforcement across publish/discovery/render/navigation/redeem | **Partial / planned integration** | Policy activity enum includes publish, discover, render, navigate, redeem and interact. | Evaluator and persistence do not prove every operation is gated. Build an enforcement matrix and fail-safe behavior before public publishing or commerce. |
| Generic asset pipeline | **Partial primitives** | Media service owns upload and moderation; AR packages validate/render model assets and cache models. | No inspected end-to-end reusable asset catalog with licenses, variants, provenance, spatial constraints and marketplace lifecycle. |
| Extension SDK/marketplace | **Planned** | Target architecture and extension guidance exist in `docs/extension-architecture.md`. | No inspected extension manifest registry, package signing/validation/publishing, permission broker, sandbox or revocation pipeline. |
| Merchant/tenant spatial ads | **Planned** | Target docs describe optional commerce and consent-aware proximity ads. | No inspected merchant campaign, eligibility, frequency cap, verified offer, countdown authority or redemption API. |
| Public information / education / tourism experiences | **Planned as generic platform experiences** | Current domain modules and target vision can host future experiences. | Need generic object/scene contracts and an example experience before general-purpose publishing. |
| Smart-glasses / XR support | **Planned / provider-dependent** | Runtime abstractions are multi-platform; current app is Flutter smartphone-first. | No verified glasses device adapter or field-validation evidence. |

## 5. Important integration findings

### 5.1 The AR engine is already the reusable runtime boundary

Do not create another AR engine package or put Jezaku's memory, merchant, advertising, or authority rules inside `ar_engine`.

Recommended ownership:

- `ar_engine`: provider-neutral session, capability, tracking, rendering primitives and platform adapters.
- `jezaku_ar`: reusable Jezaku AR integration helpers only where they are not tied to a single screen.
- `UI/jezaku`: product workflows, memory/frame UI, policy composition and experience-specific interaction.
- Backend domain modules: authoritative identity, access, content, lifecycle and safety decisions.

### 5.2 The current frame model is not yet the generic Spatial Object model

A memory frame is one important kind of spatial content, but its owner, visibility, media moderation, on-site radius, and gallery behavior are product-specific. Map it to future generic contracts through an adapter or migration path. Do not replace it wholesale or relax its privacy behavior.

### 5.3 Safety has progressed beyond the earlier target docs

Spatial safety is not merely a proposed idea anymore: evaluator, authority authorization and persistence/audit slices have landed. However, **persistence is not enforcement**. The next safety work is API/authentication integration, repository-backed evaluation, geometry expansion, cache/version propagation and explicit call-site enforcement.

The safety service must remain the policy authority. UI-side suppression is defense in depth, not the security boundary.

### 5.4 Existing backend services overlap logically but not necessarily in ownership

Memory, discovery, spatial trails/places, presence and camera all use spatial information for different product purposes. Before adding generic endpoints, document which service owns each entity and which service only projects/consumes it. Avoid a second copy of memory ownership, social access policy or location state.

## 6. Spatial Core gap analysis

| Target concept | Current implementation to reuse | Required next decision |
|---|---|---|
| Spatial Object identity/type | Memory IDs, media IDs, AR node metadata | Define a typed platform contract and adapter for Memory; avoid generic untyped JSON as core semantics. |
| Owner / tenant / publisher | Memory owner ID; social identity; service authority principal | Define separate ownership, publisher authority, tenant scope and viewer authorization. |
| Object lifecycle | Memory/media moderation and deletion states | Define generic lifecycle and map existing memory/media states without losing moderation semantics. |
| Spatial Scene | AR scene manager and Jezaku memory scene | Define whether persistent server-side scenes are needed for first use case; do not build them speculatively. |
| Placement | Geo anchors, AR pose and local/session placement | ADR for coordinate frames, units, orientation, accuracy/confidence and persistence. |
| Discovery | Memory nearby/minimap and Discovery service | Define a shared eligibility contract while preserving owning-service access decisions. |
| Interaction | AR hit testing, gestures, app navigation | Define typed interaction/event envelope; no generic arbitrary extension execution initially. |
| Device capabilities | AR engine capability query/config resolution | Define stable capability vocabulary and provider conformance tests. |
| Safety | Circular evaluator, authority model, JDBC persistence | Integrate repository-backed decisions into each relevant server operation before public extensibility. |
| Extension | Existing package boundaries and asset validation primitives | Begin with declarative assets/templates; postpone arbitrary executable plugins. |

## 7. API and persistence assessment

### Existing APIs that should be preserved and mapped

- Memory: create/read/delete, anchor update/history, nearby, minimap, feed, per-user memory listing, media snapshot sync.
- Discovery: nearby, search, trending, for-you and feedback.
- Spatial trails: completion, history, save/list/unsave.
- Safety: current guardian/moderation endpoints plus the new internal spatial-policy domain/repository foundation.

The memory resource is explicitly `/memories`; trail resources are under `/trails`; discovery under `/discovery`. The target `/spatial/objects` family in architecture docs is illustrative, not an existing contract.

### Persistence

- Memory, media and other service persistence must remain owned by their modules.
- Spatial safety now has PostgreSQL/Flyway persistence for authority and restriction data.
- This inventory did not establish a platform-wide spatial object/scene schema or a PostGIS geometry implementation for generic polygons/corridors.
- Do not introduce a global spatial-object table until ownership, query needs, retention and migration of existing memory/trail/place records are agreed.

## 8. Risks and constraints

1. **Privacy regression:** genericizing frames could accidentally allow remote browsing or bypass owner/friends/block/moderation rules.
2. **False confidence in safety:** a stored restriction or unit-tested evaluator does not mean all APIs and clients enforce it.
3. **Provider parity assumptions:** plugin target registration is not proof of equivalent geospatial tracking, depth, anchors or occlusion on every platform.
4. **Coordinate ambiguity:** heading conventions, altitude datum, ENU corrections, local/world transforms and uncertainty must be explicit before generic serialization.
5. **Offline policy staleness:** queued content may be created offline while authority restrictions change; define expiry and fail-safe behavior before offline publishing/discovery.
6. **Trust boundaries:** client-reported position is spoofable; client visibility is defense in depth.
7. **Premature platform scope:** marketplace, merchant campaigns, smart glasses and generic scene services should not delay consolidation of the current frame and safety foundations.
8. **Operational validation:** merged migrations and repository code need CI and PostgreSQL-backed validation; physical AR needs real-device validation.

## 9. Recommended implementation sequence

This sequence updates the proposed implementation plan based on the actual repository state.

### M0 — Capability inventory and contracts (this document)

- [x] Inspect repository instructions and current module boundaries.
- [x] Inspect AR runtime and Jezaku-specific AR package exports.
- [x] Inspect memory APIs, access policy and on-site behavior.
- [x] Inspect discovery/trail APIs and safety evaluator/repository foundations.
- [x] Map current capabilities to target Spatial Core.
- [ ] Complete a full test/OpenAPI/configuration and offline-queue audit before changing code.
- [ ] Review and accept the inventory.

### M1 — Spatial safety integration (highest priority before public extensibility)

- [ ] Add/confirm authenticated authority-facing API boundary and server-resolved principal; never accept authority identity from request body.
- [ ] Connect REST operations to `SpatialPolicyRepository` and repository-backed evaluation.
- [ ] Define and implement enforcement call sites for publish, discover, render eligibility, navigate, redeem and interact.
- [ ] Define geometry support roadmap (circle now; polygon/corridor/vertical bounds as needed) and explicit CRS/units.
- [ ] Add policy version, cache invalidation/expiry and offline stale-policy behavior.
- [ ] Add PostgreSQL-backed repository tests, REST authorization tests and enforcement matrix tests.
- [ ] Keep existing guardian safety-zone/report behavior intact.

### M2 — Spatial vocabulary and compatibility contracts

- [ ] ADR for coordinate frames, units, heading, altitude and uncertainty.
- [ ] Define typed Spatial Object and Placement DTOs with owner/tenant/publisher separation.
- [ ] Map Memory to a Spatial Object adapter without changing existing memory endpoints or access rules.
- [ ] Decide whether persistent Spatial Scene is needed for the first non-memory use case.
- [ ] Define lifecycle and version semantics; map media moderation and memory deletion explicitly.
- [ ] Publish OpenAPI schemas and contract tests before adding new consumers.

### M3 — Device capability and runtime conformance

- [ ] Document provider capability matrix from actual code and physical-device evidence.
- [ ] Add provider conformance tests for session lifecycle, anchors, hit tests, pose, tracking quality and unsupported-feature fallback.
- [ ] Keep neutral runtime contracts in `ar_engine`; product-specific placement in `jezaku_ar`.
- [ ] Verify Android/iOS capture, placement, pause/resume, permission denial, loss/recovery and cleanup on devices.
- [ ] Record Web/Desktop simulation limitations separately from native AR claims.

### M4 — Discovery and navigation integration

- [ ] Define server-side eligibility contract joining access, moderation, lifecycle, device compatibility and safety.
- [ ] Preserve current memory feed/nearby/minimap and discovery API compatibility.
- [ ] Define NavigationTarget/Instruction independent of arrow UI.
- [ ] Implement route/path safety checks before route rendering; do not equate a straight-line bearing with a safe route.
- [ ] Define Qibla as a bearing/orientation experience, separate from route navigation.

### M5 — Declarative assets and extension foundation

- [ ] Define versioned declarative object/template package format and license/provenance.
- [ ] Add asset validation, size limits, optimized variants and content-type allowlists.
- [ ] Add explicit capability/permission registry and package signing/integrity.
- [ ] Add review, publish, suspend, revoke and rollback lifecycle.
- [ ] Prove undeclared capabilities are denied.
- [ ] Do not execute arbitrary third-party native code in the app process.

### M6 — Commerce and marketplace

- [ ] Add merchant/tenant identity and staff authorization.
- [ ] Add consent-aware spatial campaign discovery, sensitive-zone suppression and frequency caps.
- [ ] Add server-authoritative offer eligibility, quota, expiry and idempotent redemption.
- [ ] Add marketplace listings, licensing, creator publishing, review and revocation.
- [ ] Keep commerce optional and outside the core AR runtime.

## 10. Proposed first engineering tickets

| Ticket | Scope | Acceptance evidence |
|---|---|---|
| SAF-INT-01 | Safety API and authority principal integration | Authenticated principal is server-resolved; spoofed body identity is rejected; scoped authorization tests pass. |
| SAF-INT-02 | Repository-backed restriction evaluation | REST/API path reads persisted active policies; expiry, revocation and version behavior tested with PostgreSQL. |
| SAF-INT-03 | Enforcement call-site inventory and wiring | Matrix proves each operation (publish/discover/render/navigate/redeem/interact) is gated or explicitly out of scope. |
| SAF-INT-04 | Policy cache and client contract | Version/expiry/invalidation defined; stale critical policy fails safely; offline behavior tested. |
| CORE-ADR-01 | Coordinate and placement conventions | ADR accepted with coordinate frame, axis, units, altitude datum, heading, uncertainty and serialization rules. |
| CORE-MAP-01 | Memory-to-SpatialObject mapping | Compatibility adapter and contract tests; no regression to visibility, moderation, on-site radius or gallery. |
| AR-CONF-01 | Provider capability conformance | Automated testkit coverage plus documented Android/iOS physical-device evidence. |

## 11. Definition of done for the inventory milestone

M0 is complete when:

- Every target capability has a current owner or an explicit "not yet owned" status.
- Implemented, partial, planned and unknown states are evidence-backed.
- The first engineering slice is agreed and does not duplicate existing abstractions.
- Privacy, safety, API compatibility and device-validation gates are included in the work.
- No claim of full platform readiness is inferred from the presence of a package, module, migration or unit test alone.
