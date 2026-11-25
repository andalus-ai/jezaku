# Jezaku Admin Identity, Access Control and Audit Contract

> **Status:** Design contract for Phase 2. This is not an implementation claim. Runtime role grants, durable audit storage, and admin endpoints are not yet present.

## 1. Existing foundation and gaps

The current backend already provides:
- Identity-issued HS256 access tokens with issuer, subject (user ID), session ID, issued-at and expiry claims.
- Shared request authentication in `Backend/common/.../AuthFilter`.
- A request-scoped `AuthenticatedUser` and self-ownership checks through `AuthContext`.
- Separate service-to-service tokens and scopes.
- Identity account/session/guardian/device endpoints.

The following are not yet established:
- Admin roles, permission claims or an authorization policy for administrative operations.
- Durable operator grants, account/session storage, or an audit event store.
- Admin-specific provisioning, invitation, approval, step-up or recovery workflows.
- A trusted tenant/jurisdiction/resource scope registry.

Important implementation constraint: the current identity service stores accounts, sessions, guardian links and trusted devices in in-memory concurrent maps. Do not implement production operator grants or audit history in those maps. They would disappear on restart and cannot safely support multi-instance deployments.

## 2. Security model

Use **RBAC + scoped grants + policy checks**, not a single `isAdmin` boolean.

A grant is conceptually:

```text
subject (operator user ID)
  + role
  + scope type (platform | tenant | jurisdiction | resource)
  + scope ID (null only for explicitly global platform scope)
  + granted by
  + granted at
  + expires at (optional)
  + status (active | suspended | revoked | expired)
  + approval reference (when required)
```

The backend resolves active grants from trusted storage on every privileged request (or from a cache with explicit invalidation and short, bounded staleness). Never trust roles, permissions, tenant IDs, jurisdiction IDs, or scope values supplied by the browser.

### Permission evaluation

1. Authenticate the access token.
2. Resolve the operator subject and active grant set.
3. Resolve the target resource and its authoritative tenant/jurisdiction/owner scope from the owning domain.
4. Check that an active grant includes the required permission and covers the target scope.
5. Apply domain policy and any approval/step-up requirements.
6. Execute the action.
7. Persist an audit event with outcome and correlation ID.

Default deny. Unknown permission, missing scope, ambiguous resource ownership, unavailable grant store, or invalid approval must deny the operation.

### Token strategy

Do not put a long-lived, authoritative role list in the existing JWT. The token currently has a narrow identity/session purpose and is accepted by every service. Embedding admin privileges would spread privilege semantics across all services and make revocation stale until token expiry.

Keep the current JWT identity claims. Administrative authorization is resolved server-side by the owning service or a shared, carefully bounded authorization component. If a short-lived permission snapshot is later justified for performance, document its revocation and invalidation semantics in an ADR first.

## 3. Initial role catalogue

Roles are reusable bundles of permissions; scope is always attached separately.

| Role | Intended permissions |
|---|---|
| Platform Owner | Bootstrap and deployment-wide governance; smallest number of holders |
| Platform Operator | Approved deployment operations and configuration |
| Trust & Safety Moderator | Report review, moderation decisions and appeals |
| Spatial Authority Operator | Propose restrictions within verified jurisdiction |
| Spatial Authority Approver | Approve/revoke restrictions within verified jurisdiction |
| Commerce Operator | Merchant/store/campaign review within assigned scope |
| Extension Reviewer | Review package provenance, capabilities and publication requests |
| Support Operator | Minimal account lookup and support actions; sensitive fields masked |
| Auditor | Read-only audit access |

Do not grant every role to every operator. Platform Owner is not a shortcut around safety policy or domain authorization.

## 4. Permission catalogue

Use stable, namespaced identifiers. This initial catalogue is proposed and must be reconciled with each service's API contract before use.

| Permission | Scope | Notes |
|---|---|---|
| `admin.dashboard.read` | deployment | Aggregated, redacted operational overview |
| `admin.operators.read` | deployment | Read operator directory |
| `admin.operators.manage` | deployment | Provision/suspend operator; cannot self-escalate |
| `admin.roles.read` | deployment | Read role definitions and grants |
| `admin.roles.assign` | deployment or narrower | Assign only permissions the grantor may delegate |
| `admin.audit.read` | deployment or narrower | Read immutable audit records |
| `admin.moderation.read` | tenant/resource | Read moderation queue |
| `admin.moderation.review` | tenant/resource | Submit review decision |
| `admin.safety.restrictions.read` | jurisdiction | Inspect restriction state |
| `admin.safety.restrictions.propose` | jurisdiction | Submit restriction proposal |
| `admin.safety.restrictions.approve` | jurisdiction | Approve/revoke with independent authority |
| `admin.safety.emergency.activate` | jurisdiction | Scoped emergency activation, with retrospective review |
| `admin.commerce.merchants.review` | tenant/merchant | Merchant verification workflow |
| `admin.commerce.campaigns.manage` | tenant/campaign | Campaign lifecycle within scope |
| `admin.extensions.review` | marketplace/package | Review extension submission |
| `admin.extensions.publish` | marketplace/package | Publish approved package |
| `admin.extensions.revoke` | marketplace/package | Suspend or revoke published package |
| `admin.operations.read` | deployment/service | Read health and operational metadata |
| `admin.operations.jobs.retry` | service/job | Retry only when idempotency/compensation is defined |
| `admin.configuration.read` | deployment | Read non-secret settings |
| `admin.configuration.propose` | deployment | Propose versioned configuration change |
| `admin.configuration.approve` | deployment | Independently approve rollout |

A role-to-permission matrix must be maintained as version-controlled data and tested. The permission catalogue is not itself proof of access.

## 5. Separation of duties and bootstrap

- No self-assignment or self-escalation.
- A grantor cannot delegate permissions or scope they do not hold.
- Platform Owner assignment requires a separate, documented bootstrap/recovery process.
- Protect the last active Platform Owner from accidental suspension/revocation.
- High-impact grants, global configuration, emergency restrictions, extension publication and destructive operations require independent approval where feasible.
- The requester and approver must be distinct principals.
- Approval must bind to an immutable action payload/version; editing the payload invalidates the approval.
- Expire pending approvals and grants where time-bounded access is appropriate.
- Support break-glass access only with strong authentication, narrow scope, short expiry, alerting and mandatory retrospective review.

## 6. Durable storage model

Implement in the persistence strategy selected for the identity service after inspecting existing migration/database conventions. Do not assume a database that the service does not yet use.

Conceptual entities:

### OperatorProfile
- subject user ID (unique FK/reference to identity account)
- operator status
- created/updated timestamps
- provisioning source

### AdminRole
- stable role key, display name, description
- immutable/versioned role definition
- status

### AdminPermission
- stable permission key, resource/action description
- policy version and status

### RolePermission
- role key, permission key
- unique pair and version

### AdminGrant
- grant ID, subject, role, scope type, scope ID
- status, grantor, timestamps, optional expiry
- approval ID and reason
- optimistic version

### AdminApproval
- approval ID, action type, immutable payload digest
- requester, approver, state, reason, expiry and timestamps
- prohibit same requester/approver

### AdminAuditEvent
- append-only event ID, schema version, actor, action, target, scope
- outcome, reason, request/correlation ID, server timestamp
- before/after references or redacted diff
- approval reference and policy version

Use database constraints for uniqueness and referential integrity. Add migrations, indexes for subject/scope/time searches, retention policy, backup/restore and migration tests. Audit records must not be updated/deleted through application APIs.

## 7. Audit contract

Record successful and denied privileged actions, plus sensitive read/export events. Minimum event envelope:

```json
{
  "eventId": "server-generated-uuid",
  "schemaVersion": 1,
  "occurredAt": "server-generated-UTC-timestamp",
  "actor": {"subjectId": "operator-id", "clientId": "jezaku-admin"},
  "action": "admin.roles.assign",
  "target": {"type": "admin-grant", "id": "grant-id"},
  "scope": {"type": "tenant", "id": "tenant-id"},
  "outcome": "DENIED",
  "reasonCode": "SCOPE_NOT_GRANTED",
  "justification": "operator-supplied reason, length-limited",
  "requestId": "correlation-id",
  "approvalId": null,
  "policyVersion": "1"
}
```

The values above are illustrative; IDs and timestamps are server-derived, not trusted from clients.

Never record passwords, bearer/refresh tokens, secret values, raw private messages, camera media, or unnecessary precise location. Keep justification free of sensitive payloads. Audit reads/exports are also audited. Export is permission-controlled, bounded, redacted, and watermarked with request metadata.

Audit persistence must be transactionally coupled to the privileged state change where possible (same database transaction/outbox). If durable audit cannot be written, fail closed for high-impact operations. Define how to record denied requests when no domain transaction occurs.

## 8. Endpoint contract (proposed)

The following is a contract proposal, not a statement that these routes exist.

| Method | Route | Purpose |
|---|---|---|
| GET | `/admin/operators` | Paginated operator directory |
| POST | `/admin/operators/invitations` | Create time-limited invitation |
| GET | `/admin/operators/{id}/grants` | Read scoped grants |
| POST | `/admin/operators/{id}/grants` | Request/assign grant under delegation rules |
| DELETE | `/admin/grants/{grantId}` | Revoke grant |
| GET | `/admin/roles` | Read role catalogue |
| GET | `/admin/permissions` | Read permission catalogue |
| POST | `/admin/approvals` | Submit immutable action for approval |
| POST | `/admin/approvals/{id}/decision` | Approve/reject as independent approver |
| GET | `/admin/audit-events` | Search scoped audit history |

All collection routes require bounded pagination and allowlisted filters/sorts. Mutations require reason, idempotency key where applicable, optimistic version, and explicit scope. Return stable error codes for unauthenticated, forbidden, scope mismatch, approval required, stale version, and unavailable authorization service.

## 9. Integration with existing services

- Identity owns operator identity, grant lifecycle and session revocation.
- Each domain service still owns authorization of its own domain mutations and verifies resource scope itself.
- A shared authorization library may provide policy primitives and request context, but must not silently turn every service into an admin endpoint.
- Service-to-service scopes remain distinct from human operator permissions.
- Never let an admin browser call internal service endpoints using service credentials.
- Cross-service orchestration must propagate the verified actor, reason, approval and request ID in a tamper-resistant server-to-server contract; never accept an actor header directly from the browser.

## 10. Required security tests

- Anonymous request denied in production profile.
- Authenticated non-operator denied.
- Operator with wrong permission denied.
- Correct permission but wrong tenant/jurisdiction denied.
- Expired/revoked grant denied immediately within the documented revocation SLA.
- Client-forged role/scope/actor headers ignored.
- Self-escalation and unauthorized delegation denied.
- Requester cannot approve own action.
- Stale action payload invalidates approval.
- Last owner cannot be accidentally removed.
- Audit event created for success and denied privileged operations.
- Audit failure blocks high-impact mutation.
- No secrets or sensitive user content in audit/log responses.
- Pagination, export and batch endpoints enforce identical scope checks.

## 11. Delivery order

1. Choose durable persistence and migration conventions for identity.
2. Implement permission/scope policy primitives and test them independently.
3. Implement operator/grant/role persistence and repository tests.
4. Implement append-only audit/outbox and transaction tests.
5. Add protected admin APIs and authorization tests.
6. Add provisioning, invitation, approval, revocation and session controls.
7. Integrate Flutter People & Access and Audit screens against the actual OpenAPI contract.
8. Add deployment bootstrap/recovery runbook and security review.

Do not ship UI mutations before steps 1–5 are complete.
