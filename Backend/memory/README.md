# Jezaku Memory Service

Stores camera-captured memories and projects public memories into nearby feeds and minimap dots.

`POST /memories` accepts capture position, altitude, heading, compass, optional `anchorType`, `gpsAccuracyMeters`, `pitchDegrees`, and `rollDegrees`. New clients should attach uploaded media with `mediaId`; the service resolves the media URL and thumbnail, checks ownership, snapshots media and moderation status, and only allows public memories when the linked media is approved. Raw `mediaUrl` and `thumbnailUrl` remain supported for legacy capture clients as external, unverified media. `PUT /memories/media/{mediaId}/snapshot` lets the media service refresh one linked media snapshot after moderation or deletion, while `PUT /memories/media/snapshots` accepts up to 100 media-event snapshots, deduplicates repeated media IDs by highest event sequence, reports unmatched and stale media IDs separately, and returns total affected memory counts for cursor-based sync from `GET /media/events`. Batch sync tracks the last accepted sequence per media ID so duplicate events are idempotent and stale older events cannot reopen rejected or deleted public memories. Linked public memories whose media is no longer approved are removed from public feed, nearby, and minimap surfaces while remaining readable by direct/owner flows. Memory responses, nearby dots, and minimap dots include `mediaStatus`, `moderationStatus`, `memoryAttachable`, and `publicMemoryEligible` so feed and camera clients can distinguish media-service-backed memories from legacy external media without a second lookup. `PATCH /memories/{id}/anchor` lets the owner refine those anchor fields after AR stabilization or a manual placement nudge, and `GET /memories/{id}/anchor/history?ownerId=...` returns the owner-only capture/refinement revision trail. Responses include an `anchor` object with placement `quality`, `arReady`, current `revision`, `source`, and `updatedAt` so AR camera clients can distinguish reliable geospatial frames from softer discovery markers without always fetching history.

Core endpoints:

- `POST /memories`
- `GET /memories/{id}`
- `PATCH /memories/{id}/anchor`
- `GET /memories/{id}/anchor/history`
- `PUT /memories/media/{mediaId}/snapshot`
- `PUT /memories/media/snapshots`
- `GET /memories/nearby`
- `GET /memories/minimap`
- `GET /memories/feed`
- `GET /memories/users/{userId}`
- `DELETE /memories/{id}`

This project uses Quarkus, the Supersonic Subatomic Java Framework.

If you want to learn more about Quarkus, please visit its website: <https://quarkus.io/>.

## Who can read a memory

An authenticated caller always reads their own memories. Anyone else sees a memory only if it is shared with them:

- `public` (and approved media): everyone except people the owner blocked.
- `friends`: the owner's direct, unblocked friends. The service asks the social service (`POST /social/relationships/context/batch`, scope `social:audience`, this service's own token) and applies the answer to `GET /memories/{id}` and `GET /memories/users/{userId}`.
- `private`: the owner only.

A memory a caller may not see looks absent (404). `jezaku.memory.friends-visibility.enforced` (default `false`, like `jezaku.auth.required`) switches the friend lookup on; while off, `friends` memories are visible to their owner alone. If the social service cannot be reached the lookup returns nothing, so `friends` memories stay hidden (fail closed) while public ones are unaffected. Configure `jezaku.memory.social-base-url`, `jezaku.auth.service-secret` and the `social:audience` scope in production.

### On-site viewing

Other people's memories are read only on site. With `jezaku.memory.on-site-view.enforced=true` (production; off by default, like `jezaku.auth.required`) an authenticated caller reads their own memories from anywhere, and anyone else's only while within `jezaku.memory.on-site-view.radius-meters` (default 20) of the `lat`/`lng` they report:

- `GET /memories/{id}`: a non-owner without a position, or outside the radius, gets 404.
- `GET /memories/users/{userId}`: empty for anyone but that user; browsing a profile does not reveal frames.
- `GET /memories/feed`, `/nearby`, `/minimap`: the caller's own memories plus others' that are shared with them (public, or friends-only for friends) and within reach. `radiusMeters` can narrow the reach for others, never widen it; the caller's own memories still use the requested radius. With enforcement on, the caller's own non-public memories also appear in these listings.

Anonymous callers (authentication not enforced) are never restricted. The position is client-reported, so this stops browsing rather than a determined spoofer; it sits alongside the audience and moderation checks. The client enforces the same rule in `UI/docs/frame-visibility-and-roadmap.md` (`strict` mode).

### Spatial publishing enforcement

Production defaults to `jezaku.memory.spatial-safety.enforced=true`. Before `POST /memories` persists a frame, and before `PATCH /memories/{id}/anchor` persists a relocation, Memory calls the Safety service's `POST /safety/spatial/evaluate` endpoint with activity `PUBLISH`. `ALLOWED` and `CAUTION` proceed; restricted outcomes return 403. Missing configuration, an unavailable Safety service, or an invalid evaluation response returns 503 and does not save the frame or anchor change.

Configure `JEZAKU_SAFETY_BASE_URL` (or `jezaku.memory.spatial-safety.base-url`) and grant the Memory service the `spatial:policy-evaluate` service-token scope. Local development and tests explicitly disable this remote check so offline demos and isolated tests continue to run; production must not disable it.

The policy is evaluated at the requested destination anchor. The coordinate is still device-submitted capture/placement data, not hardware-attested proof of the publisher's physical location. This check enforces rules against the stored placement but does not prevent GPS spoofing.

Before returning a memory through public detail, feed, nearby, or minimap surfaces, Memory also evaluates the stored anchor with activity `RENDER`. A policy denial hides that frame from the public render surface; a Safety-service outage fails closed with 503. The owner's own direct read and `/memories/users/{userId}` gallery remain available independently of public render policy. This is distinct from the on-site visibility rule: on-site checks govern who may browse another person's content, while spatial `RENDER` rules govern whether the content may be exposed at that location.

## Running the application in dev mode

You can run your application in dev mode that enables live coding using:

```shell script
./mvnw compile quarkus:dev
```

> **_NOTE:_**  Quarkus now ships with a Dev UI, which is available in dev mode only at <http://localhost:8080/q/dev/>.

## Packaging and running the application

The application can be packaged using:

```shell script
./mvnw package
```

It produces the `quarkus-run.jar` file in the `target/quarkus-app/` directory.
Be aware that it’s not an _über-jar_ as the dependencies are copied into the `target/quarkus-app/lib/` directory.

The application is now runnable using `java -jar target/quarkus-app/quarkus-run.jar`.

If you want to build an _über-jar_, execute the following command:

```shell script
./mvnw package -Dquarkus.package.jar.type=uber-jar
```

The application, packaged as an _über-jar_, is now runnable using `java -jar target/*-runner.jar`.

## Creating a native executable

You can create a native executable using:

```shell script
./mvnw package -Dnative
```

Or, if you don't have GraalVM installed, you can run the native executable build in a container using:

```shell script
./mvnw package -Dnative -Dquarkus.native.container-build=true
```

You can then execute your native executable with: `./target/memory-1.0.0-SNAPSHOT-runner`

If you want to learn more about building native executables, please consult <https://quarkus.io/guides/maven-tooling>.

## Related Guides

- REST ([guide](https://quarkus.io/guides/rest)): Build RESTful web services and APIs using Jakarta REST (formerly JAX-RS)
- REST Jackson ([guide](https://quarkus.io/guides/rest#json-serialisation)): Jackson serialization support for Quarkus REST. This extension is not compatible with the quarkus-resteasy extension, or any of the extensions that depend on it
- SmallRye Health ([guide](https://quarkus.io/guides/smallrye-health)): Monitor service health
- Messaging - Kafka Connector ([guide](https://quarkus.io/guides/kafka-getting-started)): Connect to Kafka with Reactive Messaging
- Reactive PostgreSQL client ([guide](https://quarkus.io/guides/reactive-sql-clients)): Connect to the PostgreSQL database using the reactive pattern

## Provided Code

### Messaging codestart

Use Quarkus Messaging

[Related Apache Kafka guide section...](https://quarkus.io/guides/kafka-reactive-getting-started)


### REST

Easily start your REST Web Services

[Related guide section...](https://quarkus.io/guides/getting-started-reactive#reactive-jax-rs-resources)

### SmallRye Health

Monitor your application's health using SmallRye Health

[Related guide section...](https://quarkus.io/guides/smallrye-health)
