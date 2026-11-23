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
9. Frame visibility is a product rule: a frame is seen only by people it is shared with (public, friends, own) and only within a physical radius of where they stand. The backend is authoritative for who may see what; the client enforces the same rule and the radius through one policy. See [UI/docs/frame-visibility-and-roadmap.md](UI/docs/frame-visibility-and-roadmap.md).
    The owner sees their own frames anywhere (gallery); other people, friends included, see and interact with a frame only on site inside the radius. No remote browsing of someone else's frame. Builds run `demo` rules (everyone is a friend, no radius) or `strict` rules (the real ones) via `--dart-define=JEZAKU_FRAME_RULES`; production must be `strict`.
10. Update documentation in the same change when architecture, public contracts, setup, operational behavior, or developer workflows change.

## Before finishing

- Summarize changed paths and the reason for each.
- Report commands run and their actual outcomes.
- Call out unrun checks, hardware requirements, assumptions, and follow-up work.
