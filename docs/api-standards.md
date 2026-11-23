# Jezaku API and Contract Standards

> Proposed standards for new/evolved APIs. Existing public contracts remain authoritative until explicitly migrated.

## Principles
Domain contracts are transport-independent; changes are additive where possible; validate typed schemas at boundaries; enforce authorization/visibility/tenant/moderation/safety server-side; bound queries and payloads; make mutations auditable and retry-safe; do not expose persistence entities.

## HTTP conventions
Use existing repository path, response-envelope, authentication, and error conventions. Use resource-oriented plural paths, stable opaque IDs, standard methods/status codes, UTC RFC 3339 timestamps, WGS84 with explicit latitude/longitude and altitude datum, and SI units with unambiguous field names.

Illustrative paths only (inspect existing OpenAPI before adopting):
- POST /api/v1/spatial/objects
- GET/PATCH/DELETE /api/v1/spatial/objects/{objectId}
- POST /api/v1/spatial/scenes
- GET /api/v1/spatial/scenes/{sceneId}
- GET /api/v1/spatial/discovery
- POST /api/v1/navigation/targets

## Validation
Validate identifiers/tenant scope, enums/schema versions, coordinate ranges/units/datum/timestamps, pagination/radius/area limits, payload/asset sizes, placement/device capabilities, ownership/state preconditions, and permission/consent. Reject unsupported critical schema versions.

## Authorization and privacy
Every read/write/feed/search/batch path evaluates principal, owner, tenant, grants, visibility, moderation, and context. Public visibility is not authorization. Preserve existing frame sharing and on-site radius rules. Do not expose private coordinates, precise user location, camera metadata, private social data, or signed asset URLs in logs/analytics.

## Errors
Use existing error envelope and stable machine-readable codes. Provide safe actionable messages and correlation/request ID where supported. Never expose stack traces, secrets, topology, or sensitive policy inputs.

## Spatial queries
Require bounded result limits and maximum radius/area. Prefer cursor pagination for changing datasets. Validate bounds, apply authorization and safety before returning candidates, and define location accuracy/freshness semantics. Client location/heading is not trusted proof.

## Idempotency and concurrency
Define idempotency for retryable mutations and retention. Use versions/ETags or existing concurrency mechanisms. Duplicate event delivery must be safe.

## Events
Events require stable name/schema version, unique ID, timestamp, correlation/causation IDs, producer/consumer ownership, retry/dead-letter behavior, and idempotent consumers. Do not promise exactly-once delivery unless guaranteed by infrastructure.

## Compatibility
Do not change field meaning or units in place. Version breaking schema/event changes. Publish migration/deprecation windows and compatibility tests. Record decisions in ADRs.

## OpenAPI and testing
Update owning module OpenAPI and docs for changed HTTP APIs. Add positive, negative, authorization, privacy, validation, pagination, and idempotency tests. Coordinate changes with Flutter and SDK consumers.
