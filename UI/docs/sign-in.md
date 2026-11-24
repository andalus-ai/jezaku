# Sign-in (client seam)

Status: built and unit/widget-tested. Not yet run against a live identity service, and not checked on a device.

## The rule

- **Production (strict) builds require sign-in**; **demo / prototype builds bypass it** so the UI and AR objects keep working offline.
- The gate is on only when the build is strict **and** has an identity service (`--dart-define=JEZAKU_IDENTITY_URL=...`). A strict build with no URL has no sign-in screen, so existing production-script builds do not become unusable. The release scripts pass `JEZAKU_IDENTITY_URL` from the environment (empty = no gate).
- The client gate is a convenience. The backend is the authority and refuses unauthenticated requests.

## What exists (`lib/features/auth/`)

| File | Role |
|---|---|
| `models/auth_session.dart` | `AuthSession` (user id, session id, tokens, expiry). `toString` never prints tokens |
| `services/auth_gateway.dart` | `AuthGateway` interface; `HttpAuthGateway` (`POST /identity/sessions`, `DELETE /identity/sessions/{userId}/{sessionId}`); `UnavailableAuthGateway`; `AuthFailure` (invalid credentials / network / server / unavailable) |
| `states/auth_providers.dart` | `authGatewayProvider`, `authControllerProvider` (sign in, sign out, busy and failure state), `signedInUserIdProvider`, `httpAuthGatewayOverride` |
| `states/sign_in_requirement.dart` | `signInRequiredProvider` (strict + gateway available) |
| `screens/sign_in_screen.dart`, `widgets/sign_in_gate.dart` | The screen (loading, error, show/hide password, autofill, live-region errors) and the gate wrapped around the app in `main.dart` |
| `widgets/account_settings_tile.dart` | "Signed in" + Sign out (with confirmation) in Settings; hidden when nobody is signed in |

`currentUserIdProvider` (used by the frame audience rule) now comes from the signed-in session. In demo builds nobody signs in, so it stays null and behaviour is unchanged.

## Behaviour notes

- The identity service answers a wrong password, an unknown user and an inactive account all with 403; the client shows one message for all of them and never says which field was wrong.
- Sign out drops the local session first, so the user is signed out even if the service cannot be reached; ending the session on the service is best effort.

## Known limits

- **The session is memory-only.** Tokens are not written to ordinary app storage, so the user signs in again after a restart. Secure persistence (platform keystore) comes with the API client.
- **No token refresh and no authenticated API calls yet.** Nothing else in the app sends the access token; `friendIdsProvider` is still empty until the social client exists.
- No account creation or password reset screens.
- The offline AR test mode (`--dart-define` arOfflineTestMode) is not exempted; run it as a demo build.
