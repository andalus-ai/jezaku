# Backend Documentation

This directory describes the Quarkus multi-module backend, service boundaries, contracts, security requirements, and development validation.

## Documents

- [Architecture](architecture.md) — module topology, service boundaries, request flow, shared platform, data and event principles.
- [Service catalog](service-catalog.md) — service ownership, responsibilities, local ports, and API entry points.
- [API and integration conventions](api-conventions.md) — HTTP contracts, errors, validation, security, pagination, and cross-service changes.
- [Security and privacy](security-and-privacy.md) — authorization, sensitive data handling, media, location, and review checklist.
- [Testing and operations](testing-and-operations.md) — Maven validation, local smoke checks, contract testing, and operational safety.

## Related documentation

- [Backend agent instructions](../AGENTS.md)
- [Backend overview and endpoint inventory](../README.md)
- [Local service ports and OpenAPI links](../service-ports.md)
- [Repository-level architecture](../../docs/architecture.md)
- [Repository-wide agent instructions](../../AGENTS.md)

Update the relevant document whenever a service boundary, endpoint contract, local port, security rule, or operational workflow changes.
