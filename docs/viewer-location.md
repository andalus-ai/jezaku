# Viewer location

Discovery, trails and wall routes used to measure from the hard-coded
`viewerLatitude`/`viewerLongitude` (Bandung), and several distances came from
parsing `memory.distanceLabel`.

## Now

`viewerLocationProvider` holds a `ViewerLocation`:

- Starts at `ViewerLocation.fallback` (`isLive == false`).
- `main.dart` injects `GeolocatorViewerLocationSource`, which streams fixes
  (10 m distance filter) once location services are on and permission has
  already been granted. Fixes that move less than 5 m are ignored.
- While `isLive` is false, distances still come from `distanceLabel`, because
  the sample data is authored against the fallback origin.
- Once live, distances are computed from coordinates
  (`ViewerLocation.distanceToMemoryMeters`, `useCoordinateDistance` on the map
  projection and journey services).

Migrated: spatial journey provider, gallery (map and sort-by-nearest), memory
search trail, memory detail, virtual wall (list, create/manage dialogs, detail
overview), active trail route in `main_screen`, profile trail routes.

## Limitations / follow-ups

- Discovery never prompts for location permission (the capture flow owns the
  prompt), so it stays on the fallback until the user has granted it there.
  A proper permission step and a "location off" empty state are still needed.
- Nothing filters or sorts the home feed by radius yet; "nearby" is still every
  stored memory. Geofenced discovery is the next step.
- The AR viewer keeps its own `viewerOrigin`; unifying it is left alone.
- Sample memories sit around Bandung, so on a real device away from Bandung a
  live origin makes them look far away (enable sample data only for demos).
