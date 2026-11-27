# Jezaku Extensions Backend Module

Backend-owned validation primitives for extension package declarations.

## Current scope

- Versioned capability allowlist in `ExtensionCapabilityCatalog`.
- Security-relevant manifest v1.0.0 checks in `ExtensionManifestValidator`.
- SHA-256 calculation and constant-time digest comparison in `ArtifactDigestVerifier`.
- Unit tests for accepted declarations, unknown capabilities, undeclared permissions, invalid scopes, invalid impact classifications, malformed JSON and artifact tampering.

## Important boundary

This module is a domain validation foundation, not yet a runnable marketplace service. It has no upload endpoint, artifact store, publisher identity workflow, signature trust store, installation records, approval workflow or runtime grants.

Manifest validation currently enforces the security-critical semantic subset documented by the extension contract. The JSON Schema remains the full structural declaration contract; complete schema-engine parity, including all nested constraints and unknown-property rejection, is a follow-up before accepting public uploads.

A successful validation result means only that the declaration passed these checks. It does **not** mean the publisher is trusted, the artifact is signed, the package is approved, the extension is installed, or any capability is authorized.

## Build

From `Backend/`:

```bash
./mvnw -B -pl extensions -am test
```

## Next work

1. Add complete JSON Schema validation and schema-version pinning.
2. Add publisher key verification and signed release metadata.
3. Add bounded streaming artifact ingestion and immutable storage.
4. Add compatibility/dependency resolution against trusted registry records.
5. Add durable review, install and grant lifecycle only after identity and audit boundaries are ready.
