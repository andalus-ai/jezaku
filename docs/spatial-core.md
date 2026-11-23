# Jezaku Spatial Core Specification

> Proposed domain contract for review; not a claim these models or APIs are implemented.

## Scope
Core defines reusable spatial concepts shared across experiences. It does not contain merchant, advertising, Qibla, tourism, education, or other vertical business rules.

Responsibilities: Spatial Object/type identity; Spatial Scene composition; placement/anchor references; coordinate frames/transforms; lifecycle/versioning; interaction/event contracts; identity/access and safety integration.

## Spatial Object
A typed digital entity that may be placed, discovered, presented, interacted with, governed, and versioned.

Required conceptual attributes:
- Stable id, type, and schemaVersion.
- Owner principal and principal type; optional tenantId.
- Typed definition and appearance references.
- Placement and interaction profile references.
- Visibility intent and authoritative access-policy reference.
- Declared capabilities.
- Lifecycle and safety classification.
- Extension metadata and concurrency/version token.

Do not put authorization, ownership, lifecycle, or safety semantics in arbitrary metadata.

### Type registry
Each type declares publisher-qualified identifier, schema/version, placement strategies, required capabilities, media constraints, interactions, permission requirements, safety classification, compatibility, and deprecation policy. Unknown types must fail closed or use a safe generic fallback; never execute unknown behavior.

## Placement
Strategies: GEO_ANCHORED, WORLD_ANCHORED, SURFACE_ANCHORED, RELATIVE_ANCHORED, CAMERA_RELATIVE, USER_ATTACHED, SESSION_ANCHORED.
Every placement declares coordinate frame, units, position/orientation conventions, scale where relevant, anchor/provider reference, tracking state, accuracy/confidence and observation time, persistence/expiry, and fallback/suppression behavior.
Camera-relative/user-attached modes are presentation modes, not substitutes for persistent world anchors.

## Coordinate frames
Distinguish WGS84 geographic coordinates, local metric frame, AR session frame, object-local frame, and camera/device frame. Transform contracts declare source/destination frame, units, axis convention, handedness, timestamp, and uncertainty. Never silently mix degrees/meters or geographic/AR coordinates.

## Spatial Scene
A scene groups objects and relationships. Conceptual fields include stable ID/schema, owner/tenant, access-policy reference, object references/hierarchy, scene state/activation window, ordering/presentation hints, version/sync metadata. Scene access does not grant access to every object.

## Lifecycle
Suggested states: DRAFT → VALIDATING → PENDING_REVIEW → PUBLISHED → ACTIVE → SUSPENDED → EXPIRED / REVOKED / DELETED.
Not all types require every state. Transitions are explicit, authorized, auditable, and idempotent where possible. Revocation must invalidate discovery and cached presentation promptly.

## Ownership and visibility
Separate owner, publisher, tenant, viewer, visibility intent, and contextual access decision. Private/friends/tenant/public/restricted labels are not authorization by themselves.
Existing Jezaku frame policy remains authoritative: owner gallery access and on-site viewer radius/sharing rules must not be weakened by generic discovery.

## Interactions
Interactions describe intent, not vendor-specific input. Examples: activate, select, deselect, open-details, focus, drag, transform, dismiss, and namespaced custom actions. Each declares stable action/schema ID, required capability, preconditions/permission, payload schema/limits, result/event, accessibility alternative, and replay/idempotency behavior.

## Events
Illustrative versioned events: spatial.object.created.v1, spatial.object.updated.v1, spatial.object.published.v1, spatial.object.suspended.v1, spatial.object.revoked.v1, spatial.scene.activated.v1, spatial.placement.tracking_lost.v1, spatial.placement.tracking_restored.v1, spatial.interaction.invoked.v1.
Include event ID, timestamp, schema version, safe actor/context, tenant where relevant, and correlation ID. Do not promise exactly-once delivery. Avoid sensitive coordinates and personal data unless necessary.

## Acceptance
Schema validation rejects malformed/unsupported definitions; coordinate tests cover units/axes/frames/uncertainty; authorization tests cover owner/shared/tenant/public/denied; lifecycle tests cover invalid transitions/revocation; scene tests preserve object-level policies; serialization round-trips preserve versions; unknown capabilities fail safely; existing frame visibility/radius tests continue to pass.
