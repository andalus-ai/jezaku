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

Only an active OWNER or ADMIN of a VERIFIED merchant can invite staff. An ADMIN can grant only STORE_MANAGER or ANALYST. OWNER cannot be granted through this endpoint. Invitations expire after seven days and are persisted with inviter and expiry metadata.

The target `userId` identifies the account being invited. It is not treated as authenticated until that account accepts using its own access token.

## Accept an invitation

`POST /commerce/merchants/{merchantId}/memberships/{membershipId}/accept`

No request body. Only the authenticated user whose ID matches the invitation target can accept. Expired, revoked, or already accepted invitations are rejected. Acceptance is an optimistic-versioned, audited transition.

## List memberships

`GET /commerce/merchants/{merchantId}/memberships`

OWNER, ADMIN, and STORE_MANAGER can list membership records. ANALYST is denied access to staff enumeration.

## Revoke staff access

`POST /commerce/merchants/{merchantId}/memberships/{membershipId}/revoke`

No request body. OWNER can revoke any non-owner membership. ADMIN can revoke STORE_MANAGER and ANALYST memberships, but not another ADMIN. OWNER membership cannot be revoked through staff management.

## Authorization and persistence notes

- Merchant membership is always scoped by merchant ID and authenticated user ID.
- Role and status are loaded from the database for every operation; caller-supplied role claims are ignored.
- Membership create/update and audit append share a transaction.
- Optimistic version checks prevent stale acceptance/revocation.
- This first slice uses an existing account ID as the invitation target. Email delivery, one-time invitation links, identity-directory existence checks, ownership transfer, and authority-backed merchant verification are not implemented here.
