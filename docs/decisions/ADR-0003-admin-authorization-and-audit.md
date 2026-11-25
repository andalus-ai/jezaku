# ADR-0003: Administrative Authorization and Audit Ownership

- **Status:** Accepted as a design direction; implementation pending
- **Date:** 2026-11-25

## Context

Jezaku has a shared JWT authentication foundation in `Backend/common` and an identity service that issues user tokens. Current user tokens identify a subject and session. Shared `AuthContext` enforces user self-ownership, while service tokens carry a separate set of machine-to-machine scopes.

The identity service currently stores accounts and sessions in in-memory maps. There is no durable admin grant model or immutable administrative audit store. The backend service catalog assigns domain authority to independent Quarkus services.

The Admin Console needs operator management, scoped permissions, approval workflows and auditable privileged actions without weakening existing domain boundaries.

## Decision

1. Preserve the existing identity/session JWT as an authentication credential. Do not add a global `isAdmin` claim or make browser-supplied roles authoritative.
2. Implement human administrative authorization as server-side RBAC plus explicit resource scopes and domain policy checks.
3. Identity owns operator profiles, grant lifecycle, role catalogue and operator session lifecycle.
4. Each owning domain service independently enforces authorization and resolves the target resource's authoritative tenant/jurisdiction/ownership scope before performing a privileged operation.
5. Keep machine-to-machine service scopes separate from human admin permissions.
6. Persist grants, approvals and audit events durably. Do not implement production access control or audit using the current in-memory identity maps.
7. Require reason capture, independent approval for high-impact actions, and append-only audit records. Couple audit persistence to the state change using a transaction/outbox where possible.
8. Do not introduce a dedicated admin microservice initially. Consider a BFF only after concrete aggregation needs are measured and an ADR is approved.

## Consequences

### Positive
- Existing login/session compatibility is preserved.
- Domain services remain authoritative for domain data and policy.
- Revocation and scope checks are centrally understandable without trusting browser state.
- Human and machine identities remain distinct.
- Durable audit and approval semantics can be tested and reviewed.

### Trade-offs
- Admin operations may require service-owned checks and explicit actor propagation.
- Cross-service administrative workflows need a trusted server-to-server contract.
- Durable persistence and migrations must be established before production grants.
- Immediate revocation requires authoritative grant lookup or a carefully invalidated cache.

## Rejected alternatives

- A single boolean admin claim in every JWT: too coarse, stale on revocation, and spreads platform privilege into all services.
- UI-only route guards: not a security boundary.
- A new admin database/service duplicating domain records: creates competing sources of truth.
- Storing grants/audit in in-memory maps: loses data on restart and fails across instances.
