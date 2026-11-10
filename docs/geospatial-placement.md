# Geospatial placement quality

The concept promises AR frames that appear where the photo was taken
(about 1–3 m position and under 1° heading). Native geospatial tracking
(ARCore Earth / VPS on Android) is what provides that. GPS plus compass
projection is only a rough fallback, so the app reports which one is active.

## How it works

1. The AR session starts with geospatial enabled when the device supports it
   (`arViewerSessionPlanProvider`). Without support, or without location
   permission, the session falls back and the HUD says so.
2. `ARGeospatialQualityMonitor` polls `ARController.getGeospatialStatus()`
   every 2 s and `JejakuPlacementPolicy` turns it into a
   `JejakuPlacementAssessment`: **Precise** or **Approx.**, with a reason
   (localizing, not authorized, accuracy too low, and so on).
3. Memories start on the GPS/compass projection. The first time the assessment
   is precise, the viewer sets `JejakuMemoryARScene.preferNativeGeospatialAnchors`
   and re-syncs, so memories are re-placed as native geospatial anchors.
4. The upgrade is one way for the session. Native anchors keep correcting
   themselves, so a brief accuracy dip only changes the chip, it does not
   push memories back to the projection.

## Thresholds

`JejakuPlacementPolicy` defaults: horizontal ≤ 3 m, heading ≤ 5°,
vertical ≤ 5 m (vertical is skipped if the device does not report it).
These are **starting values** and need tuning from field data.

## Setup that code cannot do

- ARCore Geospatial API must be enabled for the app in Google Cloud, with
  keyless authorization. Without it Earth reports `ERROR_NOT_AUTHORIZED`
  and the chip says "Geospatial service is not authorized for this app".
- Location permission (fine) and network access are required at runtime.

## Field test checklist (real device, outdoors)

Run on at least one Android device in a place with Street View coverage and
one without.

- [ ] Chip goes Approx. → Precise within a reasonable time after scanning.
- [ ] A memory captured at a spot appears within ~3 m of it after the upgrade.
- [ ] Heading of a frame matches the capture direction (±5°).
- [ ] No visible jump or double frame when memories are re-placed on upgrade.
- [ ] Leaving and re-entering the screen starts from Approx. again.
- [ ] With the Geospatial API disabled, the chip shows the not-authorized
      reason and placement still works on the projection.
- [ ] Record the horizontal/heading accuracy values at which placement
      looked right or wrong, and update the thresholds.

## Not done yet

- iOS: `getGeospatialStatus` and `checkVpsAvailability` report unsupported,
  so iOS stays on Approx. until `ARGeoTrackingConfiguration` availability and
  accuracy are mapped natively.
- Capture does not yet store the geospatial accuracy at capture time next to
  the memory, so older memories keep their GPS-grade coordinates.
- Altitude uses the captured value as is (no terrain/rooftop anchors yet).
