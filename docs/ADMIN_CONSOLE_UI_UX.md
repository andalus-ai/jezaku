# Jezaku Admin Console — UI/UX Specification

**Status:** Proposed product and interaction specification  
**Scope:** Existing Flutter application at `UI/jezaku_admin/`  
**Relationship:** Complements the Flutter end-user application; does not replace it.

## 1. Product intent

The Admin Console is the operational workspace for people who configure, govern, publish, and operate Jezaku. It should support platform operators, organization administrators, moderators, content managers, and extension developers without exposing every capability to every role.

The console is a management surface, not the spatial end-user experience. It should optimize for clarity, safe operations, efficient review, and explainable state.

The repository already has a separate Flutter admin application at `UI/jezaku_admin/`, distinct from the Flutter end-user app at `UI/jezaku/`. The admin app has an initial responsive shell, ten management-area destinations, and honest not-connected/not-implemented overview states. Its dependency manifest includes Flutter and `material_ui`; the broader admin architecture also records adoption of the Alhambra UI foundation. This specification refines that existing console rather than proposing a separate web application or a second UI stack. Recheck source before implementation; the current shell and backend integration status may have changed.

## 2. UX principles

1. **Role-aware, not role-fragmented:** one coherent console; navigation and actions adapt to permissions.
2. **Progressive disclosure:** common tasks are prominent; advanced configuration and diagnostics are available without dominating everyday workflows.
3. **Safety before convenience:** show visibility, placement, policy, and audience consequences before publishing or changing spatial content.
4. **Explain system state:** every status has a plain-language label and, where useful, a next action.
5. **Consistent management patterns:** tables, filters, detail pages, forms, dialogs, and audit history behave consistently.
6. **Fast for repeat work:** global search, keyboard navigation, saved filters, bulk actions where safe, and contextual actions.
7. **Accessible and responsive:** keyboard-first operation, screen-reader semantics, text scaling, contrast, and compact layouts.
8. **Honest capability presentation:** do not show unfinished modules as operational features. Mark planned modules clearly or keep them out of production navigation.
9. **Tenant and environment awareness:** make the active organization/workspace and environment visible whenever actions are scoped by them.
10. **Auditable operations:** privileged and consequential actions explain their impact and produce attributable audit records.

## 3. Information architecture

### Primary navigation

- **Overview** — platform or organization health, activity, alerts, and shortcuts.
- **Workspace**
  - Organizations and tenants
  - Members and teams
  - Workspace settings
- **Identity & Access**
  - Users
  - Roles and permissions
  - Sessions and API credentials
- **Spatial**
  - Objects and assets
  - Scenes and placements
  - Publishing and visibility
  - Safety and moderation review
- **Content**
  - Content library
  - Review queue
  - Publishing history
- **Marketplace**
  - Catalog
  - Submissions and reviews
  - Licenses and distribution
- **Extensions**
  - Installed extensions
  - Compatibility and permissions
  - Versions and lifecycle
- **Campaigns** (optional platform capability)
  - Merchants and advertisers
  - Campaigns and promotions
  - Eligibility and performance
- **Operations**
  - Services and health
  - Jobs and schedules
  - Events and logs
- **Analytics**
  - Usage and operational insights
  - Privacy-aware reporting
- **Security & Audit**
  - Security events
  - Audit history
  - Policy decisions
- **Settings**
  - Platform/workspace configuration
  - Feature availability
  - Integrations

Navigation is permission-filtered. Avoid showing links that lead to unauthorized pages. Distinguish platform-wide administration from tenant-scoped administration in both labels and page context. Optional capabilities such as marketplace and campaigns should only appear when enabled and implemented.

## 4. Application shell

### Desktop

- Left navigation rail: approximately 248 px expanded, 72 px collapsed.
- Top bar: breadcrumb, page title context, global search, environment/workspace switcher, notifications, help, and profile menu.
- Main content: fluid width with a comfortable maximum for reading-heavy pages; data tables may use the available width.
- Optional right-side contextual panel for selected records, filters, or preview.
- Persistent environment indicator for non-production environments.

### Responsive behavior

| Viewport | Behavior |
|---|---|
| >= 1440 px | Expanded sidebar, full content layout, optional context panel |
| 1280–1439 px | Expanded or collapsible sidebar, full tables |
| 1024–1279 px | Collapsible sidebar, context panel becomes drawer |
| 768–1023 px | Compact navigation, tables prioritize key columns |
| < 768 px | Drawer navigation, stacked cards, forms in one column, table rows become compact record cards |

Do not rely on horizontal scrolling as the default mobile table experience. Preserve access to secondary fields through row details.

### Shell interaction

- Breadcrumbs reflect the actual hierarchy and provide predictable navigation.
- Global search opens with a keyboard shortcut (for example, Cmd/Ctrl+K); the shortcut must be discoverable and must not conflict with browser or assistive-technology commands.
- Workspace and environment are always visible when relevant.
- User menu contains profile, preferences, help, and sign out.
- Notifications are grouped by severity and destination; avoid using notifications as a substitute for persistent operational alerts.

## 5. Core screen specifications

### 5.1 Overview

Purpose: answer “Is Jezaku healthy, what needs attention, and what should I do next?”

Recommended hierarchy:
1. Page heading with workspace/environment context and time range.
2. Critical alerts and required actions.
3. Metric cards (only metrics backed by real APIs).
4. Health summary for relevant services.
5. Activity timeline and recent administrative changes.
6. Role-aware shortcuts.

Metric candidates include active users, published spatial objects, pending reviews, extension installations, job failures, and API/service health. Do not fabricate metrics or use decorative sample data in production. Every metric should define its source, time window, and meaning.

States: loading skeleton, first-use empty state, partial data, stale/offline, permission-limited, and recoverable error.

### 5.2 Users & Access

- Searchable, filterable, sortable, paginated user list.
- Columns: identity, organization, role summary, account state, last activity (if available and privacy-appropriate).
- User detail page: profile summary, memberships, assigned roles, effective permissions, sessions, and audit activity.
- Role editor separates role metadata from permission grants and explains inherited permissions.
- Show who granted access and when, if the backend provides that information.
- Sensitive actions (suspend, revoke sessions, change privileged roles) require confirmation and clear impact text.
- Never expose credentials, session tokens, or secrets in tables or detail views.

### 5.3 Spatial Management

Use a library/list and a detail workspace.

List view:
- Search and filters for type, owner, tenant, lifecycle state, review state, and publication state.
- Useful metadata: name, object type, owner, last updated, state.
- Bulk actions only for safe, reversible operations.

Detail view tabs:
- **Overview:** title, type, owner, tenant, lifecycle, version.
- **Assets:** media/model files, validation, optimization and preview.
- **Placement:** coordinate/reference metadata and placement confidence where supported.
- **Visibility:** audience, sharing scope, radius or eligibility policy, with clear plain-language explanation.
- **Safety:** policy checks, restrictions, moderation decisions and provenance.
- **Versions:** revision history and rollback availability.
- **Activity:** attributable changes and publication events.

Preview mode must clearly distinguish a visual preview from authoritative real-world placement. It must never imply that an object is physically present, approved, safe, or visible to a user unless the relevant backend state confirms it. Show coordinate precision only to roles and workflows that need it.

### 5.4 Content and moderation

- Separate draft, submitted, in-review, approved, published, rejected, suspended, and archived states where supported by the domain model.
- Review queue supports filters, assignment, evidence/context, policy explanation, and decision history.
- Moderation actions must explain audience and distribution impact.
- Provide reason codes and optional reviewer notes.
- High-impact decisions require confirmation and audit attribution.
- Do not let commercial ranking or campaign controls override safety restrictions or authority decisions.

### 5.5 Marketplace and Extensions

Extension catalog cards/list rows show name, publisher, version, compatibility, lifecycle state, and review status.

Extension detail:
- Description and publisher identity
- Version history and compatibility
- Declared capabilities and permissions
- Data access and network requirements
- Resource limits and dependencies
- Review/approval history
- Install, upgrade, disable, and uninstall actions where authorized

Permission grants must be explicit and understandable. Installing or upgrading an extension should show requested capability changes before confirmation. Revocation and rollback behavior must be discoverable. Untrusted extension metadata is content, not executable UI instructions.

### 5.6 Operations

- Service health overview with last-updated timestamp and data freshness.
- Job list with state, queue time, start/end, duration, and safe retry availability.
- Event/log explorer with time range, severity, correlation/request ID, and service filters.
- Details view for failure reason and sanitized diagnostic context.
- Retry/replay actions require idempotency awareness and confirmation when duplicate side effects are possible.
- Keep technical diagnostics behind progressive disclosure for non-operator roles.
- Never display secrets, tokens, private media URLs, or exact private location data in logs.

### 5.7 Security & Audit

Audit record fields, when available:
- Actor and effective role
- Action and target
- Workspace/tenant scope
- Timestamp
- Outcome
- Reason or change summary
- Correlation ID

Provide filters by actor, action, target, outcome, and date range. Audit records are read-only in the console. Corrections should be represented as new events, not edits to history.

## 6. Shared interaction patterns

### Data tables

- Search and filters persist in URL query parameters where safe.
- Show active filter chips and a clear reset action.
- Sorting is explicit and indicated in the header.
- Pagination communicates result count and current range.
- Row click behavior is consistent; secondary actions live in an overflow menu.
- Bulk selection is disabled for actions that cannot safely operate on mixed states.
- Empty search results offer filter reset; truly empty datasets offer a relevant create/import action only if authorized.

### Detail pages

Use a consistent structure:
- Breadcrumb and title
- Status and ownership metadata
- Primary action
- Secondary actions in overflow
- Tabs for logical sections
- Activity/history section
- Sticky action footer only for long edit forms when needed

### Forms

- Group fields by user task, not database table.
- Use labels, helper text, units, examples, and inline validation.
- Mark required fields and explain constraints before submission.
- Preserve entered values after recoverable errors.
- Warn before leaving with unsaved changes.
- Prefer safe defaults; do not preselect public visibility or broad permissions.
- Use review/confirmation steps for high-impact changes.

### Status and feedback

Use text plus icon; color is supplementary. Recommended semantic roles:
- Success / active
- Warning / needs attention
- Danger / blocked or failed
- Informational / pending or neutral
- Disabled / unavailable

Every status should have a documented meaning and map to a backend state. Do not invent state transitions in the UI.

### Destructive and privileged actions

- State exactly what changes and who/what is affected.
- Use a confirmation dialog for irreversible or broad-impact actions.
- Require reason text where governance policy requires it.
- Offer undo only when the backend supports a reliable compensating action.
- Show progress and final outcome; never optimistically claim success before server confirmation.

## 7. Visual design system direction

Use a restrained, high-clarity enterprise visual language. The final palette and typography should be implemented as semantic tokens after a contrast review, not scattered hard-coded values.

### Layout and density

- 8 px base spacing rhythm.
- Page gutters: 24 px desktop, 20 px tablet, 16 px mobile.
- Card radius: 10–12 px.
- Controls: 40–44 px typical height; touch targets at least 44–48 px where practical.
- Tables: compact but readable row heights; avoid excessive card decoration.
- Use whitespace to separate task groups, not to inflate every data row.

### Color roles

Define semantic tokens for:
- Canvas, surface, elevated surface, border, divider
- Primary text, secondary text, muted text, inverse text
- Primary action and focus ring
- Success, warning, danger, information
- Selected, hover, pressed, disabled

Support light and dark themes. Validate contrast for text, icons, focus indicators, status labels, and chart elements. Do not use color alone to communicate status.

### Typography

Use a clear hierarchy for page title, section title, body, metadata, and numeric metrics. Prefer tabular numerals for metrics and timestamps. Keep long-form configuration/help text comfortably readable.

### Components

Build a shared component library only around repeated patterns:
- Admin application shell and navigation item
- Breadcrumb and page header
- Search/filter bar
- Data table and mobile record list
- Status indicator
- Metric card
- Empty/loading/error states
- Form field and validation summary
- Confirmation dialog
- Activity timeline
- Permission summary
- Preview frame with explicit preview disclaimer

## 8. Accessibility and localization

- Full keyboard operation with visible focus.
- Logical focus order and focus restoration after dialogs/drawers.
- Screen-reader labels for icon buttons, charts, table actions, and status.
- Do not communicate state by color alone.
- Support browser zoom and text scaling without clipping.
- Respect reduced-motion preferences.
- Use accessible names and descriptions for charts; provide tabular alternatives for important data.
- Prepare all user-facing copy for localization. Bahasa Indonesia and English should be first-class locales; avoid concatenated sentence fragments and hard-coded date/number formats.

## 9. UX security and privacy requirements

- Enforce authorization on the server; hiding a button is not access control.
- Clearly display the active tenant/workspace and environment before scoped actions.
- Avoid exposing exact coordinates, private location history, personal contact data, or sensitive social content without a justified permission.
- Redact secrets and private data from logs, diagnostics, analytics, screenshots, and exports.
- Do not place sensitive values in URLs, browser history, or client-side analytics.
- Require explicit confirmation for public visibility, broad permission grants, campaign activation, extension capability changes, and safety-policy overrides.
- Safety restrictions and authorized authority controls take precedence over content publishing, discovery, and advertising.

## 10. Implementation sequence

### UX-A0 — Discovery and design baseline
- Inspect backend modules, OpenAPI contracts, authentication model, tenancy model, and current deployment setup.
- Identify actual admin-capable APIs and gaps.
- Confirm web application technology and hosting boundary.
- Produce screen inventory, navigation map, and role/action matrix.
- Create low-fidelity wireframes and interaction prototypes.

### UX-A1 — Design system and shell
- Implement theme tokens, typography, responsive shell, navigation, breadcrumbs, global search entry point, and feedback patterns.
- Add accessibility foundations and visual regression baseline.

### UX-A2 — Overview and identity
- Build overview using real operational data.
- Implement users, memberships, roles, and permission inspection against existing contracts.

### UX-A3 — Spatial and content management
- Build spatial object library/detail, safe preview, visibility explanation, publishing and moderation workflows.

### UX-A4 — Extensions and marketplace
- Implement catalog, extension detail, capability review, compatibility, and lifecycle UX when backend support exists.

### UX-A5 — Operations, security, analytics
- Implement service health, jobs, sanitized logs, audit history, and privacy-aware analytics.

### UX-A6 — Quality and hardening
- Validate responsive breakpoints, keyboard/screen reader behavior, localization, error/empty/offline states, and role-based navigation.
- Run automated tests and conduct usability review with representative operator roles.

## 11. Definition of done

A screen is not complete until:
- Its data source and permission requirements are documented.
- Loading, empty, error, stale, and success states are designed.
- Primary and secondary actions are clear.
- Responsive behavior is verified.
- Keyboard and screen-reader interaction is usable.
- Destructive and privacy-sensitive actions explain their consequences.
- The UI reflects server-confirmed state and does not invent capability.
- Widget/component tests and relevant integration tests cover critical behavior.
- Documentation distinguishes implemented behavior from planned capability.

## 12. Open decisions

The following must be resolved during UX-A0 rather than assumed:
- Dedicated web app versus a web target within an existing application.
- Web framework and design-system implementation technology.
- Platform-wide versus tenant-admin entry points and default landing behavior.
- Exact role taxonomy and permission granularity.
- Which optional modules (marketplace, campaigns, analytics) are enabled in the first release.
- Which operational data is available through existing backend APIs and which contracts need to be added.
