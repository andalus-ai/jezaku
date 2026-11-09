# Jejaku Feature Consolidation

This file consolidates the root-level Jejaku export snippets into the current
feature-first Flutter structure under `lib/features`.

## Consolidated Modules

- `home`: nearby memory map, anchor list, AR entry points.
- `camera`: capture surface, grid/level assist, publish handoff.
- `publish`: caption, visibility, comments, and anchor radius controls.
- `ar_viewer`: AR HUD, nearby anchor overlays, capture shortcut.
- `gallery`: memory gallery with all/AR/private filters.
- `social`: feed, discover, comments, notifications, messages, post cards.
- `virtual_wall`: collaborative AR walls, wall details, members, wall items.
- `parent`: parental dashboard, screen time, geofences, safety restrictions.
- `profile`: account summary and entry points into advanced modules.
- `settings`: privacy, notification, and high-accuracy anchoring settings.

## Source Mapping

- `jejaku_complete_ui.dart` supplied the home, camera, AR viewer, and gallery
  concepts.
- `jejaku_social_media*.dart` supplied the social feed, comments,
  notifications, messages, and profile concepts.
- `jejaku_ar_virtual_wall.dart` supplied the collaborative AR wall model.
- `jejaku_parental_controls*.dart` supplied parent dashboard, safety,
  screen-time, and geofence concepts.
- The roadmap and architecture markdown files were reduced into this feature
  map so implementation lives with feature modules instead of root-level dumps.

## Backup Folder Consolidation

- `lib/features/bak/models/memory.dart` and
  `lib/features/bak/providers/memory_provider.dart` were merged into
  `home/models/anchor_memory.dart` and `home/states/anchor_providers.dart`.
- `lib/features/bak/services/location_service.dart` and
  `lib/features/bak/services/sensor_fusion_service.dart` now live as the active
  capture snapshot model and service under `camera/models` and
  `camera/services`.
- `lib/features/bak/services/ar_anchor_service.dart` maps to the
  `ar_viewer/models/ar_memory_projection.dart` adapter and the shared
  `jezaku_ar` projection package.
- `lib/features/bak/views/camera_view.dart`,
  `lib/features/bak/views/gallery_view.dart`, `lib/features/bak/views/ar_view.dart`,
  `lib/features/bak/views/advanced_ar_view.dart`, and
  `lib/features/bak/views/home_view.dart` were folded into the current camera,
  gallery, AR viewer, and main navigation screens.
