# Spatial Safety Enforcement Contract

## Purpose

`SpatialSafetyEnforcer` is the single application-level enforcement entry point for backend operations whose behavior depends on physical location. It reuses the existing `SpatialPolicyRepository` and `SpatialSafetyPolicy`; it does not maintain a second policy store or evaluator.

## Required call order

Every affected command handler must call the enforcer after it has resolved the authoritative operation coordinate and before it performs a durable or externally visible side effect:

1. Authenticate and authorize the user/service for the product operation.
2. Resolve the coordinate from trusted server-side state or a validated location claim. Do not accept an arbitrary client coordinate as proof of where a merchant, asset, or destination is located.
3. Call `SpatialSafetyEnforcer.requirePermitted(latitude, longitude, activity)`.
4. If it returns, continue the operation. Preserve and surface `CAUTION` messaging to the user where appropriate.
5. If it throws, do not publish, expose, navigate, redeem, or execute the operation.

Do not call the enforcer asynchronously after a publish or redemption has already succeeded.

## Activity mapping

| Feature operation | Activity |
|---|---|
| Create/publish an AR object or placement | `PUBLISH` |
| Return nearby public objects, merchants, or offers | `DISCOVER` |
| Make a placed object visible or interactive in AR | `RENDER` |
| Start or continue a route / spatial guidance | `NAVIGATE` |
| Redeem a promotion, coupon, or location reward | `REDEEM` |
| Trigger an in-world action or interaction | `INTERACT` |

For multi-stage operations, evaluate each relevant stage. A successful publish-time check is not a substitute for render-time evaluation because restrictions can change after publication. Re-evaluate at redemption because promotions and user location are time-sensitive.

## Decision behavior

- `ALLOWED`: proceed.
- `CAUTION`: proceed only with the product's caution UX and any applicable user confirmation.
- `RESTRICTED`, `PROHIBITED`, `EMERGENCY_LOCKDOWN`: reject the operation.
- Policy repository failure or missing authoritative result: return 503 and reject the operation. Never interpret unavailable policy data as ALLOWED.

The enforcer currently reads active persisted restrictions for each evaluation; it intentionally does not introduce a cache that could serve stale policy. Any future cache must have explicit versioning/invalidation and a documented maximum staleness budget, and must preserve emergency lockdown propagation.

## Coordinate trust and freshness

- Use the location of the object/place for publishing and rendering.
- Use the relevant route segment or destination for navigation; a single point check is not sufficient for a route that crosses multiple restriction geometries.
- Use the merchant/offer location and validated user proximity for discovery and redemption.
- Do not log raw coordinates. Emit policy outcome, activity, restriction IDs, and a request/correlation ID where safe.
- Define freshness and spoofing controls at the calling feature boundary. The enforcer cannot prove the provenance of coordinates supplied to it.

## Current implementation boundary

This change supplies the shared fail-closed enforcement primitive and its unit tests. It does not yet inject the enforcer into every existing feature service. Each feature integration must be implemented and tested in its owning module; no feature should claim enforcement until its command/query path has an integration test proving a matching restriction blocks the side effect.

The current evaluator supports circular geofences. Route-segment intersection, polygon/multipolygon rules, offline signed policy bundles, and distributed invalidation are future work.
