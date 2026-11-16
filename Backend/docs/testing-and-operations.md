# Backend Testing and Operations Guide

This guide documents the current Maven/Quarkus development workflow and the validation expected when changing services. The module POMs, scripts, and runtime configuration are authoritative.

## Repository model

- `Backend/pom.xml` is the Maven reactor/aggregator.
- Runnable services are independent modules; `common` is a shared library, not a runnable service.
- Local service ports and OpenAPI/Swagger URLs are listed in [service-ports.md](../service-ports.md).
- Service ownership and endpoint inventory are listed in [service-catalog.md](service-catalog.md).

## Local prerequisites

Use the Java and Maven versions declared or required by the repository's build configuration. Prefer the checked-in Maven wrapper when present. Confirm any required databases, message brokers, object storage, or external services from the target module's configuration before running it; do not assume an infrastructure dependency is available.

## Build and test

From the repository root, the backend reactor can be verified with:

```bash
mvn -f Backend/pom.xml test
```

If a Maven wrapper is available and executable, prefer:

```bash
./Backend/mvnw -f Backend/pom.xml test
```

For a focused service module, include required upstream modules:

```bash
mvn -f Backend/pom.xml -pl <module> -am test
```

For a full verification build, use:

```bash
mvn -f Backend/pom.xml verify
```

Run the command appropriate to the change and environment. Do not describe a test as passing unless its process completed successfully.

## Service smoke checks

1. Start only the service(s) required for the scenario, using the module's documented Quarkus command.
2. Confirm the service's health endpoint and the expected local port.
3. Inspect `/q/openapi` and `/q/swagger-ui` for the actual running service contract.
4. Exercise a representative success path and relevant negative/authorization paths.
5. Check request ID propagation and ensure error responses do not disclose internal details.
6. Stop local services and supporting infrastructure after validation.

Use existing scripts under `Backend/scripts/` where they cover the changed workflow. Read the script before executing it and supply credentials only through environment variables; never put real credentials in shell history or documentation.

## Contract and integration validation

For endpoint changes, verify:
- request/response DTO shape and validation;
- HTTP status and stable error code;
- authentication and per-resource authorization;
- pagination/filter bounds and deterministic ordering;
- visibility behavior for list, detail, feed, search, map/minimap, and realtime projections as applicable;
- idempotency and duplicate delivery for state-changing/event-driven flows;
- compatibility with UI consumers.

For cross-service changes, test the owning service and each directly affected consumer. Update service catalog, ports, OpenAPI/API documentation, and UI integration docs when public contracts or operational settings change.

## Operational safety

- Keep configuration externalized and use placeholders in checked-in examples.
- Do not log tokens, precise coordinates, private media URLs, message bodies, or personal data.
- Make schema and event evolution compatible with rolling deployment where possible.
- Document migration order, rollback expectations, retry behavior, and degraded-mode behavior for infrastructure-dependent changes.
- Do not imply production readiness from local in-memory tests or a successful compile alone.
