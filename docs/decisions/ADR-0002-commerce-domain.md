# ADR-0002: Establish a dedicated Commerce domain

- **Status:** Accepted
- **Date:** 2026-11-23
- **Decision owners:** Jezaku platform maintainers

## Context

Jezaku needs verified merchant/store identity, authoritative store placement, campaigns, promotions, quotas, eligibility and redemption to support future proximity advertising and commerce experiences.

The current Social monetization model is graph/audience-oriented and does not establish authoritative merchant placement. Discovery already owns ranked retrieval and spatial DISCOVER enforcement, but it does not own merchant identity, offer inventory, campaign billing or redemption. Safety owns spatial restrictions and policy evaluation.

Putting merchant records and redemption into Social would couple distinct business models. Putting them into Discovery would make a retrieval/indexing service the source of commercial truth. Duplicating Safety checks or policy state in Commerce would create conflicting enforcement.

## Decision

Establish Commerce as a dedicated logical domain/module with ownership of:
- Merchant verification and merchant-scoped staff authorization.
- Stores/branches and authoritative, provenance-backed spatial placement.
- Campaigns, promotions, schedules, availability and quotas.
- Eligibility and idempotent, audited redemption.

Keep Discovery responsible for candidate retrieval/ranking and consume Commerce-owned bounded read models or explicit APIs/events. Keep Safety responsible for spatial restriction policy and evaluate it at the relevant operation boundary. Keep existing non-spatial Social ads on their current delivery path.

Start as a logical module within the existing backend architecture. Do not create a separate deployable or new infrastructure stack until operational, security, scaling or team boundaries justify it.

## Alternatives considered

1. Extend Social monetization. Rejected: graph/audience campaigns and merchant/store inventory have different ownership, verification, lifecycle and redemption requirements.
2. Store merchants and offers in Discovery. Rejected: Discovery should not become the system of record for commercial facts; ranking/indexing lifecycle differs from legal and transactional state.
3. Put merchant policy in Safety. Rejected: Safety evaluates spatial restrictions; it is not a merchant onboarding or promotion eligibility engine.
4. Create an independent Commerce microservice immediately. Deferred: premature deployment and operational complexity before contracts and scale are established.

## Consequences

Positive:
- Clear ownership and trust boundary for merchant and offer facts.
- Discovery can evolve its ranking/read model independently.
- Social ads remain compatible and are not misrepresented as proximity ads.
- Redemption can enforce transactional invariants and audit independently of client presentation.

Costs and constraints:
- Requires explicit integration contracts and projection freshness handling.
- Merchant verification and store-placement review workflows must be designed.
- Cross-domain operations require reliable events or bounded service calls.
- Proximity delivery is intentionally deferred until authoritative data and consent/safety gates exist.

## Safety and security implications

- Client-submitted coordinates are proposals, not proof of merchant ownership or physical presence.
- Public proximity candidates require verified merchant/store status and server-managed placement.
- Apply Safety DISCOVER at the store placement and RENDER at the current render context.
- Redemption rechecks current authoritative state, policy, quotas and eligibility server-side with idempotency.
- Consent, paid-content disclosure, moderation, frequency caps and privacy minimization are release requirements.

## Migration implications

No existing Social campaign is migrated or reclassified as a merchant proximity campaign by this ADR. Existing graph/audience ads remain unchanged. The first implementation should add Commerce domain contracts and persistence without changing current Discovery behavior until verified merchant/store data is available.

See Commerce Domain Architecture (../commerce-architecture.md) for the detailed target model and staged implementation plan.
