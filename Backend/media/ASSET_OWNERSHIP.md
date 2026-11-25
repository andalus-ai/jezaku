# Media asset ownership authorization

## Purpose

Commerce must not trust a client-supplied Media asset ID as proof that a merchant owns or may submit the asset. Media remains the authority for asset ownership, moderation, lifecycle and storage.

## Upload contract

Authenticated users upload assets through the existing Media upload flow. Merchant verification evidence uses:
- purpose: `merchant_evidence`
- allowed document type: `application/pdf`
- image evidence types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`
- the upload owner is derived from the authenticated user context by the Media API boundary.

An asset is attachable as merchant evidence only after upload completion, active lifecycle status and approved Media moderation. Pending, rejected, deleted, wrong-purpose or wrong-owner assets are denied.

## Internal authorization endpoint

`POST /media/internal/assets/{mediaId}/merchant-evidence-ownership-check`

Requires a service token carrying `commerce:media-ownership`. User tokens are refused. The caller supplies only:

```json
{ "expectedOwnerId": "authenticated-merchant-actor-id" }
```

The expected owner must be resolved by Commerce from its authenticated caller and active merchant membership; it must never be copied from an untrusted request body.

A successful response contains `authorized=true` plus purpose, content type, byte size, lifecycle and moderation status. A denied or missing asset returns `authorized=false` without revealing its owner, object key, URL, checksum or document bytes.

## Trust boundary and limitations

- Media performs the authoritative owner, purpose, lifecycle and moderation check.
- Commerce must call this endpoint server-to-server and fail closed on timeout, authentication failure, malformed response or denial.
- Commerce should persist only opaque media asset ID, evidence category, submitter, submission time and version metadata.
- No presigned URL or raw storage key is exposed by this ownership check.
- This endpoint does not upload, retrieve, scan or delete document contents.
- Production service tokens must be minted with the narrow `commerce:media-ownership` scope and protected by the shared service-secret management process.
- The endpoint is a policy primitive; it does not itself create a Commerce evidence record or review case.
