# Jezaku Security, Privacy, Safety, and Governance

> Cross-cutting requirements. This document supplements docs/AGENTS.md and scoped engineering instructions.

## Objectives
Jezaku overlays digital information on the physical world. It must not encourage unsafe movement, trespass, obstruction, interference with property, or reliance on unverified directions. Safety restrictions take precedence over discovery ranking, advertising, creator preferences, and rendering.

## Sensitive data
Treat precise/historical location, camera images/video, sensor/pose data, identity/social graph/private content, device identifiers/movement patterns, merchant redemption data, and privileged authority actions as sensitive. Minimize collection, precision, retention, access, and logging. Explain permissions in context.

## Access and tenant isolation
Enforce access server-side on every read/write/feed/search/batch/derived representation. Separate owner, publisher, tenant, viewer, and authority roles. Verify role and jurisdiction for privileged restrictions. Tenant ID and visibility labels are not authorization. Preserve frame sharing, moderation, and physical-radius rules.

## Spatial Safety Policy
Evaluate before discovery ranking, navigation presentation, rendering, and advertising:
- ALLOWED: proceed subject to other policies.
- CAUTION: warn clearly and apply constraints.
- RESTRICTED: only explicitly authorized actions/content.
- PROHIBITED: suppress affected experience or route.
- EMERGENCY_LOCKDOWN: suspend affected activity within defined scope.

Consider geometry, time, altitude where available, affected activity/content, user/device context, provenance, freshness, and confidence.

## Authority governance
Only authenticated and authorized principals may create restrictions within verified jurisdiction/property authority. Record issuer, scope, geometry, provenance, effective/expiry times, version, audit history, and revocation. Support review, correction, rollback, and appeals where appropriate. Emergency activation must be fast, authenticated, scoped, logged, and reviewed. Uncertain critical restrictions fail safely.

## Physical-world safety
Do not encourage use while driving or operating machinery. Avoid requiring users to walk while staring at a screen. Provide audio/haptic/non-AR alternatives where suitable. Suppress distracting content in movement-critical contexts. Do not route through hazards, restricted property, or unverified shortcuts. Communicate uncertainty and never imply a safety guarantee. Respect property rights, law, camera restrictions, and public authority.

## Advertising privacy
Proximity advertising is opt-in and preference-controlled. Apply frequency caps, merchant verification, category restrictions, sensitive-location suppression, and paid-placement disclosure. Avoid continuous tracking where on-device/coarse eligibility suffices.
Offer expiry is server-authoritative. Distinguish offer expiry, eligibility window, arrival deadline, and redemption expiry. Client GPS and local timers alone are not proof of arrival or redemption.

## Extension and marketplace security
Least-privilege capabilities; signed packages; declarative content preferred; sandbox untrusted execution; resource limits and host API allowlists; dependency scanning; moderation/reporting/suspension/revocation; license/provenance checks. Marketplace approval is not runtime permission.

## Moderation and reliability
Support reports, review queues, emergency takedown, repeat-offender controls, appeal/correction, and audit. Moderation state must propagate to discovery, caches, and clients. If critical authorization, safety, consent, localization confidence, or restriction freshness cannot be established, suppress or degrade the experience.

## Required validation
Unauthorized/cross-tenant tests; private-data leakage tests; policy precedence tests; stale/uncertain location and tracking tests; abuse/rate-limit/replay tests; revocation/cache invalidation tests; accessibility and non-AR fallback; physical-device validation for sensor-dependent behavior.
