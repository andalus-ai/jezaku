# Commerce Backend

Commerce is the authoritative domain for merchant identity, store/branch records, verified store placement, campaigns, promotions and redemption.

## Current implementation status

The domain foundation and registry persistence contracts are present:
- Guarded merchant lifecycle and store activation invariants.
- WGS84 placement validation and provenance.
- PostgreSQL/Flyway dependencies and initial registry schema.
- Repository interfaces for merchants, stores and merchant-scoped membership access.
- Audit event schema for merchant, store, placement and membership changes.

JDBC repository implementations, API resources, onboarding, staff invitations and placement-review workflows are not yet implemented.

## Persistence invariants

- Membership authorization is scoped by both merchant ID and user ID.
- Audit records include actor, action, aggregate version, timestamp and reason code.
- Each state mutation and its audit append must commit atomically.
- Optimistic version conflicts must not become last-write-wins updates.
- Client-submitted coordinates remain proposals; verification requires a server-authorized workflow.

## Database

Flyway migration V1__commerce_registry.sql creates commerce_merchant, commerce_merchant_membership, commerce_store, commerce_store_placement and commerce_audit_event.

The local database defaults to jezaku_commerce on localhost:5432. Override using JZ_COMMERCE_DB_URL, JZ_COMMERCE_DB_USERNAME and JZ_COMMERCE_DB_PASSWORD. Configure deployment credentials through a secret manager.

## Next slices

1. JDBC repositories with optimistic locking and atomic audit writes.
2. Merchant onboarding and scoped staff authorization.
3. Store registration and audited placement review.
4. Campaign/promotion lifecycle and store associations.
5. Discovery projection and Safety integration.
6. Atomic, idempotent redemption.
