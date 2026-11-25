# Identity Service: Administrative Access Control

This document defines the intended identity-service responsibilities for Jezaku administration. It does not describe implemented endpoints.

## Ownership

Identity is responsible for:
- operator profile and lifecycle linked to an existing identity account;
- versioned role and permission catalogue;
- scoped admin grants and revocation;
- operator invitation/provisioning workflow;
- admin approval requests where identity is the workflow owner;
- operator session revocation and access review metadata.

Identity is not responsible for:
- moderation decisions and spatial restriction policy (Safety);
- merchant/campaign state (Commerce);
- extension execution or package scanning (Marketplace/extension domain);
- operational control of infrastructure owned by deployment tooling.

## Security requirements

Follow [the admin identity/access/audit contract](../../../docs/admin-identity-and-access.md) and [backend architecture](../../docs/architecture.md).

- Do not store production grants or audit events in the current in-memory maps.
- Do not add roles to JWTs as an authorization source.
- Do not expose generic cross-user account mutation endpoints.
- Every endpoint must authenticate, authorize, enforce scope, validate input and emit audit as appropriate.
- Resolve resource scope from trusted domain data, never request parameters alone.
- Require independent approval for privilege escalation and high-impact grants.
- Use durable migrations and test revocation across multiple application instances.
- Keep service-to-service scopes separate from human operator grants.

## Implementation prerequisites

Before adding runtime entities/resources:
1. Select and document the identity service's durable persistence and migration approach.
2. Confirm how identity accounts are persisted and how account IDs are referenced.
3. Define a transactional audit/outbox strategy.
4. Define operator bootstrap, recovery, invitation and step-up authentication.
5. Add authorization policy unit tests before exposing any admin mutation API.

## Suggested future package boundaries

Adapt to the existing package conventions when implementation begins:
- `admin`: operator profiles, grants, roles, approvals, resources and service layer.
- `audit`: append-only audit event model and persistence.
- `auth`: shared authentication remains in `common`; do not duplicate JWT verification.
