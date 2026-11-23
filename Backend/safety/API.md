# Spatial Safety API

Base path: `/safety/spatial`

This API manages circular, time-bounded spatial restrictions and evaluates whether an operation is permitted at a coordinate. It is part of the existing Safety service; it does not create a separate service.

## Authentication and authority provisioning

All mutation and audit-history operations require an authenticated user or service token. The caller identity is read from the verified request context and resolved to a previously provisioned `AuthorityPrincipal`. The API never accepts `issuerId`, `issuerType`, permissions, status, or jurisdiction grants from a client payload.

Authority onboarding, verification, suspension, and grant management are deliberately administrative operations and are not exposed by these endpoints. They must be performed by a trusted provisioning workflow using `SpatialPolicyRepository.saveAuthority`.

A registered authority must be `VERIFIED`, inside its validity window, hold the required permission, and cover the requested jurisdiction. Emergency lockdown requires `ISSUE_EMERGENCY_LOCKDOWN` independently of ordinary create/update permission.

The evaluation endpoints are service-to-service only and require the `spatial:policy-evaluate` service-token scope. The policy change feed is separately restricted to `spatial:policy-changes-read`. These endpoints are not unauthenticated public policy oracles. Consuming services must use their own least-privilege service token and must fail closed if evaluation cannot be completed.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/restrictions` | Create a restriction (201) |
| GET | `/restrictions/{restrictionId}` | Read a restriction |
| PUT | `/restrictions/{restrictionId}` | Update using `expectedVersion` |
| POST | `/restrictions/{restrictionId}/revoke` | Revoke with expected version and reason |
| GET | `/restrictions/{restrictionId}/history` | Read audit history (issuing authority only) |
| POST | `/evaluate` | Evaluate one coordinate and activity against current active rules |
| POST | `/evaluate/batch` | Evaluate 1–500 ordered point candidates against one immutable policy snapshot (service scope required) |
| POST | `/evaluate/routes` | Evaluate up to 5 route alternatives against one immutable policy snapshot (`spatial:policy-evaluate` required) |
| GET | `/changes?afterRevision={revision}&limit={n}` | Read ordered policy invalidation events after a consumer's last revision (`spatial:policy-changes-read` required) |

## Create/update payload

```json
{
  "jurisdiction": "ID.32.73",
  "legalBasis": "Applicable authority order reference",
  "centerLatitude": -6.9,
  "centerLongitude": 107.6,
  "radiusMeters": 250,
  "outcome": "PROHIBITED",
  "activities": ["NAVIGATE", "RENDER"],
  "effectiveFrom": "2026-11-23T12:00:00Z",
  "expiresAt": "2026-11-23T18:00:00Z"
}
```

Update additionally requires `expectedVersion`. Revocation requires `expectedVersion` and a non-empty `reason`. The server assigns restriction IDs, issuer identity, issuer type, and the next version.

Coordinates are WGS84 decimal degrees. Radius must be greater than zero and no more than 100 km. Expiry, when supplied, must be later than the effective start. `ALL` may be used as the only activity value; otherwise supply concrete activities.

## Evaluation payload

```json
{
  "latitude": -6.9,
  "longitude": 107.6,
  "activity": "NAVIGATE"
}
```

Evaluation time is assigned by the server. Results include the strongest matching outcome, matching restriction IDs, a reason code, and the earliest matching expiry. `ALLOWED` and `CAUTION` are non-blocking decisions; consumers must still present caution messaging where appropriate.

## Batch evaluation payload

```json
{
  "requests": [
    { "latitude": -6.9, "longitude": 107.6, "activity": "DISCOVER" },
    { "latitude": -6.901, "longitude": 107.601, "activity": "DISCOVER" }
  ]
}
```

The response contains one result per input, in the same order, and one shared `evaluatedAt` timestamp. The server captures active restrictions once for the entire batch. Empty batches, invalid coordinates/activities, and batches over 500 are rejected; consumers must not truncate candidate lists to fit the limit. Batch evaluation is intended for server-side candidate filtering, not public client use.

## Route alternative evaluation

`POST /evaluate/routes` accepts provider-generated candidate polylines. The server always evaluates them as `NAVIGATE`; callers cannot choose a weaker activity. Every route is validated as WGS84 geometry before policy is read. All alternatives share one captured policy snapshot and the response preserves input order.

Request limits: at most 5 candidates, 2,000 vertices per candidate, 5,000 vertices total, 500 km total route length, 100 km per segment, and a caller-supplied corridor buffer from 0 to 500 m. Omitted buffer defaults to zero. Duplicate/blank route IDs, missing coordinates, degenerate segments, out-of-range coordinates, and over-limit requests are rejected; no candidate is silently truncated.

Each result contains the caller's route ID, strongest outcome, matching restriction IDs, reason code, affected zero-based segment indices, and whether the route is non-blocking. `CAUTION` is non-blocking only when the consuming product surfaces the caution UX and any required confirmation. Blocking alternatives remain in the response with `permitsOperation=false` so the routing orchestrator can select another candidate.

The response includes an opaque per-request policy snapshot ID, shared evaluation timestamp, a validity deadline capped at 15 seconds and shortened by an earlier matching restriction expiry, and a monotonic `policyRevision`. The revision advances once for every successfully committed restriction create, update, or revoke; the restriction mutation, audit event, and revision increment commit or roll back together. Snapshot capture reads the revision, active restrictions, and activity rows in one PostgreSQL statement snapshot.

`policySnapshotId` identifies this individual assessment request. `policyRevision` identifies the durable restriction-policy generation and can be compared across assessments; it is not an authorization token or a replacement for the validity deadline. Time-based activation/expiry can change the active set without a mutation, so consumers must still honor `validUntil`. Authority-grant changes are not currently included in this restriction-policy revision.

This is a short-lived assessment, not a lock or durable authorization: policy changes can occur immediately after evaluation. Re-evaluate before starting guidance and on route change, meaningful deviation, expiry, app resume, or policy invalidation. The durable change feed is available through `GET /changes`; push invalidation delivery and automatic live-session re-evaluation are not yet implemented. If the endpoint is unavailable or the response is incomplete, do not guide on any candidate.

## Policy change feed

Consuming services with the `spatial:policy-changes-read` scope call `GET /changes?afterRevision={lastProcessedRevision}&limit=100`. The response includes the current high-water revision and ordered versioned events (`eventType=spatial.policy.changed`, `eventVersion=1`) with a strictly increasing policy revision, restriction identifier/version, mutation action, jurisdiction, outcome, affected activities, and occurrence time. The event contains no coordinates or legal-basis text; consumers should treat it as an invalidation signal and re-evaluate their own active routes/operations rather than reconstructing policy from event payloads.

Advance the consumer cursor only after successfully processing each event. When a page is full, request again using the last returned event revision; do not jump directly to `currentRevision` until every intervening event has been processed. If the consumer detects a revision gap, loses its cursor, or cannot safely process an event, it must discard cached route authorization and obtain a fresh route assessment/policy snapshot. The feed is durable and ordered but currently retained indefinitely; operational retention/compaction requires a future cursor-aware design. The endpoint is polling-based: push delivery and a live navigation consumer are not implemented by this change.

Example:

```json
{
  "corridorBufferMeters": 20,
  "routes": [
    {
      "routeId": "provider-route-a",
      "points": [
        { "latitude": -6.9, "longitude": 107.59 },
        { "latitude": -6.901, "longitude": 107.60 },
        { "latitude": -6.9, "longitude": 107.61 }
      ]
    },
    {
      "routeId": "provider-route-b",
      "points": [
        { "latitude": -6.9, "longitude": 107.59 },
        { "latitude": -6.899, "longitude": 107.60 },
        { "latitude": -6.9, "longitude": 107.61 }
      ]
    }
  ]
}
```

## Error behavior

- 400: malformed or invalid coordinates, activity, timestamps, or payload
- 401: no authenticated authority caller for a mutation
- 403: caller has no registered grant, is not verified, lacks permission/scope, or does not own the restriction
- 404: restriction does not exist
- 409: optimistic version conflict or already-revoked restriction

## Current scope and safety boundary

The first API release supports circular geofences only. A service-authenticated route-alternative evaluation endpoint now exposes the bounded spherical segment intersection primitive for circular restrictions. Route generation, selection/orchestration, and live navigation-session integration remain outside Safety. Polygon/multipolygon geometry, PostGIS indexes, bulk import, jurisdiction administration endpoints, and emergency revocation workflows remain later phases. Discovery nearby/search/trending/for-you paths now call batch evaluation before returning candidates; memory publishing continues to use the existing single-coordinate evaluation path. Memory presentation/render-time enforcement remains a separate integration step. A successful evaluation endpoint call alone does not guarantee every downstream operation is protected; consuming services must integrate the policy decision before enabling the corresponding action.
