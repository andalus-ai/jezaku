# Local data and discovery

## What already persists

Captured memories are stored on-device through `AnchorMemoryStore`
(`SharedPreferencesAnchorMemoryStore` in production, injected from
`UI/jezaku/lib/main.dart`), media through the file-backed
`anchor_media_repository`, and pending uploads through the upload-queue stores.
A restart keeps everything the user captured.

## Sample data is opt-in

Bundled sample memories (`SampleAnchorService`) and walls (`SampleWallService`)
are mixed in only when `sampleDataEnabledProvider` is true:

| Build | Default |
| --- | --- |
| debug / test | on |
| profile / release | off (empty state) |

Override with `--dart-define=ENABLE_SAMPLE_DATA=true|false`. The existing
`USE_DUMMY_DATA=true` flag (used by `UI/jezaku/scripts/run_demo_android.sh`)
also turns samples on. Social sample data is still always present and is left
for the backend/integration phase.

## Known gap: "nearby" is not really nearby

Discovery does not yet use the device position:

- Several screens pass the constants `viewerLatitude`/`viewerLongitude`
  (Bandung) as the origin: `main_screen`, `profile_screen`, `gallery_screen`,
  `memory_detail_screen`, `memory_search_screen`, `virtual_wall_screen`, and
  `spatialJourneyProvider`.
- Distance text comes from parsing `memory.distanceLabel`, not from the
  memory's coordinates.

Fixing this needs a live-origin provider, distance computed from coordinates,
and geofence-based discovery. It touches about ten call sites and should be
done with a working Flutter toolchain so the screens can be exercised.
