# Jezaku Platform Architecture

> Target logical architecture, not a statement that every module or service exists today.

## Goals
Provide reusable spatial domain independent of AR vendor, device, and vertical; preserve current ownership boundaries; keep optional platform features out of Core; enforce access, moderation, and safety authoritatively; support smartphone-first offline-aware use; evolve through versioned contracts.

## Layers
1. **Applications:** Flutter mobile, web management/preview, future device clients.
2. **Device Runtime and SDK:** capability adapters, session lifecycle, tracking, rendering, AR provider adapters.
3. **Jezaku Core:** objects, scenes, placement, coordinates, discovery, interaction, navigation contracts, lifecycle, identity/access and safety interfaces.
4. **Optional Platform Services:** asset management, publishing, extensions, marketplace, merchant/commerce, moderation, analytics, developer portal.
5. **External Providers:** AR runtimes, maps/routing/geocoding, storage, messaging, authenticated authority/property feeds.

## Logical architecture
Applications → Device Runtime/SDK → Jezaku Core ↔ Optional Platform Services.
External providers connect through adapters. Safety and access policy constrain object creation, discovery, navigation, and presentation. This is a responsibility map, not a mandate to split each box into a deployable service.

## Existing repository alignment
The repository uses Flutter and reusable Dart packages under UI/Packages, plus Maven multi-module Quarkus under Backend. Preserve those boundaries:
- App workflows and composition belong in the Flutter app.
- Reusable AR behavior belongs in the appropriate existing AR package.
- Backend domain behavior belongs to its owning Quarkus module.
- Backend/common is for genuinely cross-cutting infrastructure.
- Product-level architecture belongs in docs.
- Do not create a package/service until ownership and reuse/deployment need are established.
- Keep the ARCore engine/provider boundary reusable; Jezaku consumes it through explicit adapters rather than making domain models ARCore-specific.

## Core boundaries
| Capability | Responsibility | Must not own |
|---|---|---|
| Spatial Object | identity, type, definition, owner, lifecycle, version | merchant campaign rules |
| Spatial Scene | composition, hierarchy, activation | authorization bypass |
| Placement/Anchor | coordinate frame, transform, tracking relation | renderer internals |
| Coordinates | units, transforms, bearing, uncertainty | sensor lifecycle |
| Discovery | candidate retrieval and eligibility | client-only privacy enforcement |
| Interaction | modality-independent actions and events | vendor-specific gestures |
| Navigation | targets, routes, waypoints, instructions | arrow model or renderer |
| Safety/Governance | restrictions, evaluation, audit | ad ranking override |
| Device Runtime | capabilities, sessions, provider adapters | business ownership |
| Extensions | package capabilities and lifecycle | unrestricted host access |
| Commerce | merchants, campaigns, promotions, redemption | Core object lifecycle |

## Object and scene
A Spatial Object is typed digital content that may be placed, discovered, presented, interacted with, governed, and versioned. It may be 2D, 3D, text, audio, media, marker, or structured experience.
Conceptual fields: id; type/schemaVersion; owner; optional tenantId; definition; appearance; placement reference; interaction profile; visibility; access-policy reference; capabilities; lifecycle; safety classification; metadata; version.
Core authorization and safety fields must be typed, not hidden in arbitrary metadata.
A Spatial Scene composes objects and relationships. Scene activation never bypasses object-level access or safety policy.

## Placement and coordinates
Strategies: GEO_ANCHORED, WORLD_ANCHORED, SURFACE_ANCHORED, RELATIVE_ANCHORED, CAMERA_RELATIVE, USER_ATTACHED, SESSION_ANCHORED. Each declares coordinate frame, units, axis/orientation convention, tracking requirement, persistence, accuracy/confidence, and fallback.
Distinguish WGS84 geographic coordinates, local metric coordinates, AR session coordinates, object-local coordinates, and camera/device coordinates. Geographic coordinates are not directly interchangeable with AR session coordinates; a coordinate alone does not guarantee visual alignment.

## Device abstraction
Negotiate camera, display, location, orientation, spatial tracking, depth, audio, input, and connectivity capabilities. Missing capabilities are explicit. ARCore, ARKit, XR runtimes, and glasses are adapters; provider-specific types must not leak into Core.

## Discovery, safety, and access
Discovery returns eligible candidates, not every nearby object. Evaluate identity, sharing, tenant, lifecycle, moderation, safety/geofences, consent, placement validity, location accuracy, device capability, context, and frequency. Apply safety/access before ranking and presentation. Client checks are defense-in-depth. Uncertain critical policy/localization state suppresses or degrades the experience safely.

## Navigation separation
A Navigation Target is a destination entity; a Route is a path/waypoints/instructions; arrow, path, map marker, voice prompt, or HUD is presentation. Qibla is a specialized bearing/orientation experience toward the Kaaba, not road routing.

## Optional services and deployment
Asset management, extension publishing, marketplace, merchant management, advertising, promotions, and analytics are optional. Start with logical modules mapped to existing deployables. Add deployables only for demonstrated ownership, scale, isolation, operational, or release needs. Use explicit contracts, idempotent handlers, bounded retries, correlation IDs, and observable failures.

## Compatibility
Preserve current frame visibility, sharing, moderation, and physical-radius policy. Generic discovery must not expose private frames. Preserve offline-first capture and queued work where supported. Do not claim tracking/persistence/cross-device localization beyond tested provider capabilities.
