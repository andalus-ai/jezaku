# Commerce Backend

Commerce is the authoritative domain for merchant identity, store/branch records, verified store placement, campaigns, promotions and redemption.

## Current implementation status

The initial foundation contains domain primitives only:
- Merchant lifecycle and guarded verification/suspension/reinstatement transitions.
- Store lifecycle and activation guard requiring a verified merchant and verified placement.
- WGS84 coordinate validation and placement provenance fields.
- Placement verification/revocation lifecycle and revision counter.

Not implemented yet:
- Merchant/staff authentication and authorization integration.
- Persistence, migrations, APIs, audit repository and verification workflow.
- Campaigns, promotions, quotas, eligibility and redemption.
- Discovery read-model projection or proximity ad delivery.

## Domain invariants

- Client input never directly sets a merchant to VERIFIED.
- A store cannot become ACTIVE unless its owning merchant is VERIFIED and its placement is VERIFIED.
- A verified placement records the reviewing actor and timestamp.
- Coordinates are validated as finite WGS84 latitude/longitude; accuracy must be finite and positive.
- Store schedules use an IANA time-zone identifier, not an unqualified local clock.
- Domain records are immutable; transitions return a new version.

The domain layer does not itself authenticate the verifier. The application/API layer must resolve an authorized server-side actor and invoke the transition only after the verification workflow authorizes it.

## Next implementation slices

1. Repository contracts and PostgreSQL migrations with immutable audit history.
2. Merchant onboarding and staff-role authorization boundary.
3. Store registry and audited placement review.
4. Campaign/promotion lifecycle and store associations.
5. Discovery projection and Safety integration.
6. Atomic, idempotent redemption.
