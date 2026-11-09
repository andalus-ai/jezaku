# ar_engine_testkit

Deterministic test helpers for `ar_engine` apps and higher-level AR packages.

The package provides `TestArEnginePlatform`, a reusable in-memory
`ArEnginePlatform`, plus `ArEngineTestHarness` for installing it during a test
and restoring the original backend afterwards.

```dart
final harness = ArEngineTestHarness.install();
addTearDown(harness.restore);

final controller = await harness.createController(
  const ARSessionConfig(cloudAnchorsEnabled: true),
);

harness.platform.hostedCloudIds['anchor_0'] = 'cloud_memory';
```

Use the platform maps and request logs to assert anchors, nodes, cloud-anchor
calls, geospatial fallback, depth sampling, hit tests, snapshots, recording
encoding, and lifecycle behavior without native AR hardware.

For race-condition tests, pass gate completers such as `initSessionGate`,
`hitTestGate`, `addNodeGate`, `reconfigureGate`, or `snapshotGate` to hold a
native call in flight. Failure hooks such as `getDesktopTextureIdError`,
`pauseSessionError`, `resumeSessionError`, and `encodeRecordingError` let widget
and app tests exercise native error paths deterministically.
