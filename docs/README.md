# Jezaku Documentation Index

This directory contains product direction, target architecture, implementation guidance, and existing technical documentation.

## Spatial platform direction
- [Product vision](vision.md)
- [Platform roadmap](roadmap.md)
- [Platform architecture](platform-architecture.md)
- [Spatial Core specification](spatial-core.md)
- [Extension architecture](extension-architecture.md)
- [Commerce domain architecture](commerce-architecture.md) — merchant/store ownership, authoritative placement, offers, discovery projection and redemption boundaries.
- [API standards](api-standards.md)
- [Security and safety](security-and-safety.md)
- [Implementation plan](implementation-plan.md)
- [Repository capability inventory](repository-capability-inventory.md) — source-backed current-state matrix, integration gaps, and recommended implementation sequence.
- [Spatial safety integration plan](spatial-safety-integration-plan.md) — existing safety foundations, feature enforcement matrix, phased integration tickets, and release gates.
- [Navigation safety contract](navigation-safety-contract.md) — provider-neutral route geometry, segment-level safety, alternatives, live invalidation, and implementation gates.
- [ADR-0002: Navigation and routing ownership](decisions/ADR-0002-navigation-and-routing-ownership.md) — routing-provider ownership, authoritative safety evaluation, and presentation boundaries.
- [Admin console architecture](admin-console-architecture.md) — operator personas, service ownership, authorization, audit, security and console boundaries.
- [Admin console implementation plan](admin-console-implementation-plan.md) — phased delivery from secure shell to access, safety, commerce, extensions and operations.\n- [Admin identity, access and audit contract](admin-identity-and-access.md) — RBAC, scoped grants, approvals, persistence, endpoint and audit contracts.\n- [ADR-0003: Admin authorization and audit ownership](decisions/ADR-0003-admin-authorization-and-audit.md) — preserves JWT identity semantics and domain-service authorization ownership.
- [Alhambra platform integration](alhambra-platform-integration.md) — shared Flutter foundation, product boundaries, security constraints and staged adoption.
- [ADR-0004: Alhambra as the shared platform foundation](decisions/ADR-0004-alhambra-platform-foundation.md) — repository ownership, immutable dependency policy and backend authority.
- [Architecture decisions](decisions/)

## Existing technical documentation
- [Detailed architecture](architecture.md) — earlier low-level AR/photo architecture; consult with current source and newer platform guidance.
- [Cross-cutting agent guidance](AGENTS.md) — product principles, safety/governance, repository alignment, and documentation rules.

## Status convention
Strategic and target architecture documents do not imply implementation. Source code, tests, OpenAPI contracts, migrations, and scoped agent instructions remain authoritative for current behavior.
