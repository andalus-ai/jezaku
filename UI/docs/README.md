# UI Documentation

- [AR Device Demo Lab](ar-device-demo-lab.md) — offline-first physical-device testing workflow for AR runtime, placement, photo frames, snapshots and recording.
- [Frame visibility and AR frames roadmap](frame-visibility-and-roadmap.md) — who may see a frame, the 20 m physical radius, the central rule namespace, and the ordered roadmap.
- [Sign-in](sign-in.md) — the client sign-in seam: required in production builds with an identity service, bypassed in demo builds.
- [Frame styles](frame-styles.md) — the frame gallery: built-in looks, default frame in Settings, changing a published frame, and how it maps to the platform's appearance contract.
- [AR frame persistence plan](ar-frame-persistence-plan.md) — why frames only hang within one AR session, what the ar-core backend can and cannot do, and the staged plan.


This directory documents the Flutter client, main application, reusable Dart packages, and shared UI/UX standards.

## Documents

- [Architecture](architecture.md) — app/package boundaries, feature structure, state, networking, AR integration, and data flow.
- [Application structure](app-structure.md) — actual Flutter app layout and code ownership.
- [Feature catalog](feature-catalog.md) — current app feature directories, responsibilities, and boundaries.
- [Reusable package catalog](package-catalog.md) — responsibilities, dependency direction, and public contract expectations for packages.
- [Design system and UX standards](design-system-and-ux.md) — visual foundations, accessibility, interaction states, and polish criteria.
- [Quality gates](quality-gates.md) — accessibility, responsive layout, privacy, hardware, performance, and release validation checklist.

## Scoped instructions

- [UI-wide instructions](../AGENTS.md)
- [Flutter app instructions](../jezaku/AGENTS.md)
- [Reusable package instructions](../Packages/AGENTS.md)

## Related documentation

- [Product UI/UX polish plan](../../docs/UI_UX_POLISH_PLAN.md)
- [AR viewer performance budgets](../../docs/AR_VIEWER_PERFORMANCE_BUDGETS.md)
- [AR device validation](../../docs/AR_DEVICE_VALIDATION_V1.md)

Keep these documents aligned with the implementation. Update the relevant document whenever a boundary, workflow, public package contract, design rule, or validation command changes.
