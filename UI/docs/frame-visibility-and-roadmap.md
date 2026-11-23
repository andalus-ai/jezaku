# Frame visibility and AR frames roadmap

Status: the visibility policy (stage 1) is implemented and unit-tested. It has **not** been checked on a physical device. Items marked "not built" below do not exist yet.

## Principle

Jezaku is authentic to physical existence. A frame hangs at a real place, and you see it by standing there. Two questions decide whether the AR viewer shows a frame:

1. **May this person see it?** Public frames, friends' frames and the viewer's own frames. Private frames of other people never.
2. **Are they close enough?** Only within a physical radius of where they stand now (default **20 m**). The radius follows the person: walking reveals the frames around the new spot and drops the ones left behind.

The backend stays authoritative for who may see what (`Backend/memory` `MemoryAccessPolicy`, social graph). The client rules are defence in depth, and they also own the proximity rule, which is a presence rule rather than an access rule.

## Where the rules live

One namespace: `UI/jezaku/lib/features/ar_viewer/visibility/`. Import `frame_visibility.dart`, not the individual files.

| File | Role |
|---|---|
| `frame_visibility_rule.dart` | `FrameVisibilityRule` interface, `FrameVisibilityCandidate`, `FrameViewerContext`, `FrameViewerRelation`, `FrameVisibilityDecision` (`FrameVisible` / `FrameHidden(reason)`), `FrameHiddenReason`, `FrameRuleStage` |
| `frame_audience_rule.dart` | `FrameAudience` (`private`, `friends`, `public`), `frameAudienceOf(memory)`, `FrameAudienceRule` |
| `frame_moderation_rule.dart` | `FrameModerationRule` (moderator-hidden frames are never drawn) |
| `frame_physical_radius_rule.dart` | `defaultFrameViewRadiusMeters` (20) and `FramePhysicalRadiusRule` (horizontal distance, inclusive, unknown distance fails closed) |
| `frame_visibility_policy.dart` | `FrameVisibilityPolicy`: ordered rules, `evaluate`, `eligible`, `viewable` |

Rules run in two stages. **Eligibility** rules do not depend on position (audience, moderation). **Proximity** rules depend on where the viewer stands (radius). `eligible()` returns what the viewer may see anywhere. `viewable()` returns what they may see from here, and it is the only list the AR viewer draws.

The AR viewer calls the policy in one place (`ar_viewer_parts/ar_viewer_visibility.dart`). Overlays, the native scene, the radar, the list and the HUD counts all read that result. The radar scale is the policy radius. When nothing is within the radius the viewer shows "No frames within 20 m" and says nothing about frames elsewhere, so the viewer cannot be used to find them.

Trail guidance uses the eligible list so it can still say how far the next stop is. A trail stop beyond the radius is not drawn until you arrive.

### Adding a rule

1. Implement `FrameVisibilityRule` in a new file in the namespace, choose its stage, return a `FrameHiddenReason` (add one if needed).
2. Add it to `FrameVisibilityPolicy.standard()`.
3. Add unit tests to `test/frame_visibility_policy_test.dart`.
4. Do not filter frames anywhere else. If a screen needs a different list, extend the policy.

Candidate future rules: age or expiry, time-of-day or event windows, family and group audiences, blocked accounts, safety zones, per-frame custom radius.

## Known gaps in stage 1

- **The client is not connected to the backend, so it knows no owner or friends.** `AnchorMemory` now carries `audience` (private/friends/public, the backend's `visibility`) and `ownerId`, and `FrameViewerContext.forUser` turns a user id and friend ids into owner, friend or stranger. But nothing supplies those ids yet: `currentUserIdProvider` is null and `friendIdsProvider` is empty, and frames without an `ownerId` count as the viewer's own. So the audience rule is complete and tested but hides nothing in the app today. Wiring the two providers (identity and social services) and loading other people's frames from the memory service is the integration phase.
- **Own private frames stay visible to their owner.** A person who hangs a private frame still sees it where they hung it. Change `FrameAudienceRule` if the product wants otherwise.
- **GPS jitter at the edge.** A frame that was visible stays visible up to 5 m past the radius (`defaultFrameExitMarginMeters`), so jitter at 20 m no longer makes it blink; a frame not yet visible still needs the viewer inside 20 m. Not yet validated on a device. Accuracy-aware radius and a user setting are still open. Frames hung in the current AR session are placed by AR tracking, but the policy measures geographic distance.
- **The radius is a constant.** It is not a setting and it is not per frame.
- **Not validated on a device.** See `ar-device-demo-lab.md`.

## Demo and strict rules

The rules run in one of two modes, chosen per build with `--dart-define=JEZAKU_FRAME_RULES=demo|strict`:

| Mode | Audience | Radius | Use |
| --- | --- | --- | --- |
| `demo` | everyone who is not the owner counts as a friend (private frames stay private, moderation still applies) | not enforced | offline demos and prototyping, so every sample frame can be shown |
| `strict` | public, friends, own | 20 m (plus the 5 m exit margin) | production; the backend enforces the same rules |

A build that does not pass the define runs `demo` for now. Any other value than `demo` or empty is read as `strict`, so a typo never loosens the rules. The Android and iOS production scripts pass `strict`. Physical-device validation of the radius and edge behaviour must run `strict`, for example `scripts/run_demo_android.sh --dart-define=JEZAKU_FRAME_RULES=strict`.

The backend has no demo mode: it is not used offline, and its friends rule is switched by `jezaku.memory.friends-visibility.enforced` (see the memory README).

## Own gallery versus on-site friends (product rule, 2026-11-23)

- The owner sees all of their own frames anywhere, as a gallery (grid, then detail, comments, edit, delete, change audience).
- Anyone else, friends included, sees and interacts with a frame only on site, inside the same physical radius, through the same policy (`viewable()`). No remote browsing, remote comments or remote likes on someone else's frame.
- Remote surfaces (feed, notifications, search) may show a locked placeholder: place name and distance only, no photo, no comments.
- The remote/on-site split lives in the visibility namespace, not in screens. The client cannot enforce it until slice 5 supplies the owner id; the backend must enforce it for media and comments too.

## Roadmap

Order of work, one pull request per slice, each with tests and doc updates.

| # | Slice | Status |
|---|---|---|
| 1 | Capture in the viewer, Publish now / Review & publish, photo not placeholder | done |
| 2 | Photo page with Instagram-style comments, opened from the focused-frame panel, back returns to AR | done |
| 3 | Central visibility policy: audience, moderation, 20 m physical radius | done (this document) |
| 4 | Tap the frame object in AR to open the photo page (native hit-test of the frame quad, event to Dart) | not built; needs a device |
| 5 | Backend-fed audience and owner: three-way visibility and owner id on the memory model, friends from the social graph, `FrameViewerContext` fed from them | client model done: `AnchorMemory.audience` (private/friends/public, matching the backend `visibility`) and `ownerId`, audience picker in Publish, `FrameViewerContext.forUser`, `currentUserIdProvider` and `friendIdsProvider` as the seams. Not done: the client has no backend connection or user identity yet, so those providers are empty (integration phase) |
| 6 | Persist and sync comments to the memory service's friends-only comment endpoints | not built; the client is not wired |
| 7 | Edge behaviour: exit-margin hysteresis and a "your nearest frame is N m away, walk closer" cue (own frames only, never other people's) | built, not validated on a device; accuracy-aware radius and a setting still open |
| 11 | Own-frames gallery: Instagram-style grid of the owner's frames, viewable anywhere (Profile), with detail, comments and edit | built: My frames screen (Profile → My frames), 3-column grid, All/AR/Videos/Private/Needs calibration filters, opens the memory detail; today every on-device frame counts as own, `ownFramesProvider` narrows it once slice 5 supplies the owner id; comments and edit come from the existing detail screen. Not yet validated on a device |
| 12 | On-site gate for other people's frames: Gallery, Search, Social hub, Notifications and the photo/comments page open someone else's frame only inside the physical radius; remote surfaces show a locked "Go to <place>" card with distance | planned |
| 13 | Frame gallery: several default looks, default in Settings, author changes a published frame's look or colour from the photo page / AR panel | built, see [frame-styles.md](frame-styles.md); not synced to the backend and not validated on a device |
| 8 | Frame persistence across AR sessions | see [ar-frame-persistence-plan.md](ar-frame-persistence-plan.md) |
| 9 | Diagnose the app lag (needs a device debug log) | open |
| 10 | Physical-device validation of slices 1-4 | open |

Slices 5 and 6 and the frame persistence plan need decisions from the owner before work starts: where anchor records live (memory service or a new service), how the app reaches ar-core, and keyframe privacy and retention.

## Validation still required

Unit tests cover the rules and the policy. A physical-device pass is required before slice 3 is called done: walk away from a hung frame and back, with GPS only, and record the result in `ar-device-demo-lab.md`.
