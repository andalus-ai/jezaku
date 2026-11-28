# Offline outbox: store on the device, send when online

A frame is always saved on the device first. The outbox is what later sends it to the server, so a frame captured with no network, or before signing in, is not lost and is published by itself when it can be.

## Status

| Part | State |
|---|---|
| Outbox model, retry timing and on-device storage | Implemented (`lib/features/sync/outbox/`), unit-tested |
| Server calls: photo upload (media service) and frame create (memory service) | Implemented (`MediaApi`, `MemoryApi.create`, `ApiFramePublisher`), tested against a fake HTTP layer |
| Processor that sends what is due | Implemented (`FrameOutboxProcessor`), unit-tested with fakes |
| App wiring: `FrameOutboxController`, providers, triggers (app start, sign-in change, app resume, new capture, a timer for delayed frames) | Implemented (`lib/features/sync/states/`), tested with a fake server; **not run on a device** |
| "Waiting / refused" status with Send now, Try again, Stop sending | Implemented (`FrameOutboxStatusTile`, shown on each frame in the sync queue screen) |
| Sync queue no longer fakes "Synced" | Done when the build has both service URLs: Sync All / Send Now hand frames to the outbox, and a frame shows synced only when the server has it. Builds without the URLs keep the old device-only behaviour |
| Frames saved before the outbox existed | Picked up on sign-in if they are still "queued", have a photo-type attachment and belong to the signed-in user (or have no owner) |
| Recordings and 3D objects | Not uploaded yet: held as `unsupported`, shown as not sent |
| Look change of a published frame | Sent with `PATCH /memories/{id}/frame-style` (`FrameLookSyncer`): right after the change, and after every outbox pass, so a change made offline goes out later. The frame remembers its server id and the look the server holds (`serverMemoryId`, `serverFrameLookId`) on the device. A frame the service refuses (for example removed) is skipped. Colour is not synced |
| Audience change of a published frame (Make Private / Make Public) | Sent with `PATCH /memories/{id}/details` (`FrameAudienceSyncer`), at the same moments as looks. The frame remembers the audience the server holds (`serverAudience`). Until it is sent the frame shows "Queued update" (`AnchorSyncReason.serverUpdate`) and becomes synced once the server has every change it takes (audience and placement), unless other edits are waiting too (then it stays queued). Switching back before it is sent cancels the change. A frame the service refuses shows "Update failed" and is tried again on the next pass. **Until the change reaches the server the frame keeps its old audience there**: a frame made private while offline is still visible to others as before until the app is online. `togglePrivacy` only switches private/public; friends-only is not reachable from this button |
| Moving a published frame (calibration screen's east / north / up correction) | Sent with `PATCH /memories/{id}/anchor` (`FramePlacementSyncer`) at the same moments as looks and audience. **The server holds the corrected position**: the captured latitude / longitude shifted by the correction (metres to degrees, about 111 320 m per degree of latitude, longitude scaled by cos(latitude)) and the altitude raised by the upward correction, so other people see the frame where the owner put it. A frame published with a correction is sent at the corrected position too. The frame remembers the correction the server holds (`serverPlacementOffset`); putting it back before it is sent cancels the change. The service checks the new place like a new publish and may refuse it: the frame then shows "Update failed" and is tried again on the next pass. Heading, tilt, the AR session pose and the calibration notes stay on the device |
| Deleting a published frame | Sent with `DELETE /memories/{id}` (`FrameDeletionSyncer`). The frame disappears from the device at once, so what is still to be sent is kept as a record (`PendingDeletionStore`, key `jejaku.frame_deletions.v1`, saved with the app's preferences) until the service confirms: a deletion made offline, or with the app closed before the call, is sent on a later pass (same moments as looks and audience, plus right after the delete). A 404 counts as deleted; a refusal (403) keeps the record and is retried each pass, nothing is dropped without an answer; a record belongs to the user who deleted it and is only sent with that user's sign-in. A frame deleted while it was being sent for the first time is deleted on the service as soon as the send finishes. A frame that never reached the service has nothing to delete there. There is no screen showing waiting deletions yet. Photos already uploaded to the media service are not removed by this call |
| Other edits to a frame already on the server (caption, AR pose, cloud anchor, recording review) | **Not sent**: the sync queue says so instead of marking them synced. The caption cannot be edited after capture in the app; the service accepts it on the same details endpoint |
| Real device / real network / real services validation | **Not done** |

## Turning it on

Build with both `JEZAKU_MEMORY_URL` and `JEZAKU_MEDIA_URL` (the production build scripts pass them through, e.g. `http://10.0.2.2:8108` for the media service on an Android emulator). With either one missing, or in an `OFFLINE_MODE` build, there is no outbox and frames stay on the device exactly as before.

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

There is no connectivity plugin on purpose: a failed call is the signal, and the triggers (app resume, sign-in, new capture, "send now") and a timer set for the earliest delayed frame are what make a frame go out once the network is back.

## Rules

- Never discard a waiting frame because a send failed. Only a deleted local frame, or an explicit discard by the user, removes an entry, and discarding only gives up the upload: the frame stays on the device.
- Demo (offline) builds have no memory/media service configured and keep every frame on the device only; the outbox is for production builds with the service URLs set.
- The anchor type sent to the service is `hybrid` for a frame hung in AR and `geo` otherwise (the service knows only `geo`, `visual` and `hybrid`). Accuracy, pitch and roll outside what the service accepts are left out instead of failing the whole frame.

## Checklist for a physical device (not done yet)

Build with `JEZAKU_MEMORY_URL`, `JEZAKU_MEDIA_URL` and `JEZAKU_IDENTITY_URL`, signed in, services running.

- [ ] Airplane mode on, capture a photo frame: it appears on the device; the sync queue shows "Waiting for a connection" and the frame is not "Synced".
- [ ] Airplane mode off, bring the app to the foreground: within a few seconds the frame is created on the server (check `GET /memories/{id}`) and shows "Synced"; no second copy appears in the AR viewer.
- [ ] Kill the app while a frame waits, reopen it: the frame is still waiting and is sent.
- [ ] Cut the connection in the middle of the photo upload: after reconnecting the frame is created once (one media record, one memory).
- [ ] A **public** frame: it shows "Photo is being checked" until moderation approves the photo, then is created by itself.
- [ ] Sign out with a frame waiting: it shows "Sign in to send" and is sent after signing in again; signing in as a different user does not send the first user's frame as theirs.
- [ ] A refused frame (for example the service stopped, or the photo rejected): "Try again" and "Stop sending" both work, and "Stop sending" keeps the frame on the device.
- [ ] Change the look of a published frame with airplane mode on, then back online: `GET /memories/{id}` returns the new `frameStyle` after the app is brought to the foreground; another device sees the frame in the new look.
- [ ] Make a published frame private with airplane mode on: the detail screen shows "Queued update" and the frame stays "Make Public"-labelled locally; back online and foregrounded, `GET /memories/{id}` shows `visibility: private`, the frame shows "Synced", and another account no longer sees it.
- [ ] Make a published frame private, then public again before reconnecting: no request is sent and the frame shows "Synced".
- [ ] Delete a published frame with airplane mode on, then back online and foregrounded: `GET /memories/{id}` answers 404 and the frame is gone for other accounts; it never reappears on the device.
- [ ] Delete a published frame, then close the app before it reconnects: the deletion is still sent after reopening and signing in.
- [ ] Nudge a published frame 5 m north on the calibration screen with airplane mode on, then reconnect: `GET /memories/{id}` shows the position about 5 m further north, the frame shows "Synced", and an account standing at the new spot sees it (and one at the old spot 25 m away does not).
