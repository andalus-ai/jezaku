# Jezaku Spatial Platform Implementation Plan

> Proposed engineering work; reconcile each task with current source, tests, APIs, migrations, and scoped AGENTS.md before implementation.

## Delivery rules
Inspect before implementing. Reuse existing module ownership. Keep changes small and backward-compatible. Every slice includes documentation, tests, security/privacy review, and acceptance evidence. Never claim unrun tests or device validation. Preserve frame visibility, sharing, moderation, radius, and offline-first behavior.

## Workstream 0 — Repository capability inventory
- [ ] Inventory Flutter app features and state/data flows.
- [ ] Inventory reusable AR packages and provider boundaries.
- [ ] Inventory Quarkus services, shared modules, APIs, and persistence.
- [ ] Inventory geospatial placement/discovery implementation.
- [ ] Inventory frame visibility/radius rules and tests.
- [ ] Inventory offline storage, queued work, and synchronization.
- [ ] Map current modules to target logical capabilities.
- [ ] Record gaps, duplicate abstractions, risks, and unknowns.

**Acceptance:** source-backed matrix marks each capability implemented, partial, planned, or unknown.

## Workstream 1 — Core domain contract
- [ ] Spatial Object schema/type registry.
- [ ] Owner, tenant, publisher, viewer, and access-policy references.
- [ ] Lifecycle state machine and privileged transitions.
- [ ] Spatial Scene and composition.
- [ ] Placement strategies and anchor references.
- [ ] Coordinate frames, units, axes, transforms, uncertainty.
- [ ] Interaction schemas and accessibility alternatives.
- [ ] Versioned event envelope and naming.
- [ ] Safety classification and policy integration.
- [ ] Schema evolution and serialization compatibility.

**Acceptance:** schemas/transitions documented and validated; current frame behavior explicitly mapped.

## Workstream 2 — Runtime contract
- [ ] Device capability model.
- [ ] Spatial session lifecycle.
- [ ] Provider-neutral tracking/anchor interfaces.
- [ ] Renderer boundary and supported content.
- [ ] Tracking quality, confidence, and stale-state behavior.
- [ ] Pause/resume, permission revocation, resource cleanup.
- [ ] Provider test doubles/testkit.
- [ ] Map contracts to existing AR package ownership.

**Acceptance:** test provider exercises contracts without AR hardware; device validation plan exists.

## Workstream 3 — Discovery and navigation
- [ ] Bounded spatial query.
- [ ] Server-side access/visibility filtering.
- [ ] Safety ordering and suppression reasons.
- [ ] Eligibility separated from ranking.
- [ ] Navigation target, route, waypoint, instruction models.
- [ ] Bearing/heading conventions.
- [ ] Accuracy thresholds and fallbacks.
- [ ] Qibla calculation/calibration separate from road routing.

**Acceptance:** tests cover denial, safety suppression, stale location, unsupported device, and non-AR fallback.

## Workstream 4 — Extensions and assets
- [ ] Manifest schema and semantic version rules.
- [ ] Capability/permission namespaces.
- [ ] Signing and integrity verification.
- [ ] Declarative-first and sandbox boundary.
- [ ] Resource limits and host API allowlists.
- [ ] Asset formats, validation, optimization, licensing.
- [ ] Publishing pipeline.
- [ ] Install/upgrade/disable/revoke/rollback behavior.

**Acceptance:** sample declarative extension validates and undeclared capability is denied.

## Workstream 5 — Commerce
- [ ] Merchant/organization/store/staff roles.
- [ ] Merchant spatial presence.
- [ ] Campaign, targeting, consent, frequency cap.
- [ ] Offer eligibility, quotas, expiry, redemption.
- [ ] Server-authoritative arrival/redemption.
- [ ] Paid-placement disclosure and sensitive-location suppression.
- [ ] Privacy-aware analytics and retention.
- [ ] Billing integration boundary outside Core.

**Acceptance:** test campaign enforces consent, eligibility, expiry, quota, and one-time redemption.

## Workstream 6 — Experience validation
- [ ] Map current frame experience onto generic contracts without weakening policy.
- [ ] Define Qibla as bearing/orientation experience.
- [ ] Define generic navigation target/arrow experience.
- [ ] Define spatial information panel experience.
- [ ] Validate at least two object types through one runtime.
- [ ] Record device matrix, accuracy, tracking limits, and offline behavior.

**Acceptance:** multiple experiences reuse the same object/placement/runtime contracts and pass regression tests.

## Milestones
| ID | Deliverable | Gate |
|---|---|---|
| M0 | Repository capability inventory | Existing behavior/ownership understood |
| M1 | Core domain contracts | Object/scene/placement/access reviewed |
| M2 | Runtime/provider contracts | Device/provider boundaries testable |
| M3 | Discovery/navigation contracts | Access, safety, fallback specified |
| M4 | Extension/asset contracts | Permission/sandbox reviewed |
| M5 | Commerce contracts | Consent/redemption integrity specified |
| M6 | Reference experiences | Shared contracts validated on devices |

## Definition of done
1. Scoped design and owner.
2. Code and migration if needed.
3. Unit and integration tests.
4. Authorization/privacy negative tests.
5. API/event/schema docs.
6. Operational metrics and failure handling.
7. Changelog and compatibility notes.
8. Actual test commands and outcomes.
9. Physical-device validation notes for camera/sensor/tracking/localization changes.

## Risks
| Risk | Mitigation |
|---|---|
| Duplicate frame/AR systems | Inventory and map ownership first |
| Premature microservices | Logical modules before deployables |
| Coordinate confusion | Typed frames and conversion tests |
| GPS/compass drift | Confidence and safe fallback |
| Private content leakage | Server authorization and regression tests |
| Unsafe route/ad presentation | Safety-first policy |
| Untrusted extensions | Declarative-first, sandbox, least privilege |
| Device fragmentation | Capability negotiation/provider adapters |
| Offline conflicts | Explicit sync/version/idempotency |
| Marketplace abuse | Verification, moderation, revocation |
