# Discovery service

Discovery owns ranked, location-aware retrieval of public Jezaku targets. It does not own merchant identity, offer inventory, campaign billing, or redemption.

## Target contract

The shared target taxonomy in `common` identifies `merchant` and `offer` as discoverable and reportable target types. They are deliberately not added to the engageable set until merchant/offer interaction ownership and authorization are implemented. Their domain records remain owned by the future commerce/merchant domain; Discovery should consume a bounded read model or explicit integration contract rather than reaching into another service's persistence.

A merchant discovery candidate must provide:
- Stable merchant/store target identity and verified publisher/merchant reference.
- Server-managed physical placement coordinate and coordinate provenance.
- Visibility/discoverability status and moderation state.
- Public display metadata and a safe thumbnail/creative reference.
- Optional distance, schedule, availability, and offer references.

An offer candidate must additionally resolve to an authoritative merchant, campaign, and promotion record. Discovery must not treat client-supplied offer text, discount amount, countdown, or eligibility as authoritative.

## Spatial safety enforcement

All candidate results returned by `nearby`, `search`, `trending`, and `for-you` pass through `DiscoverySpatialSafety` before becoming response DTOs. The HTTP adapter sends a bounded batch (maximum 500) to Safety using activity `DISCOVER`.

- `ALLOWED`: candidate may be returned.
- `CAUTION`: candidate may be returned with `safetyOutcome=CAUTION`; clients must present the relevant caution state and must not imply the location is safe.
- `RESTRICTED`, `PROHIBITED`, `EMERGENCY_LOCKDOWN`: candidate is omitted.
- Missing, malformed, incomplete, unknown, or unavailable policy results fail closed with HTTP 503.

Candidate coordinates must come from the authoritative server-side merchant/store placement read model, not from query parameters or a client-provided candidate payload. Query coordinates identify the viewer's search origin only; they do not replace the candidate's stored location for policy evaluation.

Discovery currently evaluates its existing in-memory catalog. The taxonomy change is an extension point only: it does not claim that a merchant registry, offer inventory, campaign-to-store association, or production ingestion pipeline exists yet.

## Boundary with social advertisements

The existing Social monetization campaign model is graph/audience-based and has no authoritative merchant placement coordinate. A campaign's `camera` or `minimap` presentation label is not proof that it is a proximity advertisement. Do not apply merchant-location policy to a graph ad based on the viewer's location alone.

A future location-aware ad must resolve a verified merchant placement and campaign/offer eligibility first, then apply:
1. `DISCOVER` at the authoritative merchant placement before selecting a proximity candidate.
2. `RENDER` at the current render context before exposing its creative in AR.
3. Consent, audience, schedule, frequency-cap, moderation, merchant availability, and paid-content disclosure checks.
4. Server-authoritative eligibility and redemption validation at redemption time.

If either spatial evaluation is denied, the proximity ad must not be delivered/rendered. If critical policy cannot be evaluated, fail closed. Keep non-spatial social ads on their existing separate delivery path.

## Privacy and anti-spoofing

- Minimize precise viewer-location retention and do not log raw coordinates.
- Clearly disclose and obtain consent for location-based advertising where required.
- Do not expose restricted merchant coordinates or private location metadata in denial responses.
- A client-reported viewer coordinate is not hardware-attested. It can support proximity relevance but must not be treated as proof of arrival or redemption eligibility.
- Use a trusted location/arrival signal and server-side checks for promotions that require physical presence.

## Validation

Run focused tests from `Backend/`:

```bash
./mvnw -pl common,discovery -am test
```

The shared taxonomy tests protect the target contract; Discovery spatial-safety tests protect fail-closed filtering and outcome propagation.
