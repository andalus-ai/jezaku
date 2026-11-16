# UI Quality Gates and Release Validation

Use this checklist for feature work and release candidates. It complements [design-system-and-ux.md](design-system-and-ux.md), [architecture.md](architecture.md), and the repository's [UI/UX polish plan](../../docs/UI_UX_POLISH_PLAN.md).

## 1. Interaction and state coverage

For each affected screen or component, verify the states that apply:

- [ ] Initial/loading state does not cause avoidable layout jumps.
- [ ] Empty state explains what is absent and offers an appropriate next step.
- [ ] Error state is understandable, preserves user input, and offers a safe retry when possible.
- [ ] Offline/stale state distinguishes cached data from confirmed server state.
- [ ] Permission denied/restricted state explains the impact and recovery path.
- [ ] Partial capability state allows supported work to continue without overstating capability.
- [ ] Success and pending states are distinguishable.
- [ ] Disabled actions have an understandable reason when the reason is not obvious.
- [ ] Destructive or visibility-changing actions make consequences clear before confirmation.

Do not add meaningless placeholder states to components that cannot encounter them; document which states are relevant.

## 2. Accessibility

- [ ] Interactive controls expose meaningful semantic labels and roles.
- [ ] Images and icons that convey information have alternatives; decorative visuals are excluded from focus/announcement.
- [ ] Screen-reader focus order follows the visual and task order.
- [ ] Important asynchronous updates are announced without repeatedly interrupting users.
- [ ] Text scaling does not clip primary actions, dialogs, or essential status information.
- [ ] Contrast is sufficient in light/dark themes and over map/camera backgrounds.
- [ ] Color is not the sole carrier of status, privacy, selection, or error meaning.
- [ ] Touch targets are large enough and do not overlap.
- [ ] Motion has a reduced-motion or non-animated alternative where appropriate.
- [ ] Keyboard/focus behavior is usable on supported desktop/web targets.

Validate with Flutter semantics/widget tests and platform accessibility inspection where available. A semantics tree test does not replace testing with a screen reader on a real target platform.

## 3. Responsive layout

Test the relevant screen classes rather than relying on one emulator size:

| Scenario | Validate |
| --- | --- |
| Compact phone | No overflow; primary actions remain reachable |
| Large phone | Content hierarchy and touch reach remain intentional |
| Landscape | Camera/map controls remain visible; sheets and dialogs fit |
| Tablet/wide layout | Content width, navigation, and map/list composition use space deliberately |
| Large text scale | Labels and actions remain available without clipping |
| Keyboard visible | Inputs, submit actions, and scroll behavior remain usable |

Record device, OS, viewport, text scale, and any known exclusions for release-critical journeys.

## 4. Camera, location, and AR

- [ ] Camera permission is requested in context and can be recovered after denial.
- [ ] Camera initialization failure and device contention are handled.
- [ ] Location unavailable, approximate, stale, and denied states are distinct where relevant.
- [ ] Heading/sensor unavailability does not silently produce misleading orientation.
- [ ] AR unsupported, session-start failure, tracking limited, and tracking lost states are handled.
- [ ] Anchor confidence/quality is not presented as certainty.
- [ ] App pause/resume and navigation away release or restore resources safely.
- [ ] Capture and pending upload state survive transient network failure.
- [ ] Hardware validation includes supported representative devices, not only simulator/emulator.

Follow [AR device validation](../../docs/AR_DEVICE_VALIDATION_V1.md) and [AR viewer performance budgets](../../docs/AR_VIEWER_PERFORMANCE_BUDGETS.md) for AR-specific checks.

## 5. Privacy and safety

- [ ] Audience/visibility is clear before publishing or changing scope.
- [ ] Exact location is not exposed beyond the intended audience and precision.
- [ ] Private media/content is not leaked through thumbnails, previews, cached views, or share flows.
- [ ] Block/report/mute and guardian controls remain discoverable where relevant.
- [ ] UI state does not imply authorization; the backend remains authoritative.
- [ ] Logs, analytics, screenshots, and test fixtures do not contain tokens or real sensitive user data.

## 6. Performance and resilience

- [ ] Scrolling and transitions remain responsive on a representative mid-range device.
- [ ] Large images/models are loaded and released deliberately.
- [ ] Camera/AR overlays do not introduce avoidable frame drops.
- [ ] Network requests have bounded timeouts and visible pending/error behavior.
- [ ] Retry behavior is bounded and does not duplicate writes.
- [ ] Long-running subscriptions, timers, streams, and controllers are disposed.
- [ ] Offline queues preserve pending content and expose actionable failure states.

## 7. Automated validation

Run from `UI/jezaku/`:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

For package changes, also run formatting, analysis, and tests from each affected package. Run relevant integration tests on the target platforms when configured.

## 8. Evidence and sign-off

For each release-critical change, record:
- commit or pull request;
- affected screens/features and platforms;
- commands executed and pass/fail results;
- viewport/device/OS and accessibility checks performed;
- hardware checks performed or still required;
- known limitations, risks, and rollback considerations.

Never mark a gate as passed based solely on a planned test, a successful compile, or an emulator result for hardware-dependent behavior.
