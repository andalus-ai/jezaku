# Backend Security and Privacy Practices

This document complements [Backend agent instructions](../AGENTS.md), [architecture](architecture.md), and [API conventions](api-conventions.md). It records cross-service requirements; each service remains responsible for enforcing them on its own endpoints and data paths.

## Security boundaries

- Authenticate callers at the API boundary using the project's configured identity/session mechanism.
- Authorize every read and write in the owning service. A valid session does not imply access to every resource.
- Treat client-provided user IDs, roles, audience scopes, ownership flags, coordinates, and moderation states as untrusted input.
- Enforce block, relationship, family/guardian, audience, moderation, and visibility rules server-side for direct reads and derived representations alike.
- Keep service-to-service access explicit and least-privileged. Do not use direct access to another service's persistence as an integration mechanism.

## Sensitive data

Jezaku can process account identifiers, precise location and movement, camera media, private memories, social relationships, messages, guardian/family relationships, and safety reports.

For each field and endpoint:

1. Collect only what the use case requires.
2. Return only fields the caller is authorized to see.
3. Avoid copying sensitive data into logs, metrics labels, traces, exception messages, or test snapshots.
4. Define retention, deletion, and access behavior with the owning domain.
5. Use synthetic fixtures and placeholder secrets in examples and tests.

Never log passwords, access/refresh tokens, signed media URLs, private message bodies, precise coordinates, or raw identity/guardian data.

## API protections

- Validate path/query/body values, coordinate ranges, timestamps, pagination, content types, and payload sizes at the boundary.
- Use parameterized persistence operations.
- Apply rate limits and abuse controls to authentication, messaging, discovery, uploads, reporting, and other abuse-prone operations as the infrastructure supports them.
- Make state-changing operations safe against duplicate requests where appropriate.
- Return stable error codes and request IDs without exposing stack traces, SQL, internal hostnames, secrets, or topology.
- Ensure caches and derived projections preserve authorization scope; do not share a response across callers with different visibility.

## Media and user-generated content

- Treat uploaded media as untrusted until validation and moderation requirements are satisfied.
- Validate upload metadata and ownership; do not trust client-supplied moderation or publication flags.
- Keep private media inaccessible through guessed IDs, thumbnails, minimaps, feeds, exports, or alternate endpoints.
- Ensure moderation and deletion state propagates to every representation and cache.
- Avoid persisting signed URLs longer than necessary; keep signing credentials server-side.

## Location and spatial privacy

- Apply visibility policy before returning nearby users, memories, trails, events, minimap dots, or spatial search results.
- Avoid returning more coordinate precision than the use case requires.
- Enforce location freshness/expiry and consent/visibility scope consistently across list, detail, feed, and realtime endpoints.
- Do not infer that an item is public because it appears in a client cache or seed dataset.

## Security review checklist

For a change touching sensitive data or access control, add tests for:
- unauthenticated and unauthorized callers;
- owner versus non-owner access;
- private, friends-only, and public scopes where applicable;
- blocked relationships and guardian restrictions where applicable;
- list/detail/search/feed/minimap/realtime consistency;
- deleted, expired, moderated, and stale records;
- malformed, oversized, and replayed requests.

Record unresolved risks and infrastructure-dependent controls explicitly. This document is not a claim that a particular auth provider, encryption scheme, rate limiter, or retention system is already deployed; verify actual configuration before making such claims.
