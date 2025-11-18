# Yapt (iOS) — Product Requirements Document

- Internal project name: yapt-ios
- User-facing name: Yapt
- Platforms: iOS (iPhone; iPad optional later)
- Minimum OS: iOS 16.0+ (native Passkeys support, modern SwiftUI APIs)
- Tech stack: Swift 5.9+, SwiftUI, MVVM, Combine, URLSession (native), WebAuthn passkeys (ASAuthorization APIs)
- Backend: Existing Yapt Fastify/TypeScript API served under `/api` (cookie-based session)
- Out of scope: Android, wallet private-key custody, on-chain tx signing

## 1. Overview & Goals

Yapt for iOS provides a fast, privacy-preserving dashboard for DeFi yield across multiple Ethereum wallets. It mirrors backend behavior: stablecoin-denominated value, APY projections, and reward-based positions that hide APY and show absolute yield projections.

Primary goals:
- Deliver a performant, mobile-first dashboard for existing Yapt users.
- Allow users to add wallets and run discovery from the app.
- Provide configurable notifications (depeg, APY drops) with an in-app feed and push notifications.

Non-goals (initial phases):
- Creating transactions, swapping assets, or key custody.
- Managing RPC providers from the app.
- Multi-tenancy or complex roles (backend remains single-tenant with sessions).

Success metrics (directional):
- TTI to dashboard < 2s on warm start (Wi‑Fi, logged in).
- Wallet discovery progress shown within 1s of start; completion matches backend counts.
- Notifications settings adoption > 30% of active users.
- Crash-free sessions ≥ 99.8%.

## 2. Users & Use Cases

Primary user: existing Yapt user with one or more wallets tracked in backend.

Key use cases:
- Log in with passkey, view all wallets’ combined portfolio and income projections.
- Review per-wallet positions; understand APY or absolute yield depending on measurement method.
- Add a new wallet by address or ENS; monitor live discovery progress.
- Configure alerts (stablecoin depegs, APY changes) and see a notification history.

## 3. Phased Scope

### Phase 1 — Auth + Dashboard (existing users)

Scope
- Authentication
  - Passkey login using backend WebAuthn endpoints.
  - Session cookies persisted via `HTTPCookieStorage` (backend uses cookie sessions).
  - Show logged-in user via `/api/auth/me`.
- Dashboard
  - Overall portfolio summary (value, estimated daily/monthly/yearly), aggregated across user’s wallets: `GET /api/portfolio/summary`.
  - Positions list with latest metrics: `GET /api/positions`.
    - Respect backend semantics: positions with `measureMethod: "rewards"` hide APY fields and show absolute yield projections.
  - Wallets list: `GET /api/wallets`.
  - Position snapshots (detail screen): `GET /api/positions/:id/snapshots` (optional in Phase 1; recommended for detail view sparklines).
- UX
  - Tab layout: Dashboard, Wallets, Positions, Settings.
  - Manual refresh button with clear feedback; if backend enforces cooldowns (e.g., portfolio refresh guard), show non-blocking message and keep cached data.

Out of scope for Phase 1
- New wallet onboarding.
- Registration and “add device” flows (assume existing accounts/passkeys; passkeys typically sync via iCloud).

Acceptance criteria
- A logged-in user can see accurate totals and positions matching web/DB values.
- Reward-based positions hide APY and show absolute projections.
- Errors (auth expired, network) are handled gracefully with retry and user-friendly copy.

### Phase 2 — Add Wallet & Discovery

Scope
- Add wallet
  - Input address or ENS; validate locally (basic format) and server-side.
  - Start discovery with server-sent events (SSE) progress stream: `POST /api/wallets/discover` (preferred) or `POST /api/wallets` (background discovery, no live progress).
  - Show real-time progress: protocol started/completed, positions found, totals; final success state.
  - For existing wallets, allow rescans for newly supported protocols via SSE: `POST /api/wallets/:id/scan`.
  - List, remove user-tracked wallets: `GET /api/wallets`, `DELETE /api/wallets/:id`.
- UX
  - “Add wallet” flow with ENS resolution feedback and discovery progress UI.
  - Wallet detail screen: positions for that wallet, last updated, quick rescan.

Acceptance criteria
- New wallet inserted and linked to user; discovery progress is streamed and rendered until completion.
- ENS resolution success/failure surfaced to the user.
- Removing a wallet updates the dashboard totals immediately.

### Phase 3 — Notifications

Scope
- Settings
  - Read/update notification settings via:
    - `GET /api/notifications/settings`
    - `PUT /api/notifications/settings`
  - Controls: enable/disable depeg and APY alerts; severities (`min`, `low`, `default`, `high`, `urgent`), thresholds; optional stablecoin symbol filters.
  - Show user’s `ntfyTopic` when present (read-only), for transparency.
- Notification feed
  - History with pagination/filters: `GET /api/notifications/history?limit=&offset=&type=`.
  - Tap to view details (title, message, metadata rendered simply).
- Push delivery
  - Phase 3a (in-app, no background): live updates when app is active by polling or lightweight background refresh; show banners/toasts.
  - Phase 3b (APNs): register device token and receive push for new alerts.
    - App API (proposed): `POST /api/notifications/devices` to bind APNs token to current user; `DELETE` to unregister. Backend to fan-out APNs on new alerts in addition to existing ntfy flows.
    - If APNs server work is deferred, keep in-app feed and foreground toasts; push arrives once APNs integration is ready.

Acceptance criteria
- Users can configure and persist notification settings, and see a history feed that matches backend logs.
- If APNs is enabled, pushes arrive within 30s of alert creation; tapping opens the app to the relevant screen.

## 4. Functional Requirements

Authentication (Phase 1)
- Use WebAuthn endpoints with cookie-based sessions:
  - `POST /api/auth/login/generate-options` with `{ username }`.
  - Native passkey assertion via ASAuthorization APIs.
  - `POST /api/auth/login/verify` with assertion; on success, backend sets session cookie.
- Maintain session via `URLSessionConfiguration` with shared `HTTPCookieStorage`.
- `GET /api/auth/me` for current user info.
- Logout: clear cookies for API domain; reset app state.

Passkeys (iCloud Keychain + 1Password)
- Use `ASAuthorizationPlatformPublicKeyCredentialProvider` for assertions; system sheet surfaces available passkeys from iCloud Keychain and third‑party providers (e.g., 1Password) when enabled in iOS Settings > Passwords.
- No special SDK integration is required for 1Password; the system Passkeys sheet handles provider selection.
- Requirements:
  - Configure Associated Domains with `webcredentials:<RP_ID domain>` (e.g., `webcredentials:app.yourdomain.com`). Host an AASA file enabling webcredentials for the app. RP_ID must match backend `RP_ID`.
  - Use a real domain for RP_ID in staging/production. Avoid `localhost` for native passkeys; use a reachable dev domain if testing on device.
  - Transform `ASAuthorizationPlatformPublicKeyCredentialAssertion` fields into WebAuthn `AuthenticationResponseJSON` (base64url encode `rawId`, `authenticatorData`, `clientDataJSON`, `signature`, `userHandle`) to satisfy `@simplewebauthn/server`.
  - Ensure cookie policy allows session cookies to be set and reused by the app (first‑party requests from the app are not subject to browser third‑party rules).

Dashboard & Data (Phase 1)
- Portfolio summary: `GET /api/portfolio/summary` (valueUsd, estDaily/Monthly/Yearly, asOf, positions excerpt).
- Positions: `GET /api/positions` includes value, APY/absolute yield semantics, lastUpdated, summary actual 24h/7d/30d yields.
- Snapshots (optional detail): `GET /api/positions/:id/snapshots?from=&to=`.
- Wallets: `GET /api/wallets` returns wallet IDs, addresses, ENS names; used for filtering.

Wallet Management & Discovery (Phase 2)
- Add wallet with address or ENS:
  - `POST /api/wallets/discover` (SSE) to create/link wallet and stream discovery progress.
  - Alternate: `POST /api/wallets` (no live stream) + background progress message.
- Rescan: `POST /api/wallets/:id/scan` (SSE). Show same progress UI.
- Remove wallet: `DELETE /api/wallets/:id`.
- Optional ENS backfill: `POST /api/wallets/backfill-ens` (for completeness; admin UI may already handle).

Notifications (Phase 3)
- Settings: `GET`/`PUT /api/notifications/settings` with fields:
  - `depegEnabled`, `depegSeverity`, `depegLowerThreshold`, `depegUpperThreshold`, `depegSymbols`.
  - `apyEnabled`, `apySeverity`, `apyThreshold`.
  - `ntfyTopic` (read-only to the app; backend generates when enabling notifications).
- History: `GET /api/notifications/history?limit=&offset=&type=`.
- Push (proposed app endpoints):
  - Register APNs token: `POST /api/notifications/devices { token, platform: "ios" }`.
  - Unregister: `DELETE /api/notifications/devices/:deviceId`.

## 5. Non-Functional Requirements

- Performance
  - Use caching of last successful responses for instant rendering; refresh in background.
  - Avoid aggressive polling; respect backend cooldowns (e.g., portfolio manual refresh guard, 5 minutes). Surface cooldown status to user.
- Reliability
  - Exponential backoff on recoverable network errors; offline mode shows cached data with timestamp.
- Security & Privacy
  - ATS enabled; cookies only to backend domain; no third-party SDKs sending PII.
  - Do not log sensitive payloads. Opt-in analytics only; minimal device metadata.
  - Use native passkeys. No password storage.
- Accessibility
  - Dynamic Type, VoiceOver labels, sufficient contrast, large-hit targets.
- Internationalization
  - English only Phase 1; USD formatting. Localizable strings infrastructure in place.

## 6. Architecture & Implementation

App architecture
- SwiftUI views + MVVM view models (Combine as the reactive layer; async/await allowed behind publishers).
- Modules (targets or groups):
  - `Auth`: WebAuthn orchestration, cookie/session handling, account state.
  - `API`: typed client, request builders, decoders, error mapping.
  - `Models`: Wallet, Position, PortfolioSummary, NotificationSettings, NotificationLog.
  - `Features`: Dashboard, Wallets, Positions (detail + snapshots), Notifications (settings + feed), Settings.
  - `Infra`: Networking, SSE client, caching, logging, DI (simple factory or environment container).

Networking
- `URLSession` with shared `HTTPCookieStorage` to maintain session.
- Combine-based API layer (`AnyPublisher<T, APIError>`), decoding with `JSONDecoder`.
- SSE client
  - `URLSessionDataTask` reading `text/event-stream`, line-delimited; parse `data:` frames.
  - Expose as Combine publisher of progress events for discovery and rescan.

State & Caching
- In-memory store for latest portfolio/positions; disk cache via `URLCache` or lightweight persistence (e.g., JSON file in app container) for fast cold start.
- Simple cache invalidation: time-based (e.g., 60s) unless user pulls to refresh.

UI Navigation
- Root authentication gate.
- `TabView` (Dashboard, Wallets, Positions, Settings). Notifications as a section under Settings in Phase 3 or its own tab when push lands.

Theming
- Light/Dark Mode with system adaptive colors. Monetary values use monospaced digits.

Logging & Telemetry
- Use `os.Logger` categories; no PII. Optional, privacy-preserving analytics gated behind a single toggle.

## 7. Data Contracts (high-level)

- Auth
  - `POST /api/auth/login/generate-options` => WebAuthn options JSON; session cookie set.
  - `POST /api/auth/login/verify` => `{ verified, user }` and authenticated cookie.
  - `GET /api/auth/me` => `{ id, username, displayName, isAdmin }`.
- Portfolio
  - `GET /api/portfolio/summary` => `{ asOf, totalValueUsd, estDailyUsd, estMonthlyUsd, estYearlyUsd, positions[] }`.
- Positions
  - `GET /api/positions` => `{ positions[], summary: { actual24hYield, actual7dYield, actual30dYield } }`.
  - `GET /api/positions/:id/snapshots` => `{ position, snapshots[] }`.
- Wallets
  - `GET /api/wallets` => `{ wallets[] }`; `POST /api/wallets/discover` (SSE); `POST /api/wallets/:id/scan` (SSE); `DELETE /api/wallets/:id`.
- Notifications
  - `GET/PUT /api/notifications/settings` => Notification settings record.
  - `GET /api/notifications/history` => `{ notifications[] }`.

Notes
- Positions with `measureMethod: "rewards"` omit APY fields; show absolute yield projections. The app must reflect this.

## 8. UX Flows (summary)

- Login
  - Enter username → Generate options → Native passkey prompt → Verify → Load dashboard.
- Dashboard
  - Aggregated value and projections; list of recent positions; CTA to Wallets/Positions.
- Wallets
  - List tracked wallets. Add wallet → address/ENS input → discovery progress (SSE) → success state.
  - Select wallet → detail view with positions and last updated; rescan button (SSE).
- Positions
  - List positions; filter by wallet; detail shows sparkline (snapshots) and metrics.
- Notifications (Phase 3)
  - Settings: toggles, thresholds, severity pickers, filtered symbols.
  - Feed: reverse-chronological list with severity badges.

## 8a. Flow Diagrams (lightweight)

Login (Passkey, existing users)

```
User → App: Enter username
App → API: POST /api/auth/login/generate-options { username }
API → App: WebAuthn options (challenge, allowCredentials, rpId)
App → iOS (ASAuthorization): Request assertion for rpId
iOS Sheet: Shows passkeys (iCloud, 1Password if enabled)
User → iOS: Select passkey, authenticate (Face ID / PIN)
iOS → App: Assertion (authenticatorData, clientDataJSON, signature, userHandle)
App: Wrap into AuthenticationResponseJSON (base64url encoded)
App → API: POST /api/auth/login/verify { assertion }
API: Verify, set session cookie
API → App: { verified, user }
App: Persist cookie; load dashboard data
```

Wallet Discovery (SSE)

```
User → App: Add wallet (address/ENS)
App → API: POST /api/wallets/discover (SSE)
API → App (SSE stream):
  data: { type: 'start', totalProtocols }
  data: { type: 'protocol_start', protocol, index }
  data: { type: 'position_found', protocol, displayName, valueUsd }
  ... (repeats)
  data: { type: 'protocol_complete', protocol, positionsFound }
  data: { type: 'complete', totalPositions }
App: Update progress UI in real time; on complete fetch /api/positions
```

## 9. Risks & Mitigations

- WebAuthn on native iOS
  - Use iOS 16+ native passkey APIs; ensure cookie persistence between generate/verify steps.
- SSE lifecycle
  - Backgrounding cancels streams; treat as foreground-only and persist interim state. For long discoveries, the server continues; the app reconnects to fetch results post-completion.
- Push complexity
  - Stage in-app feed first; add APNs later. Keep server contract minimal (register/unregister device).
- Rate limits / backend guards
  - Respect backend cooldowns (manual refresh). Use cache-first rendering, backoff on 429/403 with user feedback.

## 10. Testing & QA

- Unit tests: ViewModels (Combine publishers, state transitions, error mapping). Mock API client.
- Snapshot tests: key SwiftUI screens (light/dark, Dynamic Type).
- Integration tests: happy path auth → dashboard data load; SSE parsing for discovery.
- Manual QA: degraded network, offline cache behavior, cookie expiry, re-login UX.

## 11. Delivery Plan & Milestones

- Phase 1 (3–4 weeks)
  - Auth + session management
  - Portfolio/positions/wallets read-only
  - Basic caching and error handling
- Phase 2 (3 weeks)
  - Add wallet + SSE discovery and rescan
  - Wallet management
- Phase 3 (3–5 weeks)
  - Notification settings + feed
  - APNs device registration (server work), push notifications

Each phase ships as a TestFlight build with release notes; monitor crash reports and fix blockers before advancing.

## 12. Open Questions

- Will APNs be implemented in the backend or should the app rely on ntfy-only initially?
- Any requirement for iPad-optimized layouts in early phases?
- Should we add a read-only Guest mode on iOS (using `/api/guest/default-wallet`), or keep the app authenticated-only?
- Any PII/analytics policies that constrain telemetry beyond crash reports?
