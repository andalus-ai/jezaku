# Backend Agent Instructions

These instructions apply to everything under `Backend/`. Read this file before changing backend code.

## Scope and architecture

- Backend is a Maven multi-module project using Quarkus and Java.
- `Backend/pom.xml` is the aggregator and lists the runnable service modules plus the shared `common` library.
- `common` contains shared infrastructure and cross-service utilities; it is not a runnable service.
- Each service owns its API, application/domain logic, persistence adapters, configuration, and tests. See `Backend/docs/architecture.md` and `Backend/docs/service-catalog.md`.
- Do not introduce a new service or shared abstraction until its ownership and deployment need are clear.

## Required engineering practices

1. Inspect the target module's `pom.xml`, source tree, README, configuration, and tests before editing.
2. Follow the Quarkus and Java versions/dependency management already established by the project. Do not independently upgrade framework versions.
3. Keep service boundaries explicit. A service must not reach into another service's persistence layer or internal classes.
4. Put truly cross-cutting HTTP, error, request-context, health, and shared geospatial primitives in `common`; keep product/domain rules in their owning service.
5. Use typed request/response DTOs and validate external input at the boundary.
6. Keep resource classes thin. Put business decisions in application/domain services and persistence behind repository interfaces/adapters.
7. Make authorization and visibility enforcement server-side. Never trust client-side filtering for privacy, family, block, audience, or moderation decisions.
8. Treat location, camera, identity, family/guardian, and social graph data as sensitive. Minimize collection, retention, logging, and response fields.
9. Make retries safe: use idempotency where appropriate, transactional boundaries for state changes, and explicit handling for duplicate events.
10. Keep API errors consistent and avoid leaking stack traces, secrets, internal topology, or personal data.
11. Keep configuration externalized. Never commit credentials, private keys, production tokens, or real user data.
12. Update service README, OpenAPI/API contract docs, ports, and architecture docs when public behavior or operational configuration changes.

## API and service contracts

- Preserve existing endpoint conventions and response envelopes unless a deliberate migration is approved.
- Validate identifiers, pagination bounds, enums, coordinates, timestamps, and payload sizes.
- Use stable error codes and actionable messages; include request/correlation IDs where available.
- Document authentication, authorization, visibility rules, pagination, filtering, and error behavior.
- Do not expose internal entity models directly as public API contracts.
- Coordinate cross-service contract changes with UI and other consuming services; prefer additive evolution and explicit deprecation.

## Security and privacy

- Enforce authorization on every read/write path, including batch endpoints, feeds, minimaps, search, and derived projections.
- Apply block, audience, guardian, moderation, and visibility constraints consistently across all representations.
- Do not log access tokens, passwords, signed URLs, precise coordinates, private message bodies, or sensitive profile data.
- Use parameterized persistence operations and validate untrusted input.
- Keep secrets in environment/secret-manager configuration; use placeholders in examples.
- Consider abuse controls, rate limits, data retention, deletion, and auditability for user-generated content and location data.

## Persistence and events

- Keep persistence implementation details behind repository boundaries.
- Make transaction scope explicit for multi-record state transitions.
- Design event handlers for duplicate delivery and retry; document event names, payload versions, and ownership.
- Do not assume synchronous delivery or exactly-once semantics unless the infrastructure guarantees them.
- Keep schema changes backward-compatible during rolling deployments and document migration/rollback expectations.

## Testing and validation

Run from `Backend/`:

```bash
./mvnw -B verify
```

For a focused module:

```bash
./mvnw -pl <module> -am test
```

- Add unit tests for domain rules and validation.
- Add resource/API tests for status codes, payload validation, authorization, visibility, and error envelopes.
- Add repository tests for query semantics and persistence behavior.
- Add cross-service/contract tests when a change affects shared DTOs, events, or service integration.
- Test negative and privacy-sensitive paths, not only successful requests.
- Do not claim checks passed unless they were run. If the environment lacks dependencies or infrastructure, report the limitation and exact command.

## Change discipline

- Keep changes focused; avoid unrelated module rewrites.
- Preserve module naming, Maven dependency management, and established package conventions.
- Do not add a dependency to every module when only one module needs it.
- Avoid cyclic service dependencies and cross-module internal imports.
- Update docs and tests in the same change as contract or behavior changes.
