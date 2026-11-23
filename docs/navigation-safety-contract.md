# Navigation Safety Contract

> **Status:** Proposed implementation contract. This document does not claim route authorization or live navigation safety is implemented.

## 1. Current repository boundary

The current repository has three relevant capabilities:

- `safety` owns authoritative spatial restrictions and evaluates points for an activity against an immutable, request-scoped policy snapshot.
- `spatial-trails-places` owns spatial anchors, places, and completed trail history. Its current trail records are completed stop identifiers and timestamps, not route geometry.
- `journeys` owns guided journey definitions, ordered checkpoints, session progress, and checkpoint completion. Its current journey response has checkpoint positions, but no provider-generated route geometry, route alternatives, or navigation session.

The existing `POST /safety/spatial/evaluate/batch` endpoint evaluates up to 500 points against one policy snapshot. This is useful for candidate checks, but point batches alone do not prove that a continuous route is safe. Checking only route endpoints or journey checkpoints is insufficient.

No navigation route provider or authoritative road/path graph should be invented inside Jezaku. Route geometry must come from the configured routing provider (for example, the Idrisi routing stack or an explicitly selected external provider); Jezaku applies its own authorization and safety policy to that geometry.

## 2. Ownership decisions

| Concern | Owner |
|---|---|
| Route generation, graph data, road/path topology, turn-by-turn base geometry | Idrisi or configured routing provider |
| Route request orchestration, user journey context, route lifecycle and client delivery | Jezaku navigation experience, initially coordinated through existing journey/spatial boundaries |
| Legal/authority spatial restrictions and policy evaluation | Existing `safety` module |
| AR arrow, map line, voice prompt, accessible text and compass presentation | Flutter experience / existing AR runtime |
| Location and heading quality | Existing device/presence abstractions |

Do not add a second routing engine, safety database, geofence store, or AR navigation renderer.

## 3. Route contract

A route supplied for safety evaluation is an immutable candidate with:

- `routeId` and `providerId` (opaque identifiers, not trusted authorization claims).
- `geometryVersion` and `coordinateReferenceSystem`; the initial supported CRS is WGS84 longitude/latitude (EPSG:4326).
- Ordered geometry vertices, each with finite latitude and longitude; altitude is optional and never silently interpreted as floor/road elevation.
- Optional provider segment identifiers and maneuver metadata, kept separate from safety decisions.
- A bounded geometry size and explicit route distance.
- A route evaluation activity, normally `NAVIGATE`; route publication/advertising must not reuse navigation authorization.

The server must reject empty geometry, invalid coordinates, duplicate-only geometry, unsupported CRS, non-finite values, implausible distance, and payloads beyond configured limits. A route provider response is untrusted input and must be validated before evaluation.

The response is a safety assessment, not a guarantee that a route is physically safe or currently passable:

- `PERMITTED`: no blocking policy intersection was found in the evaluated geometry.
- `CAUTION`: one or more caution areas intersect the route; return bounded reason codes and affected segment ranges, not sensitive restriction details.
- `BLOCKED`: a blocking restriction intersects the route; do not return renderable guidance for that candidate.
- `UNAVAILABLE`: authoritative evaluation could not be completed; never downgrade this to permitted.

The public response must not disclose authority-only legal basis, private reporter information, or sensitive restriction metadata.

## 4. Geometry evaluation requirements

### 4.1 Evaluate the path, not just vertices

The authoritative Safety service must evaluate every polyline segment against applicable restrictions using one immutable policy snapshot and one evaluation timestamp. The first implementation should use a geodesic-aware point-to-segment / segment-to-circle intersection calculation (or a rigorously bounded local projection), not a naïve longitude/latitude Euclidean distance.

A vertex-only check is prohibited. Fixed-interval sampling may be used as an additional conservative check, but it is not sufficient as the sole correctness mechanism because a small restricted area can lie between samples.

For a polyline with vertices (p_0 ldots p_n), evaluate every segment ([p_i,p_{i+1}]). A restriction circle intersects a segment when the minimum geodesic distance from its center to that segment is less than or equal to its radius plus the configured safety buffer. Handle antimeridian crossing and high latitudes explicitly. If the geometry algorithm cannot establish a reliable result, return unavailable.

### 4.2 Safety corridor and location uncertainty

- Route corridor width is a policy input with a conservative server-defined minimum and maximum; clients cannot shrink it below the server minimum.
- Expand the effective restricted radius by the route corridor buffer and configured localization uncertainty.
- The client must provide location accuracy as metadata only when it is measured and available; do not fabricate a precision value.
- If current device accuracy is worse than the experience threshold, pause precise AR guidance and switch to a safe non-AR state (for example, a general direction or map overview) with a clear uncertainty notice.
- A route assessment does not override temporary closures, weather, construction, crowding, terrain, private access, or hazards absent from authoritative data.

### 4.3 Limits and denial of service

- Bound route vertices, total route length, number of alternatives, and evaluation duration.
- Reject over-limit requests; do not silently truncate geometry.
- Use one request-scoped policy snapshot for the complete route and all alternatives in that evaluation.
- Prefer one geometry-aware Safety API call over N point calls or N+1 database reads.
- Return stable error codes; do not echo full sensitive geometry in errors or logs.

## 5. Alternatives and guidance behavior

1. Ask the routing provider for a bounded set of alternatives where supported.
2. Evaluate every alternative independently against the same policy snapshot.
3. Never select a blocked route because it is shorter, cheaper, sponsored, or ranked higher.
4. If one or more permitted alternatives exist, rank only those using user preferences and routing-provider metrics.
5. If all candidates are blocked, report that no permitted route is available; do not synthesize a shortcut through the blocked area.
6. If policy evaluation is unavailable, suppress route-specific turn/arrow guidance. The client may offer retry, return-to-origin, or a generic non-route safety notice, but must not continue presenting the last route as currently authorized.

## 6. Live navigation and policy changes

A route assessment is time-bound and does not grant permanent permission.

- Return `evaluatedAt`, `policyRevision` (or equivalent monotonic policy version), and a bounded `validUntil`.
- Re-evaluate when the route changes, the user deviates beyond a configured threshold, the policy revision changes, the validity window expires, or the client resumes after a long interruption.
- Emergency restrictions must trigger prompt invalidation through the existing safety event/notification path when available; polling remains a fallback, not the only emergency mechanism.
- If a re-evaluation fails, stop route-specific guidance and clearly indicate that route safety could not be confirmed.
- Avoid continuous high-frequency raw-location uploads. Send only the minimum route progress or relevant geometry needed for the check, with explicit retention and privacy limits.

## 7. Client presentation and accessibility

The safety result is presentation-independent. Flutter may render an approved route as a map line, AR arrows, voice instructions, haptics, or accessible text, but every presentation must consume the same authoritative route assessment.

- Never place arrows over a blocked segment or imply that the user should cross a prohibited area.
- Provide a non-AR map/list alternative and accessible text instructions.
- Keep safety status understandable without color alone.
- Do not encourage trespass, crossing barriers, entering private property, or obstructing public paths to align with an AR overlay.
- If AR tracking, compass heading, localization, or camera permission is unavailable, degrade to a supported non-AR presentation rather than guessing.

## 8. API evolution proposal

Add a geometry-aware operation to the existing Safety API rather than expanding the point batch into an ambiguous contract. Proposed shape (names are provisional):

`POST /safety/spatial/evaluate/route`

Request:
- activity: `NAVIGATE`
- coordinateReferenceSystem: `EPSG:4326`
- geometry: ordered route vertices
- corridorBufferMeters: optional bounded request hint; server minimum/maximum remain authoritative
- alternatives: bounded list of candidate geometries

Response:
- evaluatedAt, policyRevision, validUntil
- per-route outcome, bounded reason codes, and affected segment index ranges
- no raw restriction records or authority-only metadata

The endpoint must authenticate the calling service with a dedicated scope or the existing spatial policy evaluation scope after an explicit scope review. It must validate all geometry and evaluate every alternative against a single captured snapshot. It must fail closed with 503 when policy storage or geometry evaluation is unavailable.

Before implementation, confirm whether Idrisi already exposes a route geometry contract and whether it can provide stable route/segment identifiers. Keep the Safety contract provider-neutral.

## 9. Implementation sequence and acceptance gates

### N1 — Provider and contract discovery
- Inspect Idrisi route APIs, geometry CRS, alternatives, route identity/versioning, and error semantics.
- Record the provider contract and whether geometry is a LineString or ordered segment list.
- Confirm which existing Jezaku module orchestrates route preview; do not assume journey checkpoints are route geometry.

**Exit:** a concrete provider adapter contract exists and no duplicate routing engine is introduced.

### N2 — Geometry safety primitive in Safety
- [x] Add spherical great-circle segment-to-circle distance evaluation for bounded WGS84 polylines.
- [x] Apply activity/time filtering, restriction precedence, and a bounded route corridor buffer.
- [x] Return affected zero-based segment indices without exposing restriction geometry.
- [x] Reuse a captured policy snapshot through the enforcer; no per-segment repository reads.
- [x] Test a restriction between clear endpoints, corridor expansion, antimeridian crossing, activity/time filtering, and malformed geometry.
- [ ] Add the authenticated route-evaluation HTTP endpoint, stable DTOs, alternatives batch semantics, policy revision, and response validity contract.

**Exit:** the pure geometry/enforcer primitive is implemented. Route API exposure and alternatives remain open; no consumer may claim route authorization yet.

### N3 — Jezaku route assessment adapter
- Add a service-authenticated adapter in the existing navigation orchestration boundary.
- Validate provider geometry before forwarding.
- Preserve provider route identity and version; never treat provider safety flags as authoritative.
- Fail closed on timeout, malformed response, missing segment decisions, or unknown outcomes.

**Exit:** integration tests cover permitted, caution, blocked, malformed, timeout, and partial results.

### N4 — Alternative selection and live invalidation
- Filter blocked alternatives before ranking.
- Add route validity and policy revision handling.
- Re-evaluate on route deviation, expiry, resume, and policy change.
- Define emergency invalidation delivery and fallback behavior.

**Exit:** no stale route remains presented as authorized after a failed or blocking re-evaluation.

### N5 — Flutter navigation presentation
- Consume only assessed routes.
- Render AR/map/voice/accessibility views from the same route response.
- Add tracking/heading accuracy gates and non-AR fallback.
- Validate on real devices and in controlled safe environments.

**Exit:** physical-device tests show safe suppression/degradation under poor localization, compass drift, network loss, and policy invalidation.

## 10. Explicit non-goals

This contract does not claim to provide:
- A routing graph or routing engine.
- Real-time road closures, weather, terrain, crime, or crowd intelligence.
- Guaranteed physical safety or legal permission to enter a location.
- Turn-by-turn navigation based only on journey checkpoints.
- Permanent authorization based on a one-time route evaluation.
- A client-side substitute for authoritative Safety decisions.
