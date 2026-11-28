# Jezaku Admin Console

The operator-facing administration application for the Jezaku spatial experience platform.

## Status

The responsive Flutter console shell and first UI/UX refresh are implemented: Jezaku-branded navigation, desktop sidebar collapse, compact drawer navigation, overview dashboard hierarchy, honest unavailable-data states, light/dark theme switching, and global management-area search. Reusable management primitives now include a searchable/sortable/paginated responsive table, explicit feedback states, scoped destructive confirmation, and a tabbed detail scaffold. These are presentation components only; authentication, management APIs, live operational dashboards, and privileged workflows are not yet implemented. See the [Admin Console UI/UX specification](../../docs/ADMIN_CONSOLE_UI_UX.md). See the architecture and phased plan before adding features.

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

## Shared UI foundation

The Admin app uses Alhambra for platform-level foundations and JzDS (`jezaku_ds`) for shared Jezaku presentation components. Both dependencies are pinned to immutable Git commits. Keep Jezaku-specific navigation, domain workflows, and backend authorization in this app and the Quarkus services. See [Alhambra platform integration](../../docs/alhambra-platform-integration.md) and the [JzDS adoption guide](../docs/jzds-adoption.md).

## Development

Use the Flutter SDK compatible with the checked-in `pubspec.yaml`.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Do not add production credentials or endpoints to source. Authentication and API base URLs must be configured through the approved deployment mechanism.
