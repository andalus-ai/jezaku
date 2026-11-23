# ADR-0001: Jezaku Spatial Platform Principles

- **Status:** Accepted strategic direction; implementation details require follow-up ADRs.
- **Date:** 2026-11-23
- **Decision owners:** Jezaku maintainers

## Context
Jezaku is extending from existing AR/frame capabilities toward navigation, Qibla, commerce, advertising, tourism, education, public services, industrial assistance, extensions, and future spatial devices. Separate feature implementations would duplicate spatial primitives; coupling Core to one business vertical or AR provider would limit reuse.

## Decision
1. Position Jezaku as an extensible spatial experience platform.
2. Organize the product into Core, optional Platform services, and Experiences.
3. Treat Spatial Object, Scene, Placement/Anchor, coordinate contracts, lifecycle, interaction, and safety/access integration as shared foundations.
4. Keep vertical business rules in experiences or optional platform modules.
5. Make smartphone the first-class initial device while keeping contracts provider/device agnostic.
6. Keep logical modules first; do not create deployables solely from diagrams.
7. Preserve current frame sharing, visibility, moderation, radius, and offline behavior.
8. Require versioned, permission-declared, validated, revocable extensions.
9. Evaluate safety and access before discovery ranking, navigation, rendering, and advertising.
10. Treat location, camera, sensor, identity, and movement data as sensitive.

## Consequences
**Benefits:** reusable experiences; Core independent of commerce; future device adapters; consistent governance; incremental evolution.

**Trade-offs:** careful contract/version design; device/localization fragmentation; extension security and marketplace governance complexity; specialized experiences still need domain policies.

## Alternatives
- Separate app per vertical: rejected as primary strategy due to duplicated spatial capabilities.
- Hardcoded object types in one AR feature: rejected due to poor extensibility.
- Immediate microservice decomposition: rejected until ownership and operational needs justify it.
- Marketplace-first: rejected because object, asset, permission, and extension contracts must stabilize first.

## Follow-up ADRs
Spatial Object/Scene schema; coordinate and placement contract; device/runtime/provider interfaces; discovery and safety enforcement; extension package and sandbox; API/event compatibility and evolution.
