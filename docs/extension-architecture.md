# Jezaku Extension Architecture

> Target architecture. Public third-party execution and marketplace distribution require security review before launch.

## Goals
Allow developers to add object types, templates, experiences, integrations, and constrained behaviors without modifying Core or gaining unrestricted host access.

## Extension categories
- Declarative object type and schema.
- Asset/template pack: models, materials, animation, audio, scene templates.
- Experience package: bounded domain experience using supported APIs.
- Provider adapter: approved routing, localization, or content provider.
- Integration: external service through scoped backend APIs.
- Interaction module: constrained definitions or sandboxed behavior.

## Package contract
A package declares publisher-qualified ID, name, semantic version, manifest schema version, compatible Jezaku API versions, pinned dependencies and integrity hashes, object types/capabilities, permissions and rationale, entry points/resource requirements, assets/licenses, signature/provenance, privacy disclosures, safety/content category, changelog, and deprecation.

Illustrative manifest fields:
- manifestVersion
- id and version
- compatibility.jezakuApi
- capabilities[]
- permissions[]
- objects[]
- assets[]

This list is conceptual; formalize a machine-readable schema before implementation.

## Capability security
Use least privilege, explicit and revocable grants, host-enforced APIs, and user/tenant review. Possible namespaces include spatial.object.read, spatial.object.create, spatial.object.update.owned, spatial.scene.compose, spatial.render, spatial.anchor.create, spatial.location.coarse, spatial.location.precise, spatial.camera.access, spatial.interaction.register, spatial.navigation.target.read.
Avoid wildcard grants. Precise location, camera, microphone, contacts, and external network access need separate justification and consent.

## Execution model
Prefer declarative manifests, typed schemas, and host-provided APIs. Untrusted executable extensions require sandboxing, no ambient filesystem/process/network access, host API allowlists, CPU/memory/storage/time limits, validated I/O, safe timeout behavior, pinned dependencies, and audit. Do not load arbitrary native code into the core app. Client and server execution have separate threat models.

## Validation and publishing
1. Upload and size/type validation.
2. Manifest/schema validation.
3. Dependency and compatibility resolution.
4. Asset scanning and content moderation.
5. License/provenance checks.
6. Static analysis and sandbox tests for executable behavior.
7. Permission/privacy review.
8. Safety review.
9. Signed immutable release.
10. Staged publication and monitoring.

## Lifecycle and revocation
Support draft, submitted, reviewing, approved, published, deprecated, suspended, revoked, and removed as appropriate. Revocation prevents new installs, disables affected execution, invalidates caches, notifies affected parties where appropriate, preserves audit evidence, and supports safe rollback.

## Marketplace separation
Distribution is separate from execution. Private/internal registries need not publish to a public marketplace. Marketplace approval does not grant runtime permissions. Asset, object-template, and experience listings are distinct product types.

## Developer experience and acceptance
Provide manifest/API docs, local validator CLI, samples, simulator/testkit, compatibility matrix, signing/release guide, permission explanation, submission/review/analytics/revocation status.
A reference extension must package, validate, sign, install, permission-review, execute only allowed APIs, upgrade, disable, and revoke. Undeclared capabilities are denied.
