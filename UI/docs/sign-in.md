# Sign-in (client seam)

Status: built and unit/widget-tested. Not yet run against a live identity service, and not checked on a device.

## The rule

- **Production (strict) builds require sign-in**; **demo / prototype builds bypass it** so the UI and AR objects keep working offline.
- The gate is on only when the build is strict **and** has an identity service (`--dart-define=JEZAKU_IDENTITY_URL=...`). A strict build with no URL has no sign-in screen, so existing production-script builds do not become unusable. The release scripts pass `JEZAKU_IDENTITY_URL` from the environment (empty = no gate).
- The client gate is a convenience. The backend is the authority and refuses unauthenticated requests.

## What exists (`lib/features/auth/`)

| File | Role |
|---|---|
| `models/auth_session.dart` | `AuthSession` (user id, session id, tokens, expiry, `needsRefreshAt`). `toString` never prints tokens |
| `services/session_store.dart`, `services/secure_session_store.dart`, `services/auth_session_codec.dart` | `SessionStore` (read / write / clear; `NoSessionStore` by default), `SecureSessionStore` (Keychain / Android Keystore via `flutter_secure_storage`) and the strict JSON codec |
| `services/auth_gateway.dart` | `AuthGateway` interface; `HttpAuthGateway` (`POST /identity/sessions`, `POST /identity/sessions/refresh`, `DELETE /identity/sessions/{userId}/{sessionId}`); `UnavailableAuthGateway`; `AuthFailure` (invalid credentials / network / server / unavailable) |
| `states/auth_providers.dart` | `authGatewayProvider`, `authControllerProvider` (sign in, sign out, restore, refresh, busy / restoring / failure state), `sessionStoreProvider`, `signedInUserIdProvider`, `httpAuthGatewayOverride` |
| `states/sign_in_requirement.dart` | `signInRequiredProvider` (strict + gateway available) |
| `screens/sign_in_screen.dart`, `widgets/sign_in_gate.dart` | The screen (loading, error, show/hide password, autofill, live-region errors) and the gate wrapped around the app in `main.dart` |
| `widgets/account_settings_tile.dart` | "Signed in" + Sign out (with confirmation) in Settings; hidden when nobody is signed in |

`currentUserIdProvider` (used by the frame audience rule) now comes from the signed-in session. In demo builds nobody signs in, so it stays null and behaviour is unchanged.

## Behaviour notes

- The identity service answers a wrong password, an unknown user and an inactive account all with 403; the client shows one message for all of them and never says which field was wrong.
- Sign out drops the local session first, so the user is signed out even if the service cannot be reached; ending the session on the service is best effort.

## Calling services with the token (`lib/features/api/`, `lib/features/remote_frames/`)

- `AuthInterceptor` adds `Authorization: Bearer <token>` to each request (token read at request time) and, on a 401 to a request that carried our token, reports the rejected token. `authInterceptorFor(ref)` signs the user out only if that token is still the current one, so a late 401 never ends a newer sign-in.
- `MemoryApi` reads `GET /memories/nearby` and `GET /memories/users/{userId}`. The service decides what the caller may see (friends, on-site radius); the client only asks and parses. Failures are `notAllowed` (401/403), `network` or `server`.
- `RemoteFrame` is the wire model. It drops unusable entries (no id, owner or position, coordinates off the globe) without hiding the rest, and reads an unknown or missing `visibility` as **private** so a value this build does not know can never widen who sees a frame.
- `memoryApiProvider` is null (stay offline) unless the build passes `--dart-define=JEZAKU_MEMORY_URL=...`.
- The AR viewer uses it through `viewerAnchorsProvider` (see "Other people's frames in the viewer" below).

## Other people's frames in the viewer (`remote_frames/`)

- `viewerAnchorsProvider` = the user's own frames (local store) + other people's frames from `MemoryApi.nearby`. The AR viewer and the photo page read it instead of the local list. Remote frames are **never** written to the local store, so they are not part of My frames, sync or upload.
- Loading is `RemoteFramesController`, kept fresh by `remoteFramesAutoRefreshProvider` while something watches `viewerAnchorsProvider`: only with a memory service (`JEZAKU_MEMORY_URL`), a signed-in user and a **live** location fix (the development fallback origin is never sent). It asks within 100 m, again after the viewer moves 25 m or 60 s pass, excludes the user's own frames, keeps the last good frames when a query fails, and forgets everything on sign-out or when another user signs in (a late answer for a previous user is discarded).
- `RemoteFrameMapper` turns a service frame into an `AnchorMemory` carrying the owner id and the service's audience, so the normal visibility policy applies unchanged: friends-only frames of others stay hidden until the friend list has loaded (see "Friends" below), and the 20 m on-site radius still applies. Only an explicit `approved` moderation status shows a frame; anything else is hidden.
- Pictures: up to 8 thumbnails per query (nearest first) are fetched over plain HTTP(S) with `HttpRemoteMediaLoader` (absolute http/https only, 4 MB cap, **no sign-in token sent** because picture URLs may point at another host) and kept in memory. A frame whose picture is missing hangs as a plain frame.

## Friends (`lib/features/friends/`)

- `SocialApi.friendIds(userId)` reads `GET /social/friends/{userId}` (100 per page, following `nextCursor`, at most 20 pages) and returns the friends' user ids. Entries without a usable id are skipped; a body that is not `{friends: [...]}` is a `server` failure. Failures use the same `ApiFailure` reasons as the memory client (shared in `lib/features/api/api_failure.dart`).
- `FriendsController` (`friendsProvider`) holds the ids, `loaded`, `loading` and the last failure. It asks only with a social service (`JEZAKU_SOCIAL_URL`) and a signed-in user, at most every 5 minutes, keeps the last good ids when a refresh fails, and tags the ids with the user they belong to. `friendIdsProvider` only returns ids that belong to the signed-in user, so another user never sees the previous user's friends even for a moment; the auto refresh also drops them on sign-out. A late answer for a previous user is discarded.
- `friendsAutoRefreshProvider` runs while `viewerAnchorsProvider` is watched: it loads on sign-in and re-checks on location updates.
- `friendIdsProvider` now reads `friendsProvider`, so in strict builds `FrameViewerContext.forUser` classes a loaded friend's frame as a friend's. **Fail closed:** until the first answer (or when the service is unreachable) the list is empty and friends-only frames of others stay hidden. Demo builds treat everyone as a friend and never call the service.
- Build with `--dart-define=JEZAKU_SOCIAL_URL=http://host:8103` (the release scripts pass it from the environment; empty means off).

## Staying signed in (session persistence and refresh)

- With an identity service (`JEZAKU_IDENTITY_URL`), `main.dart` gives the app a `SecureSessionStore`. Sign-in saves the session, sign-out deletes it, and a refresh replaces it. Tokens live only in the platform keystore, never in shared preferences. Builds without an identity service keep nothing.
- **Startup:** `AuthController.restore()` reads the saved session while the gate shows a spinner (not the sign-in screen). A still-valid session signs in with no network; an expired one is refreshed (`POST /identity/sessions/refresh`); if the service refuses, the saved session is deleted and sign-in shows; if the service cannot be reached the saved session is kept for the next start. An unreadable or corrupt store means signing in again.
- **Before a request:** `authenticatedDio` asks the controller for a fresh token; one that expires within 60 s is refreshed first. The service **rotates** the refresh token (the old session is revoked), so refreshes are single-flight and the new session is saved before it is used again.
- **On a 401:** the controller tries one refresh and signs out only if the service refuses the refresh token. A token refused again within 10 s of a refresh is treated as refused (sign out), so a service that rejects our tokens cannot cause a refresh loop. A late 401 for an older token changes nothing.
- A sign-out (or another user signing in) while a refresh or save is in flight drops the answer and removes anything saved.

## Known limits

- **Session persistence and refresh are built but not validated on a device or against a live identity service.** The keystore plugin (`flutter_secure_storage`) has only been compiled by CI; `pubspec.lock` was not regenerated here (no Flutter SDK), run `flutter pub get` and commit it. Android backup of keystore-encrypted data and iOS keychain-after-reinstall behaviour need a device check.
- Offline at startup with an expired access token: the user sees the sign-in screen (the saved session is kept and retried at the next start). A refresh the service refuses deletes the saved session.
- No account creation or password reset screens.
- **Remote frames are view-only.** The focused-frame panel and the photo page offer Change frame, Calibrate, Re-hang and Details only for the viewer's own frames (`FrameOwnerActions`); someone else's frame, a friend's included, keeps Photo & comments and Recenter. Not yet checked on a device.
- Remote pictures are held in memory only (no disk cache), the 4 MB cap is applied after download, and the photo page shows the thumbnail only (no full image or comments for remote frames yet).
- Friends are re-checked at most every 5 minutes, so a removed friend can still see your friends-only frames on site for a few minutes (the backend decides what it sends; this is the client's second line).
- The offline AR test mode (`--dart-define` arOfflineTestMode) is not exempted; run it as a demo build.
