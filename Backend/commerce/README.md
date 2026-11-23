# Commerce Backend

Commerce is the authoritative domain for merchant identity, store/branch records, verified store placement, campaigns, promotions and redemption.

## Current implementation status

Implemented:
- Guarded merchant lifecycle and store activation invariants.
- WGS84 placement validation and provenance.
- PostgreSQL/Flyway schema for merchants, merchant-scoped memberships, stores, placements and audit events.
- JDBC merchant and store repositories, including placement persistence.
- JDBC active-membership lookup scoped by both merchant ID and user ID.
- Optimistic aggregate version checks and atomic audit writes for merchant/store create and update operations.
- Environment-variable based datasource configuration.

Not yet implemented:
- Merchant onboarding and staff membership mutation/invitation APIs.
- Authorized placement review endpoints and verification-role resolution.
- Campaign, promotion, quota, eligibility and redemption persistence.
- Full PostgreSQL integration test suite.

## Persistence guarantees

- Merchant and store updates require the expected aggregate version. A mismatch returns an empty result and does not append an audit event.
- State mutation and audit append execute in one Quarkus JTA transaction. An audit failure rolls back the aggregate write.
- Update timestamps cannot move backwards.
- Store creation persists the store, initial placement and both audit records atomically.
- Membership lookup is always constrained by merchant ID, user ID and ACTIVE status.
- Database uniqueness prevents duplicate membership for the same merchant/user pair.
- Client-submitted coordinates remain proposals; the repository does not authorize verification. The application layer must resolve a trusted server-side reviewer before invoking the domain transition.

## Database

Flyway migration V1__commerce_registry.sql creates commerce_merchant, commerce_merchant_membership, commerce_store, commerce_store_placement and commerce_audit_event.

The local database defaults to jezaku_commerce on localhost:5432. Override using JZ_COMMERCE_DB_URL, JZ_COMMERCE_DB_USERNAME and JZ_COMMERCE_DB_PASSWORD. Configure deployment credentials through a secret manager.

## Operational notes

The current store-placement table holds the latest placement snapshot. The audit event records the placement revision and action, but does not yet retain a full immutable copy of every prior coordinate payload. A dedicated placement revision/history table should be introduced before exposing self-service placement editing at scale.

The repository adapters are persistence primitives, not authorization boundaries. Callers must authorize merchant-scoped operations before invoking them.

## Next slices

1. Add PostgreSQL-backed repository integration tests and verify Flyway against the supported PostgreSQL version.
2. Add merchant onboarding and server-resolved staff authorization.
3. Add audited placement review/revocation workflows and immutable placement history.
4. Add campaign/promotion lifecycle and store associations.
5. Add Discovery projection and Safety integration.
6. Add atomic, idempotent redemption.
