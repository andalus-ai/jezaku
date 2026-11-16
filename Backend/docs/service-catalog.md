# Backend Service Catalog

The parent Maven project is `Backend/pom.xml`. The following catalog reflects the current service inventory documented by `Backend/README.md` and `Backend/service-ports.md`.

| Module | Port | Primary ownership |
|---|---:|---|
| `identity` | 8101 | Accounts, sessions, guardian links, trusted devices |
| `profile` | 8102 | Public profiles, privacy, parental controls |
| `social` | 8103 | Friends, family, groups, communities, blocks, audience decisions, social graph/content |
| `memory` | 8104 | Camera memories, nearby memory feed, minimap dots |
| `spatial-trails-places` | 8105 | AR anchors, trails, place discovery |
| `events` | 8106 | Nearby events, RSVP, check-ins, invitations |
| `notifications` | 8107 | Notification inbox, preferences, device registration |
| `media` | 8108 | Upload slots, media inventory, moderation state |
| `presence` | 8109 | Live location, altitude/compass context, nearby user dots |
| `safety` | 8110 | Reports, moderation review, guardian safety zones |
| `engagement` | 8111 | Reactions, comments, bookmarks, engagement summaries |
| `discovery` | 8112 | Nearby discovery, spatial search, feedback signals |
| `journeys` | 8113 | Guided journeys, checkpoint progress, badge rewards |
| `messaging` | 8114 | Direct, group, and spatial-context conversations |
| `rewards` | 8115 | XP, badges, streaks, reward profiles, leaderboards |
| `camera` | 8116 | Camera HUD context, sessions, safety zones, minimap overlays |

## Shared module

`common` is a Maven library module and has no standalone service port. It contains shared technical infrastructure and geospatial primitives.

## Local API exploration

Each service exposes its Quarkus Swagger UI and OpenAPI document using the standard paths:

- Swagger UI: `http://localhost:<port>/q/swagger-ui`
- OpenAPI: `http://localhost:<port>/q/openapi`

See [../service-ports.md](../service-ports.md) for the complete URL table. Keep this catalog and that file synchronized when ports or module ownership changes.
