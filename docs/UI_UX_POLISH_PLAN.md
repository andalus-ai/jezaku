# Jezaku UI/UX Polish Plan

**Status:** Proposed implementation backlog  
**Scope:** Flutter application in `UI/jezaku`  
**Product direction:** A spatial-social application where discovering, capturing, revisiting, and sharing real-world memories feels clear and trustworthy.

## 1. Goals

1. Make the primary user journeys obvious: discover nearby memories, capture a memory, view it in AR, and share it safely.
2. Establish a coherent visual system across Home, Camera, AR Viewer, Social, Gallery, Profile, and Settings.
3. Reduce visual clutter without hiding important AR state or safety controls.
4. Improve accessibility, responsive behavior, loading/error/empty states, and perceived performance.
5. Preserve existing feature behavior and Riverpod state architecture while polishing presentation.

## 2. Repository observations

The current Flutter app already has meaningful feature separation and several user-facing surfaces:

- `app/screens/main_screen.dart`: five-tab navigation (Home, AR View, Social, Gallery, Profile), Capture FAB, active-trail banner.
- `features/home/screens/home_screen.dart`: map-led home screen, location status, map actions, nearby-memory list and filters.
- `features/camera/screens/camera_screen.dart`: camera capture workflow and sensor/minimap overlays.
- `features/ar_viewer/screens/ar_viewer_screen.dart`: AR viewer and diagnostics-oriented controls.
- `features/social/screens/social_hub_screen.dart`: Feed/Discover tabs, notifications, messages, saved filter.
- `features/settings/screens/settings_screen.dart`: user preferences plus substantial storage, cache, and AR diagnostics controls.

This plan is based on source inspection, not a running visual audit. Before changing layouts, capture screenshots and run the existing widget tests on representative devices.

## 3. UX principles

- **Spatial-first, not map-only:** the map is an entry point; memories and actions remain understandable without interpreting map symbols.
- **One dominant action per context:** Capture on Home; Place/Relocalize in AR; Compose in Social.
- **Progressive disclosure:** expose common controls first; move technical diagnostics into expandable details or a developer mode.
- **Honest system status:** location, camera, tracking, sync, and permission states must be explicit and actionable.
- **Privacy by design:** visibility is shown at creation and review time; precise location sharing is never implied.
- **Consistent interaction:** common spacing, typography, cards, sheets, dialogs, buttons, and feedback.
- **Accessible by default:** text scaling, contrast, semantics, touch targets, keyboard navigation, and reduced motion.
- **Responsive:** layouts work on compact phones, large phones, and tablets; avoid fixed heights that clip content.

## 4. Workstreams and implementation order

### UX-00 — Baseline and design tokens

**Tasks**
- Capture baseline screenshots for Home, Camera, AR Viewer, Social Feed, Gallery, Profile, Settings, and key bottom sheets/dialogs.
- Record viewport sizes and text scale used for snapshots.
- Inventory existing ThemeData, colors, typography, radii, spacing, and component duplication.
- Define semantic color roles, type scale, spacing scale, radii, elevation, and motion durations.
- Create shared components only where repeated patterns are confirmed.

**Acceptance criteria**
- A documented visual baseline exists.
- Light and dark theme tokens are centrally defined.
- No feature introduces ad-hoc brand colors for standard UI states.
- Golden tests cover the shared primitives and main navigation shell.

### UX-01 — App shell and navigation

**Current surface:** `app/screens/main_screen.dart`.

**Tasks**
- Standardize app title/branding (repository currently has a visible Jejaku/Jezaku spelling inconsistency to resolve).
- Review five-tab navigation labels and icon semantics.
- Ensure selected/unselected states, safe-area insets, and text scaling remain clear.
- Reposition the Capture action so it never obscures the active-trail banner, content, or system gesture area.
- Make the active-trail banner compact, dismissible, and context-aware; provide a clear resume action.
- Preserve tab state and avoid unnecessary camera/AR session initialization when switching tabs.
- Add route transition conventions and predictable back behavior.

**Acceptance criteria**
- No overlap between FAB, active-trail banner, bottom navigation, and system insets.
- All navigation destinations have meaningful semantics and selected states.
- Tab switching does not unexpectedly reset user context.
- Navigation widget tests cover all five destinations and trail banner visibility.

### UX-02 — Home and nearby discovery

**Current surface:** `features/home/screens/home_screen.dart`.

**Tasks**
- Refine map/list hierarchy: make the map useful but allow users to expand the memory list easily.
- Replace fixed proportional map/list sizing with a draggable or responsive layout where practical.
- Add clear map legend and distinguish current location, memories, trails, and walls.
- Make location status explain both the state and next action (permission disabled, locating, approximate, accurate, stale).
- Group filters into a concise horizontally scrollable filter row; show active filter and result count.
- Improve memory cards with consistent thumbnail, title, distance, timestamp, visibility, and AR availability.
- Add explicit loading, permission-denied, location-unavailable, no-nearby-memory, and filtered-empty states.
- Ensure list content remains usable when map rendering or location permission fails.
- Make map actions accessible without relying on icon-only controls.

**Acceptance criteria**
- Users can understand location quality and recover from denied permissions.
- Map and list remain usable on compact screens and large text settings.
- Empty states explain how to create or discover memories.
- Filter state, result count, and map pins stay synchronized.

### UX-03 — Capture and camera

**Current surface:** `features/camera/screens/camera_screen.dart`.

**Tasks**
- Establish a clear capture hierarchy: preview first, shutter primary, mode/flash/import secondary.
- Keep critical status visible without covering the camera subject.
- Consolidate telemetry into a compact status chip; put detailed sensor data behind a diagnostics affordance.
- Add clear permission onboarding and recovery for camera, location, and motion sensors.
- Improve capture feedback (haptic/visual confirmation, thumbnail preview, save state).
- Make retake, discard, and continue actions explicit and prevent accidental data loss.
- Explain location accuracy and privacy before publishing; avoid exposing exact coordinates by default.
- Add resilient states for camera initialization, capture failure, low storage, and unavailable location.
- Verify touch target sizes and one-handed reachability.

**Acceptance criteria**
- A first-time user can capture a memory without reading technical diagnostics.
- Camera errors provide a recovery action.
- Capture/save/publish states are distinguishable.
- Discarding an unsaved capture requires confirmation when data would be lost.

### UX-04 — AR Viewer

**Current surface:** `features/ar_viewer/screens/ar_viewer_screen.dart` and `screens/ar_viewer_parts/`.

**Tasks**
- Define a clean AR HUD hierarchy: tracking state, primary placement/relocalize action, and context-specific controls.
- Use plain-language tracking states (Initializing, Move slowly, Searching for surface, Tracking, Tracking limited, Relocalizing).
- Pair every non-ready state with a concise instruction and optional details.
- Keep diagnostics hidden behind a developer/diagnostics panel rather than permanently competing with the scene.
- Standardize anchor placement, selected-anchor, unavailable-anchor, and tracking-loss visuals.
- Improve occlusion/contrast of controls over bright and dark camera scenes using scrims and adaptive surfaces.
- Ensure capture, exit, and recovery controls remain reachable.
- Add an AR onboarding coachmark that can be dismissed and revisited.
- Respect reduced-motion settings and avoid unnecessary animation during tracking instability.

**Acceptance criteria**
- Tracking state is understandable without knowing SLAM terminology.
- Each recoverable tracking failure has a next step.
- Core controls remain legible across varied camera backgrounds.
- Diagnostics are available but do not dominate the normal experience.

### UX-05 — Social, Gallery, Profile

**Current surfaces:** `features/social/screens/social_hub_screen.dart`, `features/gallery/screens/gallery_screen.dart`, `features/profile/screens/profile_screen.dart`.

**Tasks**
- Standardize feed card layout, media ratios, author metadata, location labels, and action placement.
- Make visibility and location-sharing scope visible on spatial posts.
- Improve feed loading, refresh, empty, offline, and error states.
- Make Discover explain why a place/person/content item is suggested.
- Give Gallery consistent filters/sorting and distinguish local, synced, and failed-upload media.
- Make Profile emphasize identity, memories, trails, and privacy controls with clear edit actions.
- Use confirmation/undo patterns for destructive or socially sensitive actions (hide, block, report, delete).
- Ensure accessible labels exist for like, comment, save, share, and report controls.

**Acceptance criteria**
- Feed, gallery, and profile use shared spacing and typography.
- Users can identify local vs synced media and recover failed uploads.
- Privacy scope is visible before sharing.
- Destructive actions are deliberate and reversible where appropriate.

### UX-06 — Settings and diagnostics

**Current surface:** `features/settings/screens/settings_screen.dart`.

**Tasks**
- Separate everyday preferences from advanced storage/cache/AR diagnostics.
- Group settings into Account, Privacy & Safety, Notifications, Location & AR, Storage, and About.
- Replace long undifferentiated lists with section cards or grouped list sections.
- Explain consequences for privacy-sensitive toggles.
- Show storage usage with clear units and distinguish media cache from model cache.
- Add confirmation and progress feedback for cleanup/repair operations.
- Keep diagnostic export and repair tools accessible to support/developer workflows without overwhelming ordinary users.

**Acceptance criteria**
- Common settings are findable within two navigation steps.
- Destructive cleanup explains what is removed.
- Long-running operations show progress and completion/failure feedback.
- Privacy controls use clear, non-technical language.

### UX-07 — Design system and component library

**Tasks**
- Introduce a shared app theme with light/dark ColorScheme and semantic extension tokens if needed.
- Define typography using ThemeData text styles rather than inline font sizes.
- Standardize page gutters, section spacing, card radius, icon sizes, and elevation.
- Create reusable components: primary/secondary action, status chip, section header, memory card, empty state, error panel, loading skeleton, confirmation sheet.
- Avoid building an abstraction for one-off UI; extract only stable repeated patterns.
- Document component usage and accessibility requirements.

**Acceptance criteria**
- New screens can be composed from shared tokens/components.
- Existing screens migrate incrementally without behavior regressions.
- Components support text scaling, semantics, and theme changes.

### UX-08 — Accessibility, localization, and motion

**Tasks**
- Audit semantic labels, focus order, screen-reader announcements, and contrast.
- Ensure interactive targets are at least 48 logical pixels where feasible.
- Test 1.3x and 2.0x text scaling.
- Avoid conveying state by color alone.
- Add localization-ready strings and avoid hard-coded concatenated sentence fragments.
- Support reduced motion and avoid animation that interferes with AR tracking.
- Validate Bahasa Indonesia and English copy for clarity and consistency.

**Acceptance criteria**
- Critical flows work with TalkBack and VoiceOver.
- No critical content is clipped at 2.0x text scale.
- Important statuses have text/icon cues in addition to color.
- User-facing copy is localizable.

### UX-09 — Quality gates and visual regression

**Tasks**
- Add widget tests for app shell, Home states, capture states, AR HUD states, feed states, and settings groups.
- Add golden tests for shared components and representative screens in light/dark themes.
- Add integration tests for first-run permission flow, capture-to-save, and memory-to-AR viewer.
- Run tests at compact and large viewport sizes.
- Add manual device checklist for Android first, with iOS parity maintained.
- Capture performance baselines for scrolling, image loading, and AR overlay composition.

**Acceptance criteria**
- UI changes include relevant widget/golden tests.
- Critical flows have integration coverage.
- No known overflow or inaccessible critical control in supported viewport matrix.
- Visual changes are reviewed against updated goldens rather than blindly accepting snapshots.

## 5. Suggested sequence and parallelization

| Iteration | Focus | Parallel work |
|---|---|---|
| UX Sprint 0 | Baseline, theme audit, design tokens | Inventory all screens and tests |
| UX Sprint 1 | App shell + Home | Shared component primitives |
| UX Sprint 2 | Camera + capture flow | Permission and accessibility states |
| UX Sprint 3 | AR Viewer + HUD | AR state copy and visual regression |
| UX Sprint 4 | Social + Gallery + Profile | Shared card and empty-state patterns |
| UX Sprint 5 | Settings + diagnostics | Localization and accessibility audit |
| UX Sprint 6 | Integration polish | Golden tests, device QA, bug bash |

Do not block all screen work on a complete redesign system. Establish the tokens and shared primitives first, then migrate one user journey at a time.

## 6. Visual direction

Recommended direction: **calm, modern, spatial, and trustworthy**.

- Use a neutral surface foundation with one restrained brand accent.
- Reserve high-saturation colors for AR tracking, location status, and meaningful alerts.
- Keep map and camera surfaces visually quiet so spatial content remains dominant.
- Use clear typography and generous but consistent spacing.
- Prefer bottom sheets for contextual actions and full screens for focused workflows.
- Use motion to communicate transitions and state changes, not as decoration.
- Avoid excessive glassmorphism, gradients, glowing borders, and decorative cards.

## 7. Priority order

### P0 — Fix first
- App shell/FAB/active-trail overlap and safe-area behavior.
- Home map/list usability and location-permission recovery.
- Camera first-run permission and capture/save feedback.
- AR tracking state clarity and control legibility.
- Privacy scope visibility when creating/sharing memories.
- Text scaling, semantics, and overflow on primary journeys.

### P1 — High value
- Shared theme and component primitives.
- Feed and gallery card consistency.
- Loading, empty, offline, and error states.
- Settings information architecture.
- Golden tests and responsive layout coverage.

### P2 — Refinement
- Subtle transitions and haptics.
- Personalized discovery explanations.
- Advanced map presentation and optional map styles.
- Additional tablet layouts and richer profile presentation.

## 8. Definition of done for UI/UX work

A screen is considered polished only when:

1. Its primary action is obvious.
2. Loading, empty, error, offline, and permission states are designed.
3. It works on compact and large screens.
4. It supports text scaling and screen readers.
5. It follows shared theme tokens.
6. It preserves existing business logic and state behavior.
7. Relevant widget/golden tests pass.
8. It has been reviewed on a physical Android device.
9. Privacy implications are clear for any location or sharing action.

## 9. First implementation slice

Start with **UX Sprint 0 + UX Sprint 1**:

1. Capture screenshots and inspect existing theme configuration.
2. Define semantic theme tokens and shared spacing/type/radius rules.
3. Polish the main navigation shell and Capture FAB/trail-banner interaction.
4. Improve Home map/list hierarchy, location status, and empty/error states.
5. Add widget/golden tests for these surfaces.

Do not redesign all screens at once. Ship a coherent, tested vertical slice and use it as the reference for the remaining features.
