# Commerce Backend

Commerce is the authoritative domain for merchant identity, store/branch records, verified store placement, campaigns, promotions and redemption.

## Current implementation status

Implemented:
- Guarded merchant lifecycle and store activation invariants.
- WGS84 placement validation and provenance.
- PostgreSQL/Flyway schema for merchants, merchant-scoped memberships, stores, placements, immutable placement revisions and audit events.
- JDBC merchant and store repositories, including placement persistence.
- JDBC membership lifecycle persistence and active-membership lookup scoped by merchant ID and authenticated user ID.
- Authenticated merchant registration that creates the initial owner membership atomically.
- Seven-day staff invitations, renewal of expired/revoked invitations, acceptance by the invited account, role-bounded revocation and membership audit events.
- Merchant onboarding REST endpoints whose actor identity is resolved from the verified authentication context.
- Optimistic aggregate version checks and atomic audit writes for merchant/store create and update operations.
- Environment-variable based datasource configuration.

Not yet implemented:
- Email delivery, one-time invitation links and identity-directory existence checks.
- Trusted merchant verification/rejection administration and ownership transfer.
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
- Merchant registration creates the merchant and initial OWNER membership in one service transaction.
- The REST resource derives actor identity from the verified access token; actor, inviter, owner and role are never accepted as trusted caller identity from request fields.
- Only OWNER/ADMIN can invite staff after merchant verification. ADMIN cannot grant ADMIN/OWNER privileges.
- Only the invitation target can accept. Invitations expire after seven days and all membership transitions are optimistic-versioned and audited.
- OWNER membership cannot be revoked through staff-management operations.
- Database uniqueness prevents duplicate membership for the same merchant/user pair.
- Client-submitted coordinates remain proposals; the repository does not authorize verification. The application layer must resolve a trusted server-side reviewer before invoking the domain transition.

## Database

Flyway migration V1__commerce_registry.sql creates the merchant/store registry and audit tables. V2__commerce_store_placement_history.sql creates the immutable placement-revision table and backfills the current snapshot for existing stores. V3__commerce_membership_lifecycle.sql adds invitation expiry, inviter and activation metadata with lifecycle constraints.

The local database defaults to jezaku_commerce on localhost:5432. Override using JZ_COMMERCE_DB_URL, JZ_COMMERCE_DB_USERNAME and JZ_COMMERCE_DB_PASSWORD. Configure deployment credentials through a secret manager.

## Operational notes

The current store-placement table remains the fast latest-state snapshot. The placement-revision table is the historical source for prior coordinate/provenance payloads. Direct database writers must follow the same append-only revision protocol; database roles used by application services should not be granted UPDATE or DELETE on the history table.

The repository adapters are persistence primitives, not authorization boundaries. Callers must authorize merchant-scoped operations before invoking them.

## Next slices

1. Expand PostgreSQL-backed repository integration tests to cover merchant updates, rollback on audit failure and concurrent writers; verify Flyway against the supported PostgreSQL version.
2. Add trusted merchant verification/rejection administration, invitation delivery and ownership transfer.
3. Add audited placement review/revocation workflows.
4. Add campaign/promotion lifecycle and store associations.
5. Add Discovery projection and Safety integration.
6. Add atomic, idempotent redemption.


## Trusted merchant review

Merchant verification is a separate trust boundary from merchant ownership and staff administration. The merchant-facing API cannot create reviewer grants, change reviewer status, widen reviewer jurisdiction, or grant reviewer permissions.

Migration V4 adds:
- `commerce_merchant_reviewer`: server-provisioned reviewer identity, status and validity window.
- `commerce_merchant_reviewer_scope`: explicit jurisdiction grants; there is no wildcard or prefix inheritance.
- `commerce_merchant_reviewer_permission`: independent VERIFY, REJECT, SUSPEND and REINSTATE permissions.

The runtime repository is read-only. Reviewer provisioning and revocation must be performed by a trusted operator workflow using a separately controlled database role, with operational audit retained by that workflow. The application database role should receive SELECT but not INSERT/UPDATE/DELETE on reviewer grant tables.

Review operations derive the reviewer identity from the verified access token, require an active grant valid at the current server time, exact jurisdiction scope and action-specific permission. A reviewer who has any membership in the merchant being reviewed is denied, preventing owner/staff self-verification. Review reasons are mandatory and recorded in the merchant aggregate audit event. Updates use the merchant aggregate version; concurrent review decisions return a conflict.

Endpoints:
- `POST /commerce/merchants/{merchantId}/review/verify`
- `POST /commerce/merchants/{merchantId}/review/reject`
- `POST /commerce/merchants/{merchantId}/review/suspend`
- `POST /commerce/merchants/{merchantId}/review/reinstate`

Each accepts only a `reasonCode`; reviewer identity, permission, jurisdiction and timestamps are never client-controlled. Verification is the only transition that makes a pending merchant eligible for staff invitations and store activation. Rejection is terminal in this initial lifecycle; reinstatement applies only to suspended verified merchants.

The review API does not yet ingest or retain identity documents. Evidence storage, reviewer assignment queues, dual-control for high-risk decisions and operator-facing grant management remain follow-up work.


## Merchant review cases and evidence foundation (V5)

V5 introduces a versioned review case, evidence metadata references and append-only decision history. This is distinct from store-placement verification: merchant identity/legal eligibility and the physical location of a store are separate trust decisions with separate reviewers and evidence.

Review cases move through `OPEN`, `IN_REVIEW`, `NEEDS_INFORMATION`, and terminal `APPROVED`, `REJECTED` or `CLOSED` states. Only an assigned reviewer may request information or decide a case. The database permits at most one active case per merchant. Optimistic versions protect case transitions.

Evidence records reference an opaque `mediaAssetId` owned by the Media service. Commerce does not accept or persist public URLs, storage keys, document bytes, OCR claims, or client assertions that an asset is verified. The future submission API must call a Media ownership/authorization boundary to establish that the authenticated merchant actor may attach that asset before writing evidence metadata. Media remains responsible for upload validation, malware scanning, encryption, retention and access-controlled retrieval.

Evidence categories include business registration, tax registration, identity, address proof and authorization. Evidence is immutable in identity and submission provenance; its review status transitions from RECEIVED to ACCEPTED/REJECTED, or to WITHDRAWN before review. Rejection requires a reason. Decision rows capture the case version and an evidence-version snapshot so later review can reconstruct which evidence was considered.

The current slice adds domain invariants and database schema only. Evidence upload/submission endpoints, reviewer queue/assignment APIs, document retrieval authorization, and the orchestration that turns an APPROVED case into the merchant VERIFIED transition are intentionally deferred until the Media asset authorization contract is integrated. Existing review endpoints remain the current merchant status transition surface and must not be mistaken for a complete evidence-backed workflow.


## Durable merchant review case operations (V6 repository slice)

The V5 review-case and evidence schema is now backed by a JDBC repository:
- Create and retrieve review cases; look up the active case for a merchant.
- Read a bounded reviewer queue (maximum 100 rows), optionally filtered by status and assigned reviewer.
- Apply optimistic-versioned case transitions.
- Append a decision record in the same transaction as the case transition.
- Read append-only decision history, including the exact case version and evidence-version snapshot captured at decision time.

This repository is a persistence boundary, not an authorization boundary. Reviewer assignment, reviewer grant checks, merchant self-review prevention, and evidence ownership checks must be enforced by the service before repository calls. The evidence snapshot is server-generated data; it must never be accepted as a client-authored assertion. The current repository slice does not yet expose queue/assignment endpoints or submit evidence. Those are follow-up service/API work, and evidence submission remains blocked on a real Media ownership authorization API.
