# Jezaku Repository Agent Instructions

These instructions apply repository-wide. Read the nearest scoped `AGENTS.md` before changing a subsystem; more specific instructions add to these rules.

## Repository map

- `UI/`: Flutter client, main app, and reusable Dart packages. Read [UI/AGENTS.md](UI/AGENTS.md).
- `Backend/`: Maven multi-module Quarkus backend. Read [Backend/AGENTS.md](Backend/AGENTS.md).
- `docs/`: product-level architecture, plans, decisions, and cross-cutting documentation.

## Working rules

1. Inspect the existing implementation, tests, configuration, and documentation before proposing or making structural changes.
2. Treat checked-in manifests, source code, OpenAPI contracts, and tests as authoritative. Documentation must describe current behavior and clearly label proposals or future work.
3. Keep changes scoped to the owning app, package, or backend service. Avoid cross-module internal dependencies and duplicate abstractions.
4. Preserve public API compatibility unless a migration is explicitly intended; coordinate UI/backend contract changes and update both sides.
5. Treat identity, location, camera media, private social content, and guardian/family data as sensitive. Minimize exposure in APIs, logs, analytics, fixtures, and examples.
6. Add or update tests with behavior changes. Run the narrowest relevant checks, then broader checks when practical.
7. Never claim a command, test, build, device check, or deployment succeeded unless it was actually executed successfully.
8. Do not commit credentials, production data, local secrets, generated build output, or machine-specific configuration.
9. Update documentation in the same change when architecture, public contracts, setup, operational behavior, or developer workflows change.

## Before finishing

- Summarize changed paths and the reason for each.
- Report commands run and their actual outcomes.
- Call out unrun checks, hardware requirements, assumptions, and follow-up work.
