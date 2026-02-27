# Yapt iOS — Agent Guidelines

## What This Is

Yapt is a **DeFi portfolio tracking iOS app** (SwiftUI, iOS 16+). Users authenticate with passkeys, then monitor their yield-bearing positions across multiple wallets. The app tracks APY-based and rewards-based positions and alerts on position changes.

**Backend**: `https://yapt.fi/api` | **Test user**: `boffola`

## Engineering principles
Produce code that is correct, secure, clear, maintainable, and efficient. Follow existing project conventions unless clearly harmful. Prefer simple, explicit solutions over clever ones. Use strong typing wherever possible. Keep concerns separated and side effects at the boundaries. Remove real duplication, but do not over-abstract. Write code that is easy for other humans and agents to understand and extend. Validate all external input, use safe APIs, avoid hardcoded secrets, and do not log sensitive data. Handle errors explicitly and with useful context. Avoid obvious code smells. Keep changes focused and minimal. Add or update unit and integration tests where appropriate, including edge cases and regressions. Do not consider work complete unless the code builds, passes checks, and the changed behavior is adequately tested and documented.

## Architecture

**MVVM + Combine** — strictly enforced.

- **Views**: SwiftUI only, zero business logic. Use `@StateObject` for owned ViewModels.
- **ViewModels**: `@Published` state, Combine pipelines, `@MainActor`. No UIKit.
- **Services**: All API calls, caching, and data transformation. Return `AnyPublisher`.
- **Models**: `Codable` structs matching the backend TypeScript types exactly.

**Dependency injection** flows entirely through `AppEnvironment` (passed as `@EnvironmentObject`):

```swift
env.sessionManager          // Auth state publisher
env.authService             // Login/logout
env.portfolioService        // Portfolio summary + cache
env.positionService         // Positions + change detection
env.walletService           // Wallets + SSE discovery
env.notificationService     // Notification settings & history (backend pending)
env.pushNotificationService // APNs registration
env.positionChangeSettings  // UserDefaults-backed position alert settings
env.sseClient               // SSE stream for wallet discovery
env.portfolioValueCache     // Cross-session portfolio value delta tracking
```

Never instantiate services directly in views. Always pass from `AppEnvironment`.

---

## File Structure

```
Yapt/
├── App/
│   ├── YaptApp.swift           # Entry point
│   ├── AppEnvironment.swift    # DI container — add all new services here
│   ├── RootView.swift          # Auth gate (login vs. main tab)
│   └── MainTabView.swift       # Tab navigation
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift     # URLSession wrapper; handles 401 → auto-logout
│   │   ├── APIEndpoint.swift   # Type-safe endpoint definitions
│   │   ├── APIError.swift      # Error enum
│   │   └── SSEClient.swift     # Server-sent events
│   ├── Models/                 # Codable types (Position, Wallet, etc.)
│   └── Extensions/
│       ├── Constants.swift     # TTLs, API base URL, RP_ID
│       └── Formatters.swift    # Currency, date, percentage formatters
├── Features/
│   ├── Auth/                   # Passkey login (SessionManager, WebAuthnCoordinator)
│   ├── Dashboard/              # Portfolio summary + animated delta
│   ├── Positions/              # Position list, change detection, banner
│   ├── Wallets/                # Wallet list, add wallet, SSE discovery, detail
│   ├── Notifications/          # Settings, history feed, detail view
│   └── Settings/               # App settings, logout
└── Mocking/                    # MockAPIClient + JSON fixtures (see MOCK_API_SETUP.md)
```

---

## Critical Business Logic

### Position Measurement (do not get this wrong)

Positions have two mutually exclusive display modes based on `measureMethod`:

| `measureMethod` | Show | Never show |
|---|---|---|
| anything except `"rewards"` | `apy`, `apy7d`, `apy30d`, `estDailyUsd`, `estMonthlyUsd`, `estYearlyUsd` | — |
| `"rewards"` | `absoluteYield.avgDailyYield`, `projectedMonthlyYield`, `projectedYearlyYield` | APY fields (will be null) |

Use `position.isRewardBased` (computed via `PositionDisplayable` protocol). Reference: `PositionDetailRow` in `PositionsListView.swift`.

### Authentication

1. `POST /api/auth/login/generate-options` → challenge
2. `ASAuthorizationController` native passkey sheet
3. `WebAuthnCoordinator` converts assertion → JSON
4. `POST /api/auth/login/verify` → backend sets `yapt.sid` cookie
5. Cookie persists in `HTTPCookieStorage.shared`; all requests send it automatically
6. `APIClient` auto-triggers `sessionManager.logout()` on any 401

**Passkey testing requires a physical device** (iOS 16+). Simulator support is limited.

### Caching

TTLs in `Constants.swift`: Portfolio 60s, Positions 60s, Wallets 300s.
Pull-to-refresh always bypasses cache (`forceRefresh: true`).
`clearCache()` is called on every service when the user logs out (`AppEnvironment.clearSessionScopedState`).

### Position Change Detection (client-side)

`PositionService` compares fresh network responses against `previousPositions`. On the first load it sets a baseline (no alerts). Subsequent fresh fetches emit `[PositionChangeAlert]` via `positionChanges: PassthroughSubject`. `previousPositions` is cleared in `clearCache()` so there are no stale comparisons after re-login. Threshold and enabled state live in `PositionChangeSettings` (UserDefaults, persists across sessions).

---

## Recipes

### Add a new API endpoint

```swift
// 1. APIEndpoint.swift — add the endpoint
let endpoint = APIEndpoint(path: "/api/my-resource", method: .get)

// 2. Service — return a publisher
func fetchData() -> AnyPublisher<MyModel, APIError> {
    apiClient.request(endpoint)
}

// 3. ViewModel — subscribe
service.fetchData()
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        },
        receiveValue: { [weak self] data in self?.data = data }
    )
    .store(in: &cancellables)
```

### Add a new screen

1. Create `FeatureViewModel.swift` with `@MainActor`, `@Published` state
2. Create `FeatureView.swift` with `@StateObject private var viewModel`
3. Add to `MainTabView` or as a `NavigationLink` destination
4. Wire new service through `AppEnvironment`

### Add a model property

Match the backend JSON key exactly → `Codable` handles it automatically. Use `CodingKeys` only when names differ.

---

## Build & Test Commands

```bash
# Standard debug build (live backend)
xcodebuild -scheme Yapt -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run unit tests
xcodebuild test -scheme Yapt -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# UI tests only
xcodebuild test -scheme Yapt -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:YaptUITests

# Offline / mock build (no backend needed)
xcodebuild -scheme Yapt-Mock -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

---

## Mock API

Use the `Yapt-Mock` scheme (`-D MOCK_API` flag) for offline development. See `MOCK_API_SETUP.md` for full setup.

- Add fixtures under `Yapt/Mocking/MockData/`
- Tweak `MockConfiguration.scenario` and `networkDelay` to demo edge cases (empty state, auth failure, latency)
- Never call mock-only symbols from production code — `Release` builds must stay clean

---

## Code Conventions

- Swift 5.9, SwiftUI-first, value semantics preferred
- `UpperCamelCase` types, `lowerCamelCase` members, `snake_case` only for backend payload keys
- No force unwraps (`!`) — use `guard let` or optional chaining
- Four-space indentation; separate sections with `// MARK:`
- Filename mirrors the primary type (`WalletDetailView.swift`)
- Magic numbers → `Constants.swift`
- Comments only for non-obvious logic

### Logging

```swift
private let logger = Logger.network  // .auth | .ui | .cache
logger.info("Fetching \(endpoint)")
logger.error("Failed: \(error)")
```

**Never log**: cookies, auth tokens, passkey assertions, passwords, or PII.

---

## Testing

- Unit tests use Swift `Testing` framework (`@Test func ...`) in `YaptTests`
- Name tests for the behavior: `@Test func positionChangeDetectsFullExit()`
- UI tests in `YaptUITests`; use accessibility identifiers, not view order
- Run `xcodebuild test` before every PR
- Add mock fixtures when mocking new API responses
- Confirm `Yapt-Mock` scheme still compiles after any changes

---

## Current State

Everything listed below is **fully implemented**:

- Passkey auth, session persistence, 401 auto-logout
- Portfolio dashboard with animated value delta
- Positions list with APY vs. rewards display logic
- Client-side position change detection + in-app banner alerts
- Add wallet (address/ENS), SSE discovery progress
- Wallet detail, rescan, swipe-to-delete
- Notification settings UI (depeg alerts, low-APY alerts, position change alerts)
- Push notification registration (APNs device token → backend)
- Notification history feed with pagination + detail view

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "No passkeys available" | Physical device only; verify Associated Domains + AASA file |
| Session expired on launch | Expected — cookie TTL; app auto-redirects to login |
| Data not updating | Pull-to-refresh; check TTLs in `Constants.swift` |
| Build errors after adding files | Project uses `PBXFileSystemSynchronizedRootGroup` — files on disk are auto-included, no pbxproj edit needed |
| SourceKit false errors after multi-file edits | Transient index lag; clean build (⇧⌘K) resolves |
| Position alerts firing on first load | They shouldn't — `previousPositions == nil` guard skips first fetch |
