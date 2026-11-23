# ADR-0002: Navigation and Routing Ownership

- **Status:** Accepted
- **Date:** 2026-11-23
- **Decision owners:** Jezaku platform architecture
- **Related:** [Navigation Safety Contract](../navigation-safety-contract.md), [Spatial Safety Integration Plan](../spatial-safety-integration-plan.md)

## Context

Jezaku needs route guidance for journeys, trails, wayfinding, and future AR experiences. The repository already has a Safety module that owns spatial restrictions, a journeys module that owns ordered checkpoints and progress, a spatial-trails-places module that owns anchors/places/completed trail history, and Flutter presentation code.

The current client-side `ARTrailRouteService` computes direct geodesic distance and bearing between stop coordinates. It does not use a routable road/path graph and must not be represented as pedestrian or road navigation. Completed trail records and journey checkpoints are not authoritative route geometry.

Idrisi is the intended self-hosted geospatial provider. Its architecture identifies Valhalla as the initial routing-engine integration, but its current repository status lists routing as planned rather than implemented.

## Decision

1. **Route generation belongs to a configured routing provider.** Idrisi is the preferred provider for Jezaku deployments. Jezaku will consume provider-neutral route geometry and will not implement or maintain a second road/path routing engine.
2. **Jezaku owns product orchestration.** Existing journey/spatial application boundaries will coordinate route preview, user context, route lifecycle, and delivery. A new service is not justified until a concrete deployment or ownership need exists.
3. **The existing Safety module remains the only policy authority.** It owns restriction storage, policy snapshots, geometry evaluation, and authoritative `NAVIGATE` decisions. No second geofence store or navigation-specific policy service will be introduced.
4. **A route is evaluated as continuous geometry.** Checking endpoints, checkpoints, or vertices alone is insufficient. The Safety evaluator must detect restriction intersections along every segment, using a geodesic-aware method and a conservative corridor/uncertainty buffer.
5. **Provider output is untrusted input.** Jezaku validates CRS, coordinate ranges, geometry size, ordering, route length, and provider identifiers before safety evaluation. Provider-supplied safety flags are never authoritative.
6. **Presentation is separate from route truth.** Flutter and AR runtime may render an assessed route as a map line, arrows, voice, haptics, or accessible text. They cannot convert a blocked or unavailable route into an approved one.
7. **Safety failure suppresses route-specific guidance.** Policy timeout, malformed geometry, incomplete decisions, expired assessment, or unknown outcomes must never be interpreted as permission. The client degrades to a clear non-AR/non-route state.
8. **Route assessments are time-bound.** Route changes, meaningful deviation, policy revision changes, expiry, and long app suspension require re-evaluation. A previous decision is not permanent authorization.

## Consequences

### Positive

- Reuses Idrisi's intended routing stack and the existing Safety policy owner.
- Keeps Jezaku provider-agnostic and the AR presentation reusable across phones and future glasses.
- Prevents false confidence from straight-line bearings or endpoint-only checks.
- Gives alternatives, live invalidation, offline behavior, and accessibility a consistent safety boundary.

### Costs and trade-offs

- A geometry-aware Safety API is required; the current point and point-batch endpoints are insufficient.
- The routing provider must expose stable route geometry/version identifiers and bounded alternatives.
- The initial Safety restriction model is circular. Polygon/multipolygon intersection requires a later, explicit geometry/data ownership decision.
- Live policy invalidation and offline route behavior require additional contracts and operational validation.

## Current implementation status

This ADR records architecture ownership, not delivered navigation functionality. The route provider integration, geometry-aware Safety endpoint, route orchestration adapter, live invalidation, and AR navigation UI remain unimplemented. The current direct-bearing trail helper remains a lightweight stop-to-stop visualization only.
