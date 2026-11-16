# Backend API and Integration Conventions

## 1. HTTP resource design

- Use resource classes as transport adapters; keep domain decisions in application services.
- Use nouns for resource paths and HTTP methods for intent.
- Keep path/query/body responsibilities consistent and document required parameters.
- Return appropriate status codes: 200 for successful reads/updates with a body, 201 for creation, 202 for accepted asynchronous work, 204 for successful no-content operations, and 4xx/5xx for failures.
- Bound collection responses with pagination and maximum page sizes.

## 2. DTOs and validation

- Use explicit request and response DTOs rather than exposing persistence entities.
- Validate required values, length/range constraints, enum values, UUIDs, timestamps, coordinate ranges, and payload sizes at the API boundary.
- Define coordinate order, reference system, altitude datum/units, distance units, and heading convention explicitly.
- Reject malformed values with a stable client error; do not silently coerce unsafe or ambiguous inputs.
- Avoid returning fields the caller does not need or is not authorized to see.

## 3. Errors

- Use the shared error response infrastructure in `common` where applicable.
- Keep error codes stable and messages safe for clients.
- Include request/correlation IDs when available.
- Do not expose stack traces, SQL errors, internal hostnames, tokens, or secret configuration.
- Distinguish validation, authentication, authorization, not-found, conflict, rate-limit, and transient dependency failures.

## 4. Authentication and authorization

- Authentication establishes caller identity; each owning service must enforce operation-level authorization.
- Never trust client-provided owner IDs, audience scopes, guardian state, block state, or moderation state without server-side verification.
- Apply the same visibility decision to direct endpoints, feeds, search, batch reads, minimaps, and derived projections.
- Test denied access and cross-user access explicitly.
- Use least privilege for service-to-service credentials.

## 5. Pagination and filtering

- Prefer stable cursor pagination for mutable/high-volume feeds and timelines.
- Define default and maximum limits; reject or clamp invalid values consistently.
- Document sort order and cursor semantics.
- Apply visibility filtering before returning page results and avoid leaking hidden counts or identifiers unless explicitly intended.
- Keep batch endpoints bounded and validate every item.

## 6. Location and spatial contracts

- Document coordinate reference system (normally WGS84/EPSG:4326 for geographic coordinates), coordinate order, altitude semantics, and units.
- Validate latitude/longitude ranges and reject non-finite values.
- Use spatial indexes and bounded radius/area constraints for nearby queries.
- Treat precision as a privacy-sensitive output decision, not merely a database concern.
- Distinguish unavailable, approximate, stale, and high-confidence location data.
- Do not infer altitude or heading when the source did not provide it.

## 7. Media and upload contracts

- Validate content type, size, ownership, and upload completion before making media available.
- Use short-lived signed upload/download URLs and avoid logging them.
- Treat client metadata as untrusted; verify server-side where possible.
- Separate upload accepted, processing, moderation, and published states.
- Ensure retries and completion callbacks are idempotent.

## 8. Events and cross-service integration

For each event, document producer, consumer, schema version, delivery semantics, retry policy, and privacy classification. Consumers must tolerate duplicate delivery. Use an outbox or equivalent when state changes and event publication must remain consistent.

Cross-service integration must use explicit API/client or event contracts. Do not import another module's internal implementation or use its database as an undocumented integration surface.

## 9. API documentation and compatibility

- Keep OpenAPI metadata, module README, and service catalog up to date.
- Document request/response examples without real personal data or secrets.
- Prefer additive fields and endpoints.
- Deprecate before removing fields where feasible.
- Coordinate breaking changes with UI consumers and update client adapters/tests in the same delivery plan.

## 10. Test expectations

For an API change, cover:
- successful request and response shape;
- required/invalid input;
- authentication and authorization;
- privacy/visibility and blocked-user paths;
- pagination boundaries;
- dependency failure and error mapping;
- duplicate/retry behavior for writes and asynchronous processing.
