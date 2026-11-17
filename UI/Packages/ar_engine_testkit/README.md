# ar_engine_testkit

**ar_engine_testkit** is a test-only package containing deterministic fakes for consumers of **ar_engine**. It is not a runtime adapter and must not be imported by production application code.

## Responsibility and non-goals

It provides **TestArEnginePlatform**, an in-memory **ArEnginePlatform**; **ArEngineTestHarness**, which installs that fake as global **ArEnginePlatform.instance**, creates controllers and restores the previous platform; request/stream recording; synthetic IDs; async gates; injected errors; and **testCamera()**.

It does not emulate ARCore/ARKit/WebXR, render a camera view, request OS permissions, reproduce sensor noise, or prove native resource behavior.

## Public API and dependency direction

~~~dart
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
~~~

The barrel exports **ArEngineTestHarness**, **TestArEnginePlatform**, **TestArEngineNodeIdFactory**, and **testCamera()**. Its only non-SDK runtime package dependency is the local **ar_engine** package; Flutter is also declared as an SDK dependency. **publish_to: none** is set. **ar_engine** must not depend on this package; **jezaku_ar** and the app use it only as a **dev_dependency**.

## Default fake behavior

A default **TestArEnginePlatform** reports AR, world tracking, planes, hit testing, light estimates, snapshot capture and recording encode as supported. It does not automatically enable image tracking, depth, occlusion, body tracking, geospatial tracking or cloud anchors.

Operations record inputs and update in-memory anchor/node maps. Geospatial calls use the generic local projection fallback. Cloud-anchor responses are controlled by **hostedCloudIds** and **resolvedCloudAnchors**; no network service is called.

Optional **Completer<void>** gates pause selected operations until the test releases them. Error fields inject deterministic exceptions. Stream helpers publish camera, plane, anchor and light samples.

## Correct use

Install/restore the harness around each test and dispose controllers before restoring the global platform:

~~~dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';

void main() {
  test('controller can be exercised without native AR', () async {
    final harness = ArEngineTestHarness.install();
    try {
      final controller = await harness.createController();
      try {
        final hits = await controller.hitTest(0.5, 0.5);
        expect(hits, isEmpty);
        harness.platform.emitCamera(testCamera());
      } finally {
        await controller.dispose();
      }
    } finally {
      harness.restore();
    }
  });
}
~~~

For capability-resolution tests use **harness.createResolvedController(config)** and assert both resolved config and **configResolution**. To test a race, pass a **Completer<void>** such as **addNodeGate** or **initSessionGate**, await its corresponding **\*Started** completer, then release the gate.

**restore()** only restores the global platform reference. It does not dispose controllers or close streams. By default **destroySession()** closes fake streams; set **closeStreamsOnDestroy: false** only when the test will explicitly call **platform.close()**.

Because **ArEnginePlatform.instance** is process-global, do not run tests installing different harnesses concurrently in the same isolate. Always restore in **finally**/teardown.

## Platforms, lifecycle, and errors

There are no native platform folders or hardware requirements. It runs in Flutter unit/widget tests on the Dart VM. It tests consumer behavior against a fake contract, not native plugin registration or platform-specific camera/AR lifecycle.

Injected errors are rethrown by the fake; invalid controller use can still produce the engine's own **StateError**/argument exceptions. A passing fake test does not establish that a native backend implements the same feature or error code.

## Test coverage and gaps

One test file covers harness installation/restoration, controller lifecycle/cleanup, capability-resolved sessions, local geospatial fallback, operation gates and stale async paths. It does not test native adapters, rendering, hardware permissions, WebXR or real AR devices.

See the [ar_engine README](../ar_engine/README.md) and [UI package catalog](../../docs/package-catalog.md).
