# Spatial Safety API

Base path: `/safety/spatial`

This API manages circular, time-bounded spatial restrictions and evaluates whether an operation is permitted at a coordinate. It is part of the existing Safety service; it does not create a separate service.

## Authentication and authority provisioning

All mutation and audit-history operations require an authenticated user or service token. The caller identity is read from the verified request context and resolved to a previously provisioned `AuthorityPrincipal`. The API never accepts `issuerId`, `issuerType`, permissions, status, or jurisdiction grants from a client payload.

Authority onboarding, verification, suspension, and grant management are deliberately administrative operations and are not exposed by these endpoints. They must be performed by a trusted provisioning workflow using `SpatialPolicyRepository.saveAuthority`.

A registered authority must be `VERIFIED`, inside its validity window, hold the required permission, and cover the requested jurisdiction. Emergency lockdown requires `ISSUE_EMERGENCY_LOCKDOWN` independently of ordinary create/update permission.

The evaluation endpoint is service-to-service only and requires the `spatial:policy-evaluate` service-token scope. It is not an unauthenticated public policy oracle. Consuming services must use their own service token and must fail closed if evaluation cannot be completed.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/restrictions` | Create a restriction (201) |
| GET | `/restrictions/{restrictionId}` | Read a restriction |
| PUT | `/restrictions/{restrictionId}` | Update using `expectedVersion` |
| POST | `/restrictions/{restrictionId}/revoke` | Revoke with expected version and reason |
| GET | `/restrictions/{restrictionId}/history` | Read audit history (issuing authority only) |
| POST | `/evaluate` | Evaluate one coordinate and activity against current active rules |
| POST | `/evaluate/batch` | Evaluate 1–500 ordered candidates against one immutable policy snapshot (service scope required) |

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

## Error behavior

- 400: malformed or invalid coordinates, activity, timestamps, or payload
- 401: no authenticated authority caller for a mutation
- 403: caller has no registered grant, is not verified, lacks permission/scope, or does not own the restriction
- 404: restriction does not exist
- 409: optimistic version conflict or already-revoked restriction

## Current scope and safety boundary

The first API release supports circular geofences only. Polygon/multipolygon geometry, PostGIS indexes, bulk import, jurisdiction administration endpoints, and emergency revocation workflows remain later phases. Discovery nearby/search/trending/for-you paths now call batch evaluation before returning candidates; memory publishing continues to use the existing single-coordinate evaluation path. Memory presentation/render-time enforcement remains a separate integration step. A successful evaluation endpoint call alone does not guarantee every downstream operation is protected; consuming services must integrate the policy decision before enabling the corresponding action.
