# Commerce Domain Architecture

> Status: proposed architecture. This document defines ownership and contracts; it does not claim that a merchant registry, offer inventory, campaign engine, or redemption API exists.

## 1. Purpose

Commerce is the authoritative domain for merchants, physical stores, commercial campaigns, promotions, eligibility, and redemption. It provides verified commercial facts to other Jezaku capabilities without allowing those capabilities to become the source of truth for commercial state.

The initial implementation should be a logical domain/module, not automatically a separately deployed microservice. Follow existing Quarkus module conventions and extract a deployable only when scale, security isolation, team ownership, or operational requirements justify it.

## 2. Ownership boundaries

| Capability | Owns | Must not own |
|---|---|---|
| Commerce | Merchant identity and verification, stores/branches, merchant staff roles, authoritative store placement, campaigns, promotions, quotas, eligibility, redemption | General nearby ranking, AR rendering, spatial restriction policy |
| Discovery | Candidate retrieval, ranking, pagination, filtering, read-model projection | Merchant verification, offer terms, inventory, redemption |
| Safety | Spatial restrictions, authority grants, policy evaluation and enforcement decisions | Merchant onboarding or campaign eligibility |
| Social | Existing graph/audience-based social campaigns and social interactions | Merchant/store registry or proximity redemption |
| Spatial Core / Runtime | Provider-neutral object, placement, presentation and device contracts | Commercial truth or entitlement decisions |

Commerce must call or consume the Safety domain; it must not reproduce restriction logic. Discovery must use Commerce-owned data through a bounded read model/API/event projection and must not query Commerce tables directly.

## 3. Core aggregates and records

### Merchant

Represents a legal or operating business account. Minimum concepts:
- Stable merchant ID and canonical display identity.
- Verification state: PENDING, VERIFIED, SUSPENDED, REJECTED.
- Verification evidence references and review/audit metadata; avoid copying sensitive documents into ordinary logs.
- Legal/business jurisdiction and supported operating regions.
- Account status, created/updated timestamps, optimistic version.

Only authorized server-side workflows may change verification state. A client-provided verified flag is never authoritative.

### Store / branch

A merchant may own multiple independently located stores. Minimum concepts:
- Store ID, merchant ID, public name and status.
- Address and authoritative placement reference.
- Time zone identifier (IANA), operating schedule and optional temporary closures.
- Contact/public display metadata.
- Provenance of coordinates: source, verifier, verification method, verified-by reference, verified-at, accuracy/quality, and revision.
- Lifecycle and audit history.

A store is not equivalent to a viewer's current location. A merchant may propose coordinates, but public proximity use requires server-side validation and an explicit placement verification state. Client GPS is not proof of store ownership or physical presence.

### Campaign and promotion

Keep campaign intent separate from the actual offer terms:
- Campaign: merchant, objective, lifecycle, budget/billing references where applicable, audience constraints, channel/placement, start/end, frequency policy and approval state.
- Promotion: human-readable terms, discount/benefit definition, eligibility rules, per-user and total quotas, redemption window, inventory/availability constraints, and legal disclosures.
- Campaign-store association: explicit set of eligible stores and their effective dates. Never infer store association from a campaign's camera/minimap label or the viewer's location.
- Creative references: validated asset IDs and metadata; do not store arbitrary executable content.

All time windows are evaluated server-side using explicit instants and the store/campaign time-zone policy. Client countdowns are presentation only.

### Redemption

A redemption is an immutable business event with controlled state transitions:
- Redemption ID, promotion/campaign/store references, merchant and customer references.
- Server-computed eligibility result and policy/version references.
- Idempotency key scoped to the authenticated actor and operation.
- Issued/redeemed/voided timestamps, status and reason codes.
- Verification method and audit references, with minimal location evidence.

Do not store raw continuous movement history as redemption evidence. Retain only the minimum evidence needed for fraud prevention, dispute resolution, and legal obligations.

## 4. Authoritative spatial placement

The store's placement is a Commerce-owned fact with explicit provenance and lifecycle. A placement record should include:
- Coordinate reference system and normalized latitude/longitude (WGS84 for the initial API contract).
- Optional entrance/approach point and service-area geometry in a later version.
- Horizontal accuracy/quality and verification status.
- Source, reviewer, verification timestamp, revision and audit trail.
- Effective status and suspension/revocation reason.

Do not assume a store's postal address geocodes to its entrance. Do not use a campaign creative's anchor, viewer location, or user-submitted query coordinate as the merchant's authoritative location.

The initial implementation may support a verified point per store. Polygon service areas, multi-entrance sites, indoor venues and multi-floor placement require a later geometry design and Safety compatibility review.

## 5. Discovery integration

Commerce exposes a bounded, versioned merchant/offer candidate read model. Discovery consumes it and remains responsible for ranking and pagination.

Candidate projection fields should be deliberately limited:
- Stable target type and ID (merchant or offer).
- Verified merchant/store references and public display fields.
- Server-managed store coordinate plus provenance/quality status needed for filtering.
- Visibility, moderation, availability and effective schedule state.
- Safe creative/thumbnail reference.
- Offer reference and a server-computed public summary of terms.
- Read-model revision and freshness metadata.

Do not expose private merchant evidence, internal risk scores, redemption secrets, or unnecessary precise customer data.

Before returning a proximity candidate:
1. Confirm merchant and store are verified, active and publicly discoverable.
2. Confirm campaign/promotion is approved, active, available and associated with that store.
3. Apply consent, audience, schedule, moderation, frequency and relevance filters.
4. Evaluate Safety DISCOVER at the authoritative store placement.
5. Return only the bounded public projection and its safety outcome.

Before AR exposure, evaluate Safety RENDER at the current render context. CAUTION must be preserved for client UX; denied outcomes suppress exposure. Critical policy lookup failures fail closed. The exact enforcement adapter remains in the owning integration boundary.

## 6. Redemption and physical-presence claims

Redemption is a server-side state transition, never a client assertion.

A redemption command must:
- Authenticate the customer and authorize the requested promotion/store.
- Re-read current merchant, store, campaign, promotion, quota and schedule state.
- Recompute eligibility on the server.
- Enforce per-user/global quotas atomically.
- Apply idempotency and replay protection.
- Evaluate applicable Safety policy for the redemption activity.
- Record an auditable result and publish an event only after the transaction commits.

A client GPS coordinate may be a relevance signal, but is not attested proof of arrival. If an offer requires physical presence, use a documented verification tier (for example, staff-issued one-time code or store-controlled QR/NFC challenge) and describe its limitations. Do not imply GPS alone prevents spoofing. Do not guarantee a discount based only on an AR overlay or countdown.

## 7. Security, privacy and trust

- Merchant onboarding and verification are separate from ordinary user authentication.
- Merchant staff permissions are scoped to merchant and, where relevant, specific stores.
- All administrative transitions are server-authorized and audited.
- Public API responses must not reveal verification evidence or private store metadata.
- Protect onboarding, campaign creation, offer issuance and redemption against enumeration, replay, mass assignment and fraud.
- Obtain clear opt-in/consent for location-based advertising where required; provide controls to disable it.
- Minimize precise viewer-location retention and never put raw coordinates in ordinary logs.
- Clearly label paid/promoted content and preserve frequency caps.
- Never obscure safety warnings, navigation cues, emergency information or accessibility controls.
- Apply jurisdiction-specific consumer, advertising, privacy, tax and business-verification requirements with legal review before launch.

## 8. Suggested API resource families

These are proposed contracts, not implemented endpoints:
- POST/GET /commerce/merchants
- POST/GET /commerce/merchants/{merchantId}/stores
- POST /commerce/stores/{storeId}/placement-verification
- POST/GET /commerce/campaigns
- POST/GET /commerce/promotions
- POST /commerce/promotions/{promotionId}/eligibility
- POST /commerce/promotions/{promotionId}/redemptions
- GET /commerce/discovery-candidates (internal/service-to-service contract; alternatively publish a read model)

Use versioned DTOs, explicit authorization, validation, pagination, optimistic concurrency, stable reason codes and idempotency for retryable commands. Never accept trusted merchant verification, eligibility, discount balance, quota remaining, or redemption status from the client.

## 9. Events and read-model consistency

Potential versioned events:
- merchant.verified.v1, merchant.suspended.v1
- store.placement.verified.v1, store.placement.changed.v1
- campaign.approved.v1, campaign.paused.v1
- promotion.activated.v1, promotion.exhausted.v1
- redemption.completed.v1, redemption.voided.v1

Events should contain stable IDs, aggregate version, occurrence time, schema version and only the minimum data needed by consumers. Use an outbox or equivalent reliable publication mechanism when persistence and event publication must remain consistent.

Discovery projections are eventually consistent. Define a freshness objective and suppress candidates when critical verification, schedule, availability or revocation state is too stale to trust. Redemption always rechecks the authoritative Commerce store; it never trusts a Discovery projection.

## 10. Implementation sequence and exit criteria

### C1 — Domain foundation
Define module ownership, merchant/store/promotion lifecycle enums, authorization matrix, DTOs, repository boundaries and migrations.
**Exit:** domain tests cover valid/invalid transitions and merchant/store isolation.

### C2 — Merchant and store registry
Implement merchant onboarding state, staff roles, store CRUD and audited placement proposal/verification.
**Exit:** unverified or suspended merchants/stores cannot enter public discovery.

### C3 — Campaign and promotion
Implement campaign approval, store association, schedules, quotas, terms and moderation/creative references.
**Exit:** no client-controlled terms or schedule can activate an offer.

### C4 — Discovery projection
Expose bounded candidate projection and connect Discovery without cross-module table access.
**Exit:** stale/invalid candidates are suppressed and DISCOVER policy remains fail-closed.

### C5 — Redemption
Implement atomic eligibility, quota reservation/consumption, idempotency, audit and event publication.
**Exit:** concurrent/replayed requests cannot exceed quotas or redeem twice.

### C6 — Proximity delivery
Only after C1–C5, integrate consent-aware proximity ads with DISCOVER, RENDER, frequency caps, paid disclosure and measured safety behavior.
**Exit:** end-to-end tests prove suppression, stale-state behavior, consent, quota and redemption invariants.

## 11. Explicit non-goals for the first release

- No real-time bidding/ad exchange.
- No automated geofence inference from campaign creatives.
- No client-authoritative discounts, countdowns, eligibility or redemption.
- No continuous customer tracking or raw movement-history warehouse.
- No polygon/multi-floor store placement until geometry and Safety contracts are ready.
- No forced extraction into an independently deployed microservice before operational need is demonstrated.

## 12. Related contracts

- Discovery service contract: ../Backend/discovery/README.md
- Spatial safety integration plan: spatial-safety-integration-plan.md
- Security and safety: security-and-safety.md
- API standards: api-standards.md
- Platform roadmap: roadmap.md
