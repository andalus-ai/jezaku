# Jezaku Extensions Backend Module

Backend-owned validation primitives for extension package declarations.

## Current scope

- Versioned backend capability allowlist in `ExtensionCapabilityCatalog`.
- Full structural validation of manifest v1.0.0 using the checked-in JSON Schema (JSON Schema Draft 2020-12).
- Additional semantic checks that bind requested permissions to known, declared capabilities.
- Explicit reporting of high-risk requested capabilities for human review; reporting is not approval or a grant.
- SHA-256 calculation and constant-time digest comparison in `ArtifactDigestVerifier`.
- Tests for schema constraints, unknown capabilities, undeclared permissions, invalid scopes, invalid impact classifications, malformed/trailing JSON and high-risk capability reporting.

The schema is loaded from the repository's canonical `schemas/jezaku-extension-manifest.schema.json` file as a module resource; there is no separately maintained schema copy.

## Important boundary

This module is a domain validation foundation, not yet a runnable marketplace service. It has no upload endpoint, artifact store, publisher identity workflow, signature trust store, installation records, approval workflow or runtime grants.

A successful validation result means only that the declaration passed structural and semantic checks. `highRiskCapabilities` is a review signal, not an approval decision. It does **not** mean the publisher is trusted, the artifact is signed, the package is approved, the extension is installed, or any capability is authorized.

## Build

From `Backend/`:

```bash
./mvnw -B -pl extensions -am test
```

## Next work

1. Add publisher key verification and signed release metadata.
2. Add bounded streaming artifact ingestion and immutable storage.
3. Add compatibility/dependency resolution against trusted registry records.
4. Add durable review, install and grant lifecycle only after identity and audit boundaries are ready.
