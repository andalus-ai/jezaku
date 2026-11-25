# ADR-0004: Alhambra as the Shared Platform Foundation

- **Status:** Accepted direction; adoption is staged and implementation remains pending.
- **Date:** 2026-11-25
- **Owners:** Jezaku platform maintainers

## Context

Jezaku needs a reusable application foundation for its operator console and future extension ecosystem. The separate Alhambra repository already contains reusable Flutter UI, plugin API/runtime, capability, composition, integrity, lifecycle, recovery, and revocation work.

Duplicating these systems inside Jezaku would create parallel contracts and increase maintenance cost. Merging the repositories, however, would couple a reusable foundation to one product's domain and release cycle.

Alhambra's Flutter plugin runtime is an in-process composition/lifecycle system, not a secure sandbox for arbitrary downloaded Dart code. Alhambra's identity package also must not be treated as Jezaku's authoritative backend authorization system: the current package's reference repositories are in-memory and its authorization service requires security hardening before production use.

## Decision

1. **Keep repositories separate.** Alhambra remains a reusable platform foundation; Jezaku remains the product and domain implementation.
2. **Adopt Alhambra selectively.** Evaluate and consume stable Alhambra packages where they remove genuine duplication, beginning with UI composition for the Jezaku Admin Flutter client after package compatibility and build validation.
3. **Pin dependencies.** Consume Alhambra packages through immutable Git commit references or a versioned internal/public package release. Do not depend on a moving branch in production. Keep a documented upgrade and compatibility policy.
4. **Preserve backend authority.** Jezaku's Quarkus services remain authoritative for authentication, operator grants, scopes, resource ownership, approval, domain invariants, and privileged actions. The client and Alhambra UI/runtime may improve presentation and composition but cannot grant authority.
5. **Keep domain ownership in Jezaku.** Spatial/AR placement, geospatial navigation, safety and moderation policy, merchant advertising, marketplace publication policy, and Jezaku-specific operator permissions remain Jezaku concerns.
6. **Do not execute untrusted marketplace code in-process.** Marketplace packages require a separately designed isolation boundary, such as a constrained declarative contribution model or an isolated remote/server execution model. A signature or manifest alone does not make arbitrary code safe.
7. **Treat Alhambra identity as a contract/reference implementation until hardened.** Do not use its current authorization service as the enforcement point for Jezaku backend APIs. Review fail-closed behavior, principal trust, scope checks, durable persistence adapters, and audit guarantees before any production adoption.
8. **No new admin microservice by default.** Admin operations remain in the existing owning Jezaku services unless a later ADR justifies a thin aggregation layer.

## Target boundary

```text
Jezaku Admin Flutter app
  └─ Alhambra UI / composition packages (pinned dependency)
       └─ presentation and client-side contribution composition only

Jezaku Quarkus services
  ├─ identity: operator identity, grants, sessions, audit ownership
  ├─ safety: moderation and spatial restriction decisions
  ├─ commerce: merchant, campaign and redemption truth
  ├─ spatial and other domain services: resource ownership and invariants
  └─ enforce every privileged request server-side

Alhambra repository
  └─ reusable UI, plugin contracts/runtime, capability and lifecycle foundation
     (not Jezaku domain policy; not a general-purpose untrusted-code sandbox)
```

## Consequences

### Positive
- Reuses platform work without merging product and foundation repositories.
- Keeps Jezaku's backend security and domain authority explicit.
- Allows Alhambra to evolve for multiple host products.
- Creates a clear gate for future marketplace execution architecture.

### Costs and constraints
- Package versions and Flutter/Dart compatibility must be managed deliberately.
- Alhambra packages and their transitive local-path dependencies must be validated from a consumer checkout.
- Jezaku must implement backend authorization and durable audit in its own service architecture.
- Marketplace execution requires additional architecture beyond the existing Flutter plugin runtime.

## Adoption sequence

1. Publish this boundary in both repositories.
2. Harden and test Alhambra identity authorization independently; do not couple that work to Jezaku's backend authorization.
3. Validate Alhambra package dependency resolution, supported SDKs, and consumer build from Jezaku.
4. Integrate only the minimum required Alhambra UI packages into `UI/jezaku_admin`, pinned to an immutable revision.
5. Keep the admin shell functional and safe when optional Alhambra capabilities are unavailable.
6. Design marketplace package execution/isolation as a separate ADR before enabling third-party executable extensions.

## Acceptance criteria before production integration

- Consumer dependency resolves reproducibly from a clean checkout.
- Flutter analyze, tests, and supported build targets pass in both repositories.
- No client-side permission check is treated as authorization.
- Backend tests prove deny-by-default, scope isolation, approval requirements, and audit behavior for privileged operations.
- No untrusted downloaded code executes in the Jezaku or Alhambra host process.
- Upgrade and rollback procedures identify the exact Alhambra revision.

## Rejected alternatives

- **Copy Alhambra packages into Jezaku:** duplicates ownership and makes upstream fixes harder to consume.
- **Merge the repositories:** couples a reusable foundation to Jezaku's domain and release cycle.
- **Use Alhambra's Flutter authorization service as Jezaku's backend authority:** client/runtime boundary and current security/persistence gaps make this inappropriate.
- **Treat plugin signatures as sandboxing:** integrity and publisher authenticity do not constrain what executable code can do.
