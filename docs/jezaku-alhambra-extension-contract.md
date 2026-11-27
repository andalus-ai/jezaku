# Jezaku–Alhambra Extension Contract

> **Status:** Target contract, version 1.0.0 draft. This is an architecture and validation baseline, not permission to execute marketplace code.

## Purpose

Map Alhambra's generic plugin contribution and lifecycle foundation to Jezaku's product-specific extension system without transferring Jezaku domain authority to the Flutter client.

The initial manifest schema is at [`schemas/jezaku-extension-manifest.schema.json`](../schemas/jezaku-extension-manifest.schema.json). It validates the publisher's declaration only. It is not a grant, proof of safety, package signature verifier, or execution sandbox.

## Contract ownership and mapping

| Concern | Alhambra foundation | Jezaku authority / required adapter |
|---|---|---|
| Plugin identity and metadata | Plugin manifest and metadata contracts | Publisher-qualified package identity, listing, ownership, version and release records |
| Capability declaration | Capability models, broker contracts and negotiation | Jezaku capability catalogue, policy version, review decision and effective grant |
| Runtime context and scope | Plugin context and runtime-scope contracts | Trusted tenant, user, installation, area, object and session scope resolved by backend |
| UI contributions | Navigation, views, toolbar, context menu, activity/status bar and UI contribution contracts | Allowed extension surfaces, UX policy, disclosure and safe fallback |
| Commands and tools | Command and agent-tool contracts | Server-side authorization, input/output validation, rate limits and audit |
| Packaging and integrity | Packaging, installation, integrity and lease contracts | Immutable marketplace artifact, digest/signature/provenance verification and publisher trust |
| Lifecycle and recovery | Plugin manager, startup/shutdown, recovery and runtime health | Marketplace states, approval, install policy, quarantine, disablement, revocation and incident response |
| Events and context | Event bus and context contribution contracts | Data minimization, tenant filtering, consent and event disclosure |
| Domain operations | Generic host-provided capabilities | Jezaku APIs only; Quarkus owns spatial, safety, commerce and navigation invariants |

Alhambra types are host implementation contracts. They are not automatically wire formats for the Jezaku backend or marketplace manifest. Define explicit adapters and versioned serialization at the boundary.

## Package classes and execution policy

| Package class | Default execution | Initial release policy |
|---|---|---|
| Declarative object/schema | Validated data interpreted by Jezaku-owned renderer | Preferred |
| Asset/template pack | Static assets through a constrained asset pipeline | Preferred after malware, license, format and resource checks |
| Experience package | Declarative workflow composed from approved host surfaces and APIs | Allowlist only |
| Provider adapter / integration | Remote service called through Jezaku backend connector | Review each connector; no arbitrary client network access |
| Sandboxed module | Dedicated isolated runtime, separate from Flutter process | Disabled until a separate isolation ADR and threat-model validation |

Do not load downloaded Dart, native libraries, scripts with ambient host access, or dynamic executable payloads into the Flutter application. Alhambra's in-process runtime is appropriate only for trusted, host-bundled code controlled by the application publisher.

## Capability and permission model

A manifest declares *requested* capabilities and permissions. Effective authority is calculated independently:

1. Validate the manifest against a pinned schema version.
2. Resolve package, publisher, artifact digest, dependency graph and compatibility from trusted marketplace records.
3. Map every requested capability to a versioned Jezaku capability definition.
4. Reject unknown capabilities, wildcard requests, unsupported scope types and undeclared API calls.
5. Run publisher, privacy, license, content and spatial-safety review.
6. Obtain required platform/operator approval and end-user consent for sensitive data or device access.
7. Create an installation-specific grant with resource and tenant scope, expiry/review policy and grantor provenance.
8. On each privileged operation, Quarkus authenticates the caller and resolves current grants and target-resource scope. The client runtime never supplies authoritative scope.
9. Persist decision and mutation audit records. Denials and revocations must be observable.

No wildcard permission is valid. A request for a capability is not an entitlement. Approval to publish is not approval to install, and installation is not a runtime grant.

### Initial capability namespaces

- `spatial.object.read`, `spatial.object.create`, `spatial.object.update.owned`
- `spatial.scene.compose`, `spatial.render`, `spatial.anchor.read`, `spatial.anchor.create`
- `spatial.location.coarse`, `spatial.location.precise`
- `spatial.navigation.target.read`, `spatial.navigation.route.request`
- `commerce.storefront.read`, `commerce.offer.read`, `commerce.redemption.request`
- `ads.campaign.read`, `ads.impression.report`
- `safety.content.submit`, `safety.report.read.own`
- `notifications.send` (host-mediated, user-visible and rate-limited)

This is a proposed vocabulary, not an implemented registry. Camera, microphone, precise location, external network, user data export, payments, physical-world actuation and administrative operations require separate high-risk review and should not be available in the initial public extension tier.

## Manifest invariants

The schema requires publisher identity, semantic version, compatibility, package type, requested capabilities and permissions, asset hashes/licenses, privacy disclosure, and a physical-world impact classification.

Additional server-side invariants that JSON Schema cannot establish:

- Package ID and publisher ownership are verified against marketplace records.
- Artifact digest is calculated from uploaded bytes; never trust a manifest-provided digest alone.
- Every asset path is normalized; reject traversal, symlinks, duplicate paths, decompression bombs and unsupported media.
- Signature verification uses an approved publisher key and a trusted timestamp/revocation policy.
- Dependencies resolve to immutable versions/digests; no floating dependency at install time.
- Compatibility is checked against the actual host and Jezaku API version.
- Capability and permission sets are checked against an allowlist and review outcome.
- Spatial placement is constrained by server-derived area/jurisdiction, object ownership, visibility and safety policy.
- Sensitive data collection, sharing, retention and consent are explicit and enforceable.

## Lifecycle state machine

`draft → submitted → validating → reviewing → approved → published → installable → installed → enabled`

Alternative and terminal transitions:

- Validation/review failure → `rejected` with reason and resubmission path.
- Published release → `deprecated` while existing installs follow a defined migration window.
- Any unsafe or compromised release → `suspended` or `revoked`; disable new installs immediately.
- Installation → `disabled` or `uninstalled`; retain required audit and user-owned data handling records.
- Update → install new immutable release, validate compatibility and grants, then activate with rollback support.

Marketplace publication, tenant installation, operator approval, user consent and runtime enablement are separate decisions. Revocation must invalidate caches/leases, stop future invocations, notify relevant hosts, preserve evidence and reconcile offline clients when they reconnect.

## Trust boundaries and API flow

```text
Publisher / Developer
  └─ uploads immutable package + manifest
       ↓
Jezaku Marketplace (Quarkus)
  ├─ schema, artifact, dependency and signature validation
  ├─ privacy, license, content and safety review
  ├─ approval and publication records
  └─ signed release metadata
       ↓
Jezaku Host / Flutter app
  ├─ fetches approved declarative package
  ├─ verifies artifact digest and release metadata
  ├─ renders approved contributions
  └─ calls only typed host-mediated APIs
       ↓
Jezaku Quarkus domain APIs
  ├─ authenticate actor and installation
  ├─ resolve tenant/resource scope from trusted records
  ├─ evaluate current grants and domain policy
  ├─ enforce rate/resource limits
  └─ persist audit and domain mutation
```

Never trust client-provided publisher status, permission decisions, tenant IDs, object ownership, area scope, user consent claims or grant IDs without server-side lookup and validation.

## Alhambra integration sequence

1. Keep Alhambra plugin API/runtime out of the production Jezaku dependency graph until the host-side execution mode is selected.
2. Build a small adapter translating validated Jezaku package metadata to Alhambra manifest/contribution types for trusted bundled contributions only.
3. Use Alhambra capability negotiation as a host composition mechanism, not as the source of backend grants.
4. Restrict UI contributions to a reviewed set of extension points and validate contribution IDs, routes, schemas, payload size and lifecycle.
5. Bridge commands to typed Jezaku backend clients; every server operation remains independently authorized.
6. Add contract tests for unknown capability denial, scope mismatch, expired/revoked grant, package digest mismatch, incompatible API, unsafe content and runtime shutdown.
7. Consider sandboxed modules only after a separate ADR compares constrained declarative execution, WASM with a hardened host, and remote isolated execution.

## Delivery phases

- **E1 — Contract:** schema, capability catalogue, lifecycle model, ownership and threat model.
- **E2 — Validation:** backend manifest validator, immutable artifact store, digest/signature verification and compatibility checks.
- **E3 — Review:** publisher trust, privacy/license/content/safety review, approval and staged publication.
- **E4 — Host adapter:** declarative renderer, approved UI contributions and typed backend APIs.
- **E5 — Grants:** installation-specific scoped grants, consent, revocation, audit and rate limits.
- **E6 — Marketplace:** developer portal, review console, listings, install/update/rollback and publisher analytics.
- **E7 — Executable extensions:** only after a separately approved isolation architecture and adversarial test suite.

## Acceptance criteria

- Invalid, unknown or over-broad declarations fail closed.
- Marketplace approval never silently grants tenant or user permissions.
- Every privileged backend call independently checks current grant, actor and resource scope.
- Revocation prevents new work and converges across connected hosts.
- Package digest, publisher identity, dependency and compatibility are verified from trusted records.
- Downloaded declarative content cannot invoke arbitrary host APIs or execute arbitrary code.
- Safety review accounts for physical-world impact, public visibility, jurisdiction and user disclosure.
- Audit records identify publisher, package digest/version, installation, actor, grant, target scope and decision.
