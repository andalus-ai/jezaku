# Jezaku Backend Architecture

## 1. Purpose

The backend provides the APIs and domain services for Jezaku's spatial-social camera experience. It is a Maven multi-module Quarkus project. Each runnable module is independently owned and can be developed/tested separately; `common` is a shared library module.

The parent aggregator is `Backend/pom.xml`. Its module list is the authoritative inventory of Maven modules.

## 2. Module topology

Runnable service modules currently include:

`identity`, `profile`, `social`, `engagement`, `discovery`, `journeys`, `messaging`, `rewards`, `camera`, `memory`, `media`, `presence`, `safety`, `commerce`, `spatial-trails-places`, `events`, and `notifications`.

Shared library:
- `common`: shared HTTP/request context, API error handling, health wiring, and reusable geospatial/AR confidence utilities.

Service names and ports are maintained in [service-catalog.md](service-catalog.md) and [service-ports.md](../service-ports.md).

## 3. Service ownership

- **identity** — account lifecycle, authentication/session concepts, guardian links, trusted devices.
- **profile** — user-facing profile data, privacy settings, and parental controls.
- **social** — friend/family/group/community graph, blocks, relationship context, audience decisions, social content and feed capabilities.
- **engagement** — reactions, comments, bookmarks, and engagement summaries where separated from social content ownership.
- **discovery** — ranked nearby discovery, spatial search, and feedback signals.
- **journeys** — guided AR journeys, checkpoint progress, and journey rewards integration.
- **messaging** — direct/group/contextual conversations.
- **rewards** — XP events, badges, streaks, reward profiles, leaderboards.
- **camera** — camera HUD context, live camera sessions, safety-zone context, and minimap overlays.
- **memory** — camera memory capture, nearby memories, feeds, and minimap dots.
- **media** — upload slots, media inventory, and moderation state.
- **presence** — live location check-ins, altitude/compass context, and nearby user projections.
- **safety** — reports, moderation review, guardian safety zones, and spatial restriction policy enforcement.
- **commerce** — merchant verification, stores/branches, authoritative store placement, campaigns, promotions, eligibility, and redemption. Commerce owns commercial truth; Discovery consumes bounded projections and Safety remains authoritative for spatial restrictions.
- **spatial-trails-places** — AR anchors, trails, and place discovery.
- **events** — nearby events, RSVP, check-ins, and invitations.
- **notifications** — notification inbox/preferences and device registration.

These are ownership boundaries, not a requirement that every service call every other service. Keep domain authority in one owning service and expose explicit contracts to consumers.

## 4. Dependency direction

Preferred dependency direction:

```text
UI client / external clients
          |
       HTTP APIs
          |
  owning service module
   |       |        |
 domain  application adapters
                    |
            repository / clients
                    |
          persistence / external systems

shared technical concerns -> common
```

Rules:
- Services must not import another service's internal domain or persistence classes.
- Shared DTOs/utilities belong in `common` only when they are genuinely cross-cutting and stable.
- Avoid putting business policy in `common`; the owning service remains authoritative.
- Cross-service calls use explicit HTTP/client or event contracts, not shared database tables as an integration API.
- Prevent cyclic module dependencies.

## 5. Request processing

A typical synchronous request should follow:

1. Quarkus REST resource receives the request.
2. Boundary validation checks syntax, ranges, required fields, and caller context.
3. Application/domain service executes the use case and authorization/visibility decisions.
4. Repository or external adapter performs persistence/integration.
5. Resource maps the result to a stable response DTO and HTTP status.
6. Shared request/error infrastructure adds correlation and consistent error representation.

Keep resources thin. Avoid persistence queries and policy-heavy logic directly inside resource methods.

## 6. Shared platform module

The `common` module is a technical foundation, not a general-purpose dumping ground. It currently supports shared request ID propagation, JSON API error responses, liveness health wiring, geospatial validation/math (distance, bearing, altitude delta, camera-oriented minimap offsets), and AR anchor confidence scoring.

Promote code into `common` only when:
- at least two modules need the same behavior;
- semantics are stable and not owned by a product domain;
- reuse reduces drift without creating hidden coupling;
- the public surface can be tested and documented.

## 7. Data and persistence principles

- Each service owns the schema/tables and lifecycle of its domain data.
- Use explicit migrations and document schema compatibility.
- Validate and normalize spatial inputs; define coordinate reference system and units explicitly.
- Keep spatial indexes and bounded queries aligned with actual access patterns.
- Avoid cross-service database joins as a substitute for APIs.
- Use pagination and hard limits for collection endpoints.
- Make data retention, deletion, and export behavior explicit for user content and sensitive location data.
- Do not return internal persistence entities directly from REST endpoints.

## 8. Events and asynchronous work

Use asynchronous events for decoupled side effects such as notifications, media processing, feed/activity projections, and analytics where applicable.

For every event contract document:
- event name and owning producer;
- schema/version and required fields;
- consumer responsibilities;
- retry and duplicate-delivery behavior;
- ordering assumptions;
- privacy classification and retention.

Assume at-least-once delivery unless the infrastructure explicitly guarantees otherwise. Consumers should be idempotent. Use an outbox or equivalent reliable publication pattern when a database state change must not be separated from its event.

## 9. Security, privacy, and trust boundaries

- Authenticate callers at the edge and authorize each operation in the owning service.
- Treat location, identity, guardian/family relationships, private messages, social graph, and media metadata as sensitive.
- Enforce block, audience, privacy, guardian, and moderation rules server-side for direct reads, search, feeds, batch endpoints, minimaps, and derived projections.
- Avoid returning exact coordinates unless the caller and use case are authorized.
- Minimize logs and telemetry; redact tokens, signed URLs, message content, and precise location.
- Validate upload metadata and media ownership; do not trust client-provided visibility or moderation state.
- Apply rate limits and abuse controls to high-risk endpoints.

## 10. API evolution and service integration

- Keep public endpoint contracts additive where possible.
- Use explicit DTOs, stable error codes, and documented status codes.
- Document authentication, authorization, pagination, filtering, and visibility behavior.
- Coordinate changes with UI and other service consumers before removing or changing fields.
- Prefer versioned or staged migrations for breaking changes.
- Maintain OpenAPI descriptions and module READMEs for externally consumed endpoints.

See [API conventions](api-conventions.md).

## 11. Observability and operations

- Propagate request/correlation IDs across service boundaries.
- Emit structured logs with safe identifiers; never log secrets or sensitive payloads.
- Expose health/readiness semantics consistently.
- Track latency, error rates, saturation, queue lag, and dependency failures.
- Keep service ports and local Swagger/OpenAPI URLs synchronized with configuration.
- Make local development reproducible and avoid environment-specific assumptions in code.

## 12. Build and test

Run from `Backend/`:

```bash
./mvnw -B verify
```

For a single module and its required dependencies:

```bash
./mvnw -pl <module> -am test
```

Add tests at the appropriate layer: domain/unit, resource/API, persistence, and cross-service contract. Include authorization-denied and privacy-boundary tests.

## 13. Change checklist

Before merging a backend change, verify:
- service ownership and dependency direction remain clear;
- API inputs/outputs and error cases are documented;
- authorization and visibility are enforced server-side;
- schema/event compatibility and idempotency are considered;
- tests cover success and failure/privacy cases;
- configuration and ports are documented;
- UI and downstream consumers are informed of contract changes.
