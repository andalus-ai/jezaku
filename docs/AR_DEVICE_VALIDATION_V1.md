# AR Device Validation v1 (Android-first)

## Purpose

This runbook defines the first repeatable, physical-device validation pass for Jezaku's AR experience. It complements the existing `ar_engine_testkit` integration tests; it does not replace them.

The first goal is to establish whether the current Flutter-to-native AR path behaves reliably on real Android hardware before expanding the SLAM roadmap.

## Scope

In scope:

- Android camera permission and session lifecycle.
- Native AR capability/configuration resolution.
- Camera preview and first-frame readiness.
- Horizontal/vertical plane detection where supported.
- Anchor placement, tracking, and session teardown.
- App background/foreground behavior.
- Runtime diagnostics export and reproducible defect reports.

Out of scope for this pass:

- Claiming cross-session world-map persistence unless the active native provider explicitly supports it.
- Claiming shared/cross-device anchors.
- Benchmarking production SLAM accuracy from synthetic fixtures.
- Enabling unsupported ARCore capabilities through UI flags.

## 1. Build and test baseline

Run from the repository root:

```bash
cd UI/jezaku
flutter pub get
flutter analyze
flutter test
flutter test integration_test/ar_engine_integration_test.dart
```

Record the Flutter version, Dart version, Android SDK version, device model, Android version, and app commit SHA with the test results.

The integration test currently uses `ArEngineTestHarness`. A passing result verifies the public integration contract against the test platform; it is not evidence that a physical device's camera, sensors, or ARCore runtime works.

## 2. Physical-device prerequisites

- A physical Android device; do not use an emulator as the acceptance device.
- Google Play Services for AR / ARCore installed and updated when required by the device.
- Camera permission granted.
- Location permission granted only for geospatial scenarios.
- Device date/time set automatically.
- Adequate lighting and a textured environment for tracking tests.
- Battery above 30%; remove thermal/battery saver constraints for baseline runs.
- Network available for capability/service checks, then repeat offline-capable scenarios with network disabled.

Test at least one mid-range supported Android device first. Add a higher-end device as a comparison, not as the only acceptance device.

## 3. Test protocol

For each test, capture the device model, app SHA, result, elapsed time, and exported AR diagnostics bundle when available.

| ID | Scenario | Procedure | Pass criteria |
| --- | --- | --- | --- |
| AND-AR-01 | Permission denied | Deny camera permission, open AR viewer, then retry after granting permission in system settings. | Clear permission state; no crash; retry starts a fresh session. |
| AND-AR-02 | Cold start | Force-stop app, launch, open AR viewer. Repeat five times. | Camera/session initializes without crash in all five attempts; startup timing recorded. |
| AND-AR-03 | First frame | Open viewer in a well-lit textured room. | Camera preview appears and runtime health stops reporting missing/stale frames. |
| AND-AR-04 | Plane detection | Slowly scan floor and a wall for 20 seconds. | Supported plane types become visible/reported; unsupported capabilities are reported honestly. |
| AND-AR-05 | Anchor placement | Place one test object on a detected horizontal plane. Walk around it slowly. | Object remains attached to the selected anchor during the same session; no unexplained jump. |
| AND-AR-06 | Tracking interruption | Cover the camera for 3–5 seconds, uncover it, and scan the environment. | Tracking state changes are visible; recovery or explicit relocalization-required state is reported; no false success. |
| AND-AR-07 | Background/foreground | Send app to background for 10 seconds, return to viewer. | No stale native controller is reused; session resumes or is recreated with a visible state transition. |
| AND-AR-08 | Repeated lifecycle | Enter/exit AR viewer ten times. | No crash, duplicate camera ownership, or steadily increasing resource usage. |
| AND-AR-09 | Permission revoked | Revoke camera permission while app is stopped, then reopen. | Permission is rechecked; app gives a recoverable explanation. |
| AND-AR-10 | Network loss | Start viewer, disable network, continue local plane/anchor interaction. | Local AR remains usable where native provider permits; network-dependent features show a clear degraded state. |
| AND-AR-11 | Thermal/battery | Run a 15-minute continuous session. | No crash; record FPS, thermal state, battery change, and tracking interruptions. |
| AND-AR-12 | Diagnostics export | Reproduce one warning and export the diagnostics bundle. | Bundle contains app/device context and relevant AR timeline without secrets or precise location unless explicitly consented. |

## 4. Measurements to record

Do not treat proposed targets as current performance claims. Establish a baseline first.

Record:

- Time from opening viewer to camera preview.
- Time to first valid AR frame.
- Time to first tracked plane.
- Render FPS and frame-time percentiles, if exposed by the runtime.
- Tracking state transitions and total tracking-loss duration.
- Anchor count and tracked-anchor count.
- Native session creation/destruction counts, where available.
- Memory and battery at start and end.
- Device thermal state.
- Crash, ANR, and plugin/platform exceptions.

After collecting at least three repeat runs per scenario, define device-class targets from observed data. Use a 30 FPS rendering target only where the device/runtime configuration supports it.

## 5. Defect report template

Copy this template into a GitHub issue for each reproducible failure:

```text
## Summary
[One sentence]

## Environment
- Device/model:
- Android version:
- App commit SHA:
- Flutter/Dart version:
- ARCore / Google Play Services for AR version:
- Build mode:

## Reproduction
1.
2.
3.

## Expected
[Expected behavior]

## Actual
[Observed behavior]

## Frequency
[ x / y runs ]

## Measurements
- Camera startup:
- First frame:
- Tracking loss duration:
- FPS/frame time:
- Thermal/battery:
- Anchor count:

## Diagnostics
[Attach exported bundle; redact personal data]

## Severity
[Blocker / High / Medium / Low]
```

## 6. Exit criteria

The Android AR v1 device-validation milestone is complete when:

- All applicable AND-AR-01 through AND-AR-12 scenarios have recorded results.
- No reproducible crash or camera/session ownership leak remains in the core flow.
- Unsupported device capabilities are surfaced instead of silently treated as available.
- Tracking interruption and recovery states are observable.
- At least one mid-range physical Android device completes the core camera → plane → anchor → walk-around flow.
- Known limitations and device-specific failures are documented.
- A baseline diagnostics bundle can be attached to a GitHub issue.

## 7. Follow-up engineering order

Use the physical-device findings to select the next code changes. Expected candidates:

1. Fix camera/session lifecycle defects found in AND-AR-01 through AND-AR-09.
2. Improve tracking-state propagation and runtime health reporting.
3. Add missing device/runtime telemetry.
4. Improve anchor persistence only after confirming the provider's persistence contract.
5. Evaluate relocalization and map recovery using recorded real-device sequences.

Do not start loop closure or advanced map optimization solely because they appear on a roadmap. First establish repeatable real-device evidence that the current tracking pipeline is the limiting factor.
