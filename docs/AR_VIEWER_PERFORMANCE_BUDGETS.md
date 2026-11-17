# AR Viewer Performance Budgets

This document defines a repeatable manual stress profile for the Flutter AR
Viewer. It complements the debug-only `[ARViewerPerf]` logs emitted by
`ar_viewer_screen.dart`.

## What is measured

The debug log reports two groups of metrics:

- `anchors`: total source memories, active candidates, visible anchors, rendered
  overlays, projection input/projection duration, and overlay composition time.
- `frame`: sampled average build, raster, and total frame durations, plus the
  maximum total frame duration in the sample window.

The metrics are diagnostic. They are not emitted in release builds and should
not be interpreted as a substitute for Flutter DevTools or platform profiling.

## Repeatable stress profile

Run on the same physical device, OS version, build mode, and scene for each
comparison. Prefer a physical AR-capable device; emulator results are not a
reliable proxy for camera/AR rendering.

1. Start a debug build and open AR Viewer with a stable camera session.
2. Prepare scenes containing approximately 1, 100, 500, and 1,000 memories.
3. For each scene, perform a 30-second steady scan with slow horizontal and
   vertical movement.
4. Repeat with anchors distributed across the view, clustered in one region,
   and mostly off-screen.
5. Repeat after backgrounding and resuming the app to check that instrumentation
   and overlay behavior remain stable.
6. Capture the `[ARViewerPerf]` output and a Flutter DevTools performance
   timeline for each run.

Keep device temperature, power mode, camera conditions, and other foreground
apps as consistent as practical. Record device model, refresh rate, build
configuration, anchor count, and run duration alongside the logs.

## Provisional frame budgets

These are initial engineering targets, not measured claims or CI gates. Confirm
them on the supported device matrix before treating them as release criteria.

| Target refresh rate | Frame interval | Steady-state average total | Investigate sustained maximum |
| --- | ---: | ---: | ---: |
| 60 Hz | 16.7 ms | At or below 16.7 ms | Above 33.3 ms |
| 90 Hz | 11.1 ms | At or below 11.1 ms | Above 22.2 ms |
| 120 Hz | 8.3 ms | At or below 8.3 ms | Above 16.7 ms |

Also investigate when average build or raster time approaches half of the
frame interval. A low average can hide intermittent stalls, so inspect the
DevTools timeline and the reported maximum rather than relying on averages
alone.

## Overlay scaling expectations

- The radar and anchor list must continue to represent the full collection.
- Every on-screen anchor and the focused anchor remain eligible for a floating
  overlay.
- Off-screen floating overlays are bounded to the eight nearest candidates.
- Increasing source collection size should not cause off-screen overlay count
  to grow without bound.
- Projection input caching should reuse geographic inputs while the same
  immutable `AnchorMemory` instances remain in the same order.
- Completed projection results should also be reused while the anchor snapshot,
  viewer origin, heading, pitch, field of view, range, projector and range-filter
  mode are unchanged.
- Replacing, adding, removing, or reordering memory instances must invalidate
  both geographic inputs and completed projection results.
- Any viewer-pose or projection-mode change must invalidate only the completed
  projection result; unchanged geographic inputs remain reusable.

## Projection scheduling decision

The viewer currently requests projections during widget build. The projection
algorithm is synchronous and includes per-anchor geospatial math plus sorting.
The cache-miss path computes each anchor's 3D magnitude once and reuses it for
range classification, placement scoring, and the returned distance value.
Before introducing isolate scheduling, first avoid repeating that work on
unrelated widget rebuilds: `ARMemoryProjectionCache` now memoizes the completed
projection for an unchanged memory snapshot and complete pose key.

This is deliberately not an isolate implementation. Moving the calculation to
an isolate would require serializing the anchor metadata and returning
projection results asynchronously, with stale-result cancellation and a
temporary last-known projection policy. That added complexity should be justified
by device traces showing that cache misses still exceed the frame budget for
large collections.

## Automated coverage

`test/features/ar_viewer/models/ar_memory_projection_test.dart` exercises
cache reuse and invalidation, including a 1,000-memory collection. This verifies
correctness and bounded input reuse; it is not a wall-clock performance
benchmark.

Do not add timing assertions to ordinary unit tests: host scheduling and CI
hardware make those assertions noisy. Use a dedicated benchmark or device
profiling run when stable hardware is available.
