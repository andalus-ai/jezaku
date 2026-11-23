# Jezaku Platform Roadmap

> Strategic target roadmap, not a claim that listed capabilities are implemented.

## Principles
1. Stabilize reusable contracts before domain experiences.
2. Preserve current Flutter, Quarkus, and AR package boundaries unless an ADR justifies change.
3. Prefer logical modular boundaries before separate deployables.
4. Build safety, privacy, authorization, moderation, observability, and accessibility throughout.
5. Keep marketplace and commerce optional.
6. Validate smartphone behavior on physical devices.

## Stage 0 — Architecture and engineering baseline
Inventory existing UI, backend, AR packages, APIs, tests, and documentation. Define domain vocabulary, module ownership, coordinate/placement/lifecycle/access/safety/extension decisions, API/event/versioning/testing standards, and implementation gaps.
**Exit:** source-backed capability map, explicit decisions and unresolved questions, no unjustified duplicate subsystem.

## Stage 1 — Spatial Core
Define Spatial Object, type registry, ownership, visibility, lifecycle, versioning; Spatial Scene composition; placement and anchors; coordinate frames and transforms; interaction contracts; versioned events; identity/access and safety integration.
**Exit:** tests demonstrate lifecycle, placement validation, provider-independent serialization, and authorization.

## Stage 2 — Device Runtime and SDK
Capability model; camera/pose/location/orientation/depth/input adapters; session lifecycle; renderer and AR provider interfaces; ARCore/ARKit adapters consistent with existing package ownership; tracking recovery; sample SDK and testkit.
**Exit:** real-device sample creates, places, manipulates, restores where supported, and removes an object, with limitations documented.

## Stage 3 — Discovery and Navigation
Bounded geospatial queries; server-side access, lifecycle, moderation, consent, safety and capability filtering; navigation targets/routes/waypoints/instructions; bearing/orientation confidence; AR, map, voice, and non-AR presentations; Qibla as a bearing experience, not road routing.
**Exit:** discovery and navigation have tested authorization, accuracy thresholds, and safe fallbacks.

## Stage 4 — Extension and Marketplace Foundation
Versioned manifests; capability/permission declarations; signatures, validation, sandbox/resource limits, revocation; asset ingestion and optimization; developer docs and tools; distinct asset, object-template, and experience catalogs.
**Exit:** reference extension can be validated, installed, constrained, upgraded, disabled, and revoked.

## Stage 5 — Spatial Commerce
Merchant verification, stores and staff roles; spatial presence; campaigns, targeting, consent, frequency caps; promotion quotas/expiry/redemption; server-authoritative offer state; privacy-aware analytics.
**Exit:** test merchant can publish and redeem an eligible offer with consent, safety, quota, and replay controls.

## Stage 6 — Spatial Experiences
Qibla, tourism, education, public information, industrial assistance, events, games, social, and persistent spaces. Reuse shared Core/runtime contracts.
**Exit:** multiple experiences share primitives without duplicating placement, identity, discovery, or safety logic.

## Stage 7 — Advanced Ecosystem
Capability-based smart-glasses/XR adapters; multiplayer/shared sessions; AI-assisted authoring with validation and approval; digital twin/IoT integrations; WebXR/OpenXR and interoperable assets.
**Exit:** independent device/provider paths interoperate through documented contracts.

## Dependency overview
Stage 0 → Stage 1 → Stage 2 → Stage 3 → Stage 6 → Stage 7.
Stage 1 → Stage 4 → Marketplace → Stage 5.
Stage 3 and Stage 4 provide dependencies for commerce. Work may overlap after contracts stabilize.

## Cross-cutting requirements
Security, privacy, consent, tenant isolation, physical-world safety, accessibility, offline/sync, observability, rate limits, moderation, API/event compatibility, migrations, tests, and real-device validation apply to every stage.

Prioritize shared primitives and proven blockers. Defer speculative infrastructure, premature microservices, and monetization until real use cases validate contracts.
