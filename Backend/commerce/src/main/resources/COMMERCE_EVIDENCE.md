# Merchant verification evidence

Commerce accepts an opaque Media asset ID and an evidence category. It does not accept an owner ID, moderation claim, storage URL, checksum, or document bytes from the caller.

## Submission flow

1. Commerce resolves the caller from the verified user token.
2. Commerce requires an active OWNER or ADMIN membership and a merchant in PENDING_VERIFICATION.
3. Commerce calls Media's internal ownership endpoint using a service token scoped only to commerce:media-ownership. The expected owner is the authenticated actor, never a request field.
4. Media remains authoritative for exact asset ownership, merchant_evidence purpose, active lifecycle, and approved moderation.
5. Commerce stores only the opaque media ID, category, authenticated submitter, review-case reference, timestamps, status and version. The V5 evidence table enforces one attachment per asset per review case.

Media unavailability, a non-200 response, malformed response, missing configuration, or an ineligible asset fails closed. The remote call is made before the database transaction. Commerce never downloads the document or stores a Media URL/object key.

## Configuration

Set jezaku.media.base-url to the internal Media service origin. Configure Commerce outbound service identity with service name commerce, the shared trusted service-token verification secret, and scope commerce:media-ownership. Do not configure Media to mint this scope.

## API

- POST /commerce/merchants/{merchantId}/verification/evidence
  - body: {"mediaAssetId":"...","category":"BUSINESS_REGISTRATION"}
- GET /commerce/merchants/{merchantId}/verification/evidence

Only active merchant owners and administrators can submit or list evidence.
