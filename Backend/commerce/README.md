# Commerce Backend

Commerce is the authoritative domain for merchant identity, store/branch records, verified store placement, campaigns, promotions and redemption.

## Current implementation status

The initial domain foundation and registry persistence contract are present:
- Merchant lifecycle and guarded verification/suspension/reinstatement transitions.
- Store lifecycle; activation requires the verified owning merchant and verified placement.
- WGS84 coordinate validation and placement provenance.
- PostgreSQL/Flyway dependency and initial registry schema.
- Repository interfaces for merchant, store and merchant-scoped membership access.
- Merchant/store/placement/membership audit table schema.

The repository interfaces are contracts only. JDBC implementations, API resources, onboarding, staff invitation and verification workflows are not yet implemented.

## Domain invariants

- Client input never directly sets a merchant to VERIFIED.
- A store cannot become ACTIVE unless its owning merchant is VERIFIED and its placement is VERIFIED.
- A verified placement records the reviewing actor and timestamp.
- Coordinates are validated as finite WGS84 latitude/longitude; accuracy must be finite and positive.
- Store schedules use an IANA time-zone identifier, not an unqualified local clock.
- Domain records are immutable; transitions return a new version.
- Membership queries and authorization must be scoped by both merchant ID and user ID.
- State changes and their audit events must commit atomically.
- Version mismatches are conflicts, not last-write-wins updates.

The domain layer does not authenticate the verifier. The application/API layer must resolve an authorized server-side actor and invoke transitions only after the verification workflow authorizes them.

## Database

Flyway migration V1__commerce_registry.sql creates:
- commerce_merchant
- commerce_merchant_membership
- commerce_store
- commerce_store_placement
- commerce_audit_event

The default local database is jezaku_commerce on localhost:5432. Override with JZ_COMMERCE_DB_URL, JZ_COMMERCE_DB_USERNAME and JZ_COMMERCE_DB_PASSWORD. Configure secrets through the deployment secret manager; local defaults are development-only.

## Next implementation slices

1. JDBC repositories with optimistic locking and atomic audit writes.
2. Merchant onboarding and staff-role authorization boundary.
3. Store registry and audited placement review.
4. Campaign/promotion lifecycle and store associations.
5. Discovery projection and Safety integration.
6. Atomic, idempotent redemption.
