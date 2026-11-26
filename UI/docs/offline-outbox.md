# Offline outbox: store on the device, send when online

A frame is always saved on the device first. The outbox is what later sends it to the server, so a frame captured with no network, or before signing in, is not lost and is published by itself when it can be.

## Status

| Part | State |
|---|---|
| Outbox model, retry timing and on-device storage | Implemented (`lib/features/sync/outbox/`), unit-tested, **not yet wired to the app** |
| Server calls: photo upload (media service) and frame create (memory service) | Implemented (`MediaApi`, `MemoryApi.create`, `ApiFramePublisher`), tested against a fake HTTP layer |
| Processor that sends what is due | Implemented (`FrameOutboxProcessor`), unit-tested with fakes |
| Providers, triggers (app start, resume, sign-in, new capture), "waiting" status in the UI | **Not started** (next slice) |
| Replacing the simulated `AnchorSyncCoordinator` | **Not started**: it still marks frames "Synced" without any network call; do not trust that status until it is replaced |
| Recordings and 3D objects | Not uploaded yet: held as `unsupported` |
| Changing a published frame's look or placement later | Not synced (no backend endpoint for the look yet) |
| Real device / real network validation | **Not done** |

## How a frame travels

```
queued --photo uploaded--> mediaUploaded --frame created--> published --acknowledged--> (removed)
```

- Each step is saved as soon as it succeeds. A dropped connection after the photo went up resumes at "create the frame"; it never uploads the photo again. A frame that was created but not yet recorded locally is acknowledged on the next pass instead of being created twice.
- A **public** frame needs its photo approved by moderation before the server will create it. Until then it waits as `awaitingReview` and is checked again every 5 minutes; friends-only and private frames do not wait.
- The photo goes to the storage address the media service hands out (signed for that upload), and that request does not carry the access token.

## Why a frame is waiting (`OutboxHold`)

| Hold | Meaning | Retried by itself? |
|---|---|---|
| `offline` | No connection, or the service did not answer | Yes: 15 s, doubling to 15 min |
| `serverBusy` | 5xx, 408, 429, or an answer the app could not read | Yes, same timing |
| `awaitingReview` | Public frame, photo not approved yet | Yes, every 5 min |
| `signInRequired` | Nobody is signed in, or the session was refused (401) | No: released when a user is signed in |
| `rejected` | The service refused the frame or photo (other 4xx, 403, rejected photo) | No: needs the user (retry or discard) |
| `unsupported` | This kind of frame cannot be uploaded yet | No |

No connection, a busy service and a missing sign-in stop the pass, since the next frame would hit the same problem and its attempts would be wasted. A refusal of one frame does not stop the others.

There is no connectivity plugin on purpose: a failed call is the signal, and the triggers (resume, sign-in, new capture, "sync now") are what make a frame go out promptly once the network is back.

## Rules

- Never discard a waiting frame because a send failed. Only a deleted local frame, or an explicit discard by the user, removes an entry, and discarding only gives up the upload: the frame stays on the device.
- Demo (offline) builds have no memory/media service configured and keep every frame on the device only; the outbox is for production builds with the service URLs set.
- The anchor type sent to the service is `hybrid` for a frame hung in AR and `geo` otherwise (the service knows only `geo`, `visual` and `hybrid`). Accuracy, pitch and roll outside what the service accepts are left out instead of failing the whole frame.
