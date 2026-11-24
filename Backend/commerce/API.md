# Commerce Merchant Onboarding API

All routes require an authenticated user access token. The actor ID is taken exclusively from the verified authentication context; request bodies never accept an actor, owner, or inviter identity.

Base path: `/commerce/merchants`

## Register a merchant

`POST /commerce/merchants`

Request:
```json
{
  "legalName": "Example Legal Entity PT",
  "displayName": "Example Store Group",
  "jurisdiction": "ID"
}
```

Creates a merchant in `PENDING_VERIFICATION` and an ACTIVE `OWNER` membership for the authenticated caller in the same transaction. Returns `201` with the merchant.

The owner can manage the merchant account, but merchant verification is a separate trusted review operation. A pending merchant cannot invite staff or activate stores.

## Invite staff

`POST /commerce/merchants/{merchantId}/memberships`

Request:
```json
{
  "userId": "identity-user-id",
  "role": "STORE_MANAGER"
}
```

Only an active OWNER or ADMIN of a VERIFIED merchant can invite staff. An ADMIN can grant only STORE_MANAGER or ANALYST. OWNER cannot be granted through this endpoint. Invitations expire after seven days and are persisted with inviter and expiry metadata. Repeating the invitation request can renew an expired invitation or re-invite a previously revoked member without creating a duplicate membership identity; active memberships and unexpired invitations cannot be duplicated.

The target `userId` identifies the account being invited. It is not treated as authenticated until that account accepts using its own access token.

## Accept an invitation

`POST /commerce/merchants/{merchantId}/memberships/{membershipId}/accept`

No request body. Only the authenticated user whose ID matches the invitation target can accept. Expired, revoked, or already accepted invitations are rejected. Acceptance is an optimistic-versioned, audited transition.

## List memberships

`GET /commerce/merchants/{merchantId}/memberships`

Only OWNER and ADMIN can list membership records. STORE_MANAGER and ANALYST cannot enumerate staff.

## Revoke staff access

`POST /commerce/merchants/{merchantId}/memberships/{membershipId}/revoke`

No request body. OWNER can revoke any non-owner membership. ADMIN can revoke STORE_MANAGER and ANALYST memberships, but not another ADMIN. OWNER membership cannot be revoked through staff management.

## Authorization and persistence notes

- Merchant membership is always scoped by merchant ID and authenticated user ID.
- Role and status are loaded from the database for every operation; caller-supplied role claims are ignored.
- Membership create/update and audit append share a transaction.
- Optimistic version checks prevent stale acceptance/revocation.
- This first slice uses an existing account ID as the invitation target. Email delivery, one-time invitation links, identity-directory existence checks, ownership transfer, and authority-backed merchant verification are not implemented here.


## Trusted merchant review

These operations are reserved for independently provisioned reviewers. They require an authenticated user token and a server-side reviewer grant matching the merchant's exact jurisdiction and the requested action.

All four endpoints accept:
```json
{ "reasonCode": "DOCUMENTS_CONFIRMED" }
```

- `POST /commerce/merchants/{merchantId}/review/verify` — VERIFY permission; transitions PENDING_VERIFICATION to VERIFIED.
- `POST /commerce/merchants/{merchantId}/review/reject` — REJECT permission; transitions PENDING_VERIFICATION to REJECTED.
- `POST /commerce/merchants/{merchantId}/review/suspend` — SUSPEND permission; transitions VERIFIED to SUSPENDED.
- `POST /commerce/merchants/{merchantId}/review/reinstate` — REINSTATE permission; transitions SUSPENDED to VERIFIED.

The caller identity comes only from the verified access token. The request cannot specify reviewer identity, reviewer status, jurisdiction, permissions, or decision time. Reviewers cannot review a merchant where they hold any merchant membership, including OWNER. Jurisdiction matching is exact; wildcard and implicit descendant scopes are not supported.

Reviewer grants are provisioned outside the merchant API in V4 tables. The application role should be read-only on reviewer grant tables. A missing, inactive, expired, out-of-scope or insufficient reviewer grant is denied. Every decision requires a reason code and writes an auditable merchant state transition with optimistic version checking. Invalid lifecycle transitions and concurrent updates return conflict responses.

The initial reviewer-grant provisioning workflow is operational/out-of-band. Document evidence upload, reviewer queues, dual approval and reviewer administration endpoints are not part of this slice.


## Review case persistence contract (internal, not yet exposed as REST endpoints)

The Commerce persistence layer supports:
- Creating a review case for a merchant.
- Fetching a case by ID and the current active case for a merchant.
- Listing active review work with optional status and assigned-reviewer filters; page size is bounded to 100.
- Optimistic case transitions using the expected case version.
- Atomic append of a decision-history row with the case transition.
- Reading decision history in chronological order, including the evidence snapshot and case version.

These repository methods are not directly callable by clients. A future review-case resource must derive the reviewer from the verified access token, validate an active reviewer grant for the merchant jurisdiction and action, prevent merchant participants from reviewing their own merchant, and require a reason for every decision. The decision's evidence snapshot must be assembled server-side from persisted evidence versions.

No evidence submission endpoint is enabled yet. The Media module currently has no asset ownership/authorization API, so Commerce must not accept an arbitrary media asset ID as proof that the caller may attach it.