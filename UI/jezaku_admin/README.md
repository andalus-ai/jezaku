# Jezaku Admin Console

The operator-facing administration application for the Jezaku spatial experience platform.

## Status

This directory currently contains a Flutter starter application. The production admin console, authentication integration, management APIs, and operational dashboards are not yet implemented. See the architecture and phased plan before adding features.

## Responsibilities

- Provide a secure, responsive operator interface.
- Present only capabilities the signed-in operator is authorized to use.
- Call the existing domain-owning backend services through documented contracts.
- Make privileged operations explicit, scoped, reasoned, and auditable.
- Keep private location, camera media, messages, identity and family data minimized and protected.

The console is not a source of domain truth and must not access service databases directly.

## Documentation

- [Admin console architecture](../../docs/admin-console-architecture.md)
- [Admin implementation plan](../../docs/admin-console-implementation-plan.md)
- [App-specific engineering instructions](AGENTS.md)
- [UI architecture](../docs/architecture.md)
- [Backend service catalog](../../Backend/docs/service-catalog.md)

## Development

Use the Flutter SDK compatible with the checked-in `pubspec.yaml`.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Do not add production credentials or endpoints to source. Authentication and API base URLs must be configured through the approved deployment mechanism.
