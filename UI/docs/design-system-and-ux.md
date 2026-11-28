# Jezaku UI Design System and UX Standards

## 1. Product experience principles

Jezaku combines camera-first interaction, geospatial discovery, AR placement, and social participation. UI decisions should optimize for:

1. **Clarity in context** — users understand where they are, what is happening, and what an action will do.
2. **Trust and control** — location, camera, visibility, and sharing scope are explicit.
3. **Fast capture** — the primary capture journey has minimal friction without hiding important safety or privacy information.
4. **Legibility over decoration** — map and camera content remain the visual focus.
5. **Consistency** — repeated patterns behave and look alike across features.
6. **Resilience** — permission, connectivity, tracking, and sensor failures have useful recovery paths.

## 2. Design foundations

Use semantic design tokens for:
- Color roles: background/surface, elevated surface, primary/secondary text, border/divider, primary action, success, warning, and error.
- Typography: display, title, body, label, caption, and numeric/data styles.
- Spacing: a consistent base scale with documented semantic aliases.
- Shape: control, card, sheet, dialog, and overlay radii.
- Elevation: a small intentional scale, with contrast checked in light and dark themes.
- Motion: duration and easing tokens with reduced-motion alternatives.

The shared tokens come from the `jezaku_ds` package; see [design-system-adoption.md](design-system-adoption.md) for how the app consumes them.

Do not scatter raw color, padding, radius, or animation values across feature widgets. Add a token only when it represents a reusable semantic role. Keep contrast sufficient in both themes and over camera/map imagery.

## 3. Navigation and screen hierarchy

- Keep top-level navigation stable and predictable.
- Make the primary action visually dominant but not obstructive.
- Preserve context when moving between map, list, camera, profile, and detail surfaces.
- Use bottom sheets for contextual actions and previews only when they do not hide essential map/camera context.
- Provide clear back behavior and avoid nested modal stacks.
- Use consistent titles, action placement, empty states, and loading patterns.

## 4. Camera and AR surfaces

- Prioritize camera preview and the immediate capture/view task.
- Keep controls in stable, reachable zones and respect system safe areas.
- Use contrast-aware scrims or surfaces behind controls rather than relying on text shadows alone.
- Separate camera permission, location permission, location quality, AR support, tracking state, and anchor confidence.
- Show concise status language with an actionable recovery step.
- Do not place persistent overlays over important camera content or map landmarks.
- Use haptics and animation as feedback, not as substitutes for visible state.
- Ensure capture, pause/resume, and exit actions remain discoverable.

## 5. Maps and geospatial data

- Show location freshness/accuracy when it materially affects the result.
- Differentiate user location, saved content, people, places, and route/checkpoint markers.
- Use clustering and progressive disclosure in dense areas.
- Keep selected-item state synchronized between map markers and result lists.
- Provide list alternatives for users who cannot use or prefer not to use a map.
- Explain approximate or unavailable location; never imply precision that the device/server does not provide.
- Do not expose exact private coordinates in labels, analytics, or debug UI.

## 6. Social and privacy-sensitive interactions

- Make audience scope visible before publishing or changing visibility.
- Use explicit confirmation for destructive actions and high-impact sharing changes.
- Provide understandable block, report, mute, and safety controls.
- Distinguish private, friends, family, group/community, and public scopes using both text and visual treatment.
- Do not rely on color alone to communicate privacy or moderation status.
- Avoid showing people/content that the backend has denied for the current viewer.

## 7. Required component states

Every reusable component and screen should consider relevant states:

| State | Expected behavior |
| --- | --- |
| Initial/loading | Stable layout, clear progress, avoid unnecessary layout jumps |
| Empty | Explain why there is no content and offer a useful next action |
| Error | Human-readable message, safe retry path, preserve user input |
| Offline/stale | Distinguish cached content from current server state |
| Permission blocked | Explain impact and provide a settings/retry path |
| Partial capability | Continue with supported functionality and disclose limitations |
| Success | Confirm completion without excessive interruption |
| Disabled | Explain why an action is unavailable when not obvious |

## 8. Accessibility and responsive behavior

- Use semantic labels, roles, and hints for controls and meaningful images.
- Maintain sufficient contrast and never use color as the only status signal.
- Support platform text scaling without clipping or truncating essential actions.
- Ensure touch targets are comfortably sized and spaced.
- Test narrow phones, larger phones, landscape where relevant, and tablets.
- Keep focus order logical and announce important asynchronous state changes.
- Respect reduced-motion settings and avoid flashing or disorienting transitions.

## 9. Motion and feedback

- Use transitions to explain spatial/navigation relationships.
- Prefer short, consistent motion and avoid decorative animation loops.
- Provide immediate feedback for capture, selection, save, upload, and retry actions.
- Pair haptics with visible state changes.
- Ensure animations do not block input or compromise camera frame rate.

## 10. Definition of done

A UI/UX change is ready when:
- The primary action and navigation path are obvious.
- Relevant loading, empty, error, offline, permission, and partial-capability states are covered.
- Layout works with text scaling and supported screen sizes.
- Semantics and contrast are checked.
- Shared tokens/components are used.
- Privacy implications are clear for location and sharing actions.
- Relevant unit/widget/integration tests pass.
- Performance is acceptable on representative devices.
- Physical-device validation is recorded for camera, sensor, and AR changes.
- Documentation and screenshots are updated when the design system or interaction contract changes.

See the root [UI/UX polish plan](../../docs/UI_UX_POLISH_PLAN.md) for sequencing and rollout priorities.
