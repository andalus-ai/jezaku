# Commerce Backend

Commerce is the authoritative domain for merchant identity, store/branch records, verified store placement, campaigns, promotions and redemption.

## Current implementation status

Implemented:
- Guarded merchant lifecycle and store activation invariants.
- WGS84 placement validation and provenance.
- PostgreSQL/Flyway schema for merchants, merchant-scoped memberships, stores, placements, immutable placement revisions and audit events.
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
- Store creation persists the store, current placement, immutable revision zero and audit records atomically.
- Every changed placement must advance its revision by exactly one; the current snapshot update and immutable revision insert share the store transaction.
- Placement history preserves coordinates, accuracy, source, status, verifier, verification time, actor, action, record time and reason code. Historical rows are append-only through the repository contract.
- Membership lookup is always constrained by merchant ID, user ID and ACTIVE status.
- Database uniqueness prevents duplicate membership for the same merchant/user pair.
- Client-submitted coordinates remain proposals; the repository does not authorize verification. The application layer must resolve a trusted server-side reviewer before invoking the domain transition.

## Database

Flyway migration V1__commerce_registry.sql creates the merchant/store registry and audit tables. V2__commerce_store_placement_history.sql creates the immutable placement-revision table and backfills the current snapshot for existing stores.

The local database defaults to jezaku_commerce on localhost:5432. Override using JZ_COMMERCE_DB_URL, JZ_COMMERCE_DB_USERNAME and JZ_COMMERCE_DB_PASSWORD. Configure deployment credentials through a secret manager.

## Operational notes

The current store-placement table remains the fast latest-state snapshot. The placement-revision table is the historical source for prior coordinate/provenance payloads. Direct database writers must follow the same append-only revision protocol; database roles used by application services should not be granted UPDATE or DELETE on the history table.

The repository adapters are persistence primitives, not authorization boundaries. Callers must authorize merchant-scoped operations before invoking them.

## Next slices

1. Expand PostgreSQL-backed repository integration tests to cover merchant updates, rollback on audit failure and concurrent writers; verify Flyway against the supported PostgreSQL version.
2. Add merchant onboarding and server-resolved staff authorization.
3. Add audited placement review/revocation workflows and immutable placement history.
4. Add campaign/promotion lifecycle and store associations.
5. Add Discovery projection and Safety integration.
6. Add atomic, idempotent redemption.
