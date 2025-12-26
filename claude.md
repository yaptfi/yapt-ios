# Claude Code Instructions for Yapt iOS

## Project Overview

Yapt is a DeFi portfolio tracking iOS app built with SwiftUI. **Phases 1-3** are implemented:
- Passkey authentication (WebAuthn)
- Portfolio dashboard with positions and wallets
- Add wallet with SSE discovery progress (Phase 2)
- Wallet management: detail view, rescan, delete (Phase 2)
- Notification settings and history feed (Phase 3 - awaiting backend)
- Session management with cookie-based authentication

**Backend API**: https://yapt.fi/api
**User for testing**: `boffola`

## Key Architecture Principles

### 1. MVVM + Combine
- **Views**: SwiftUI components, no business logic
- **ViewModels**: State management using `@Published` properties, Combine publishers
- **Services**: API calls, data transformation, caching
- **Models**: Codable structs matching backend TypeScript types

### 2. Dependency Injection
All dependencies flow through `AppEnvironment`:
```swift
let env = AppEnvironment.shared
env.sessionManager       // Auth state
env.authService          // Login/logout
env.portfolioService     // Portfolio data
env.positionService      // Positions
env.walletService        // Wallets + SSE discovery
env.notificationService  // Notification settings & history
env.sseClient            // Server-sent events for discovery
```

### 3. Authentication Flow
1. User enters username → `POST /api/auth/login/generate-options`
2. iOS native passkey prompt via `ASAuthorizationController`
3. `WebAuthnCoordinator` converts iOS assertion → JSON
4. `POST /api/auth/login/verify` → backend sets `yapt.sid` cookie
5. Cookie persists in `HTTPCookieStorage.shared`
6. All subsequent API calls include cookie automatically

### 4. Critical Business Logic: Position Measurement

**APY-based positions** (`measureMethod != "rewards"`):
- Display: `apy`, `apy7d`, `apy30d` fields
- Show percentage-based yields

**Rewards-based positions** (`measureMethod == "rewards"`):
- **NEVER display APY fields** (they will be null/undefined)
- Display: `absoluteYield.avgDailyYield`, `projectedMonthlyYield`, `projectedYearlyYield`
- Show absolute USD amounts

See `PositionDetailRow.swift` for reference implementation.

## File Structure

```
Yapt/
├── App/
│   ├── YaptApp.swift          # Entry point
│   ├── AppEnvironment.swift   # DI container
│   ├── RootView.swift         # Auth gate
│   └── MainTabView.swift      # Tab navigation
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift    # URLSession wrapper
│   │   ├── APIEndpoint.swift  # Type-safe endpoints
│   │   ├── APIError.swift     # Error types
│   │   └── SSEClient.swift    # Server-sent events client
│   ├── Models/                # Codable types
│   ├── Extensions/
│   │   ├── Constants.swift    # API URLs, RP_ID
│   │   └── Formatters.swift   # Currency, dates
│   └── Logging/
│       └── Logger+Extensions.swift
├── Features/
│   ├── Auth/
│   │   ├── SessionManager.swift       # Auth state publisher
│   │   ├── AuthService.swift          # API calls
│   │   ├── WebAuthnCoordinator.swift  # Passkey orchestration
│   │   ├── LoginViewModel.swift
│   │   └── LoginView.swift
│   ├── Dashboard/
│   │   ├── PortfolioService.swift     # Portfolio API + cache
│   │   ├── DashboardViewModel.swift
│   │   └── DashboardView.swift
│   ├── Positions/
│   │   ├── PositionService.swift
│   │   ├── PositionsViewModel.swift
│   │   └── PositionsListView.swift
│   ├── Wallets/
│   │   ├── WalletService.swift        # Wallet API + SSE discovery
│   │   ├── WalletsViewModel.swift
│   │   ├── WalletsListView.swift
│   │   ├── AddWalletView.swift        # Add wallet flow (Phase 2)
│   │   ├── AddWalletViewModel.swift
│   │   ├── DiscoveryProgressView.swift # SSE progress UI
│   │   ├── WalletDetailView.swift     # Wallet detail + rescan
│   │   └── WalletDetailViewModel.swift
│   ├── Notifications/                  # Phase 3
│   │   ├── NotificationService.swift   # Settings & history API
│   │   ├── NotificationSettingsView.swift
│   │   ├── NotificationSettingsViewModel.swift
│   │   ├── NotificationFeedView.swift  # History feed
│   │   ├── NotificationFeedViewModel.swift
│   │   └── NotificationDetailView.swift
│   └── Settings/
│       ├── SettingsViewModel.swift
│       └── SettingsView.swift
└── Resources/
    └── Assets.xcassets/
```

## Development Guidelines

### Adding New API Endpoints

1. **Define endpoint** in `APIEndpoint.swift`:
```swift
case myNewEndpoint
// ...
case .myNewEndpoint:
    return (path: "/api/my-endpoint", method: .get)
```

2. **Create service method**:
```swift
func fetchData() -> AnyPublisher<MyModel, APIError> {
    apiClient.request(endpoint: .myNewEndpoint)
}
```

3. **Use in ViewModel**:
```swift
service.fetchData()
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { [weak self] completion in
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        },
        receiveValue: { [weak self] data in
            self?.data = data
        }
    )
    .store(in: &cancellables)
```

### Adding New Views

1. Create ViewModel first with `@Published` state
2. Create View with `@StateObject var viewModel`
3. Add to navigation in `MainTabView.swift` or detail navigation
4. Follow existing patterns for loading/error states
5. Use reusable components from existing views

### Working with Passkeys

**Required configuration**:
- `Yapt.entitlements`: Associated Domains capability
- Domain: `webcredentials:yapt.fi`
- Backend AASA file at `https://yapt.fi/.well-known/apple-app-site-association`

**Testing**:
- Requires **physical device** (iOS 16+)
- Simulator has limited passkey support
- Ensure passkey exists for `boffola@yapt.fi` on `yapt.fi` domain

### Caching Strategy

Current TTLs (defined in `Constants.swift`):
- Portfolio: 60s
- Positions: 60s
- Wallets: 300s

Services implement:
```swift
if let cached = cache.value, cached.isValid {
    return Just(cached.data).setFailureType(to: APIError.self).eraseToAnyPublisher()
}
// Fetch from network
```

Pull-to-refresh bypasses cache.

### Error Handling

Always handle errors gracefully:
```swift
.sink(
    receiveCompletion: { [weak self] completion in
        self?.isLoading = false
        if case .failure(let error) = completion {
            switch error {
            case .unauthorized:
                // Trigger logout
            case .networkError:
                self?.errorMessage = "Check your connection"
            default:
                self?.errorMessage = error.localizedDescription
            }
        }
    },
    receiveValue: { ... }
)
```

### Logging

Use categorized loggers:
```swift
private let logger = Logger.network  // or .auth, .ui, .cache
logger.info("Fetching data from \(endpoint)")
logger.error("Failed: \(error)")
```

**Never log**:
- Cookies
- Authentication tokens
- User passwords
- Raw passkey assertions
- PII (email, full addresses)

## Common Tasks

### Run the App
1. Open `Yapt.xcodeproj` in Xcode
2. Select a physical iOS device (iOS 16+)
3. Build and run (⌘R)
4. Test login with username: `boffola`

### Test Authentication Flow
1. Clear cookies: Settings → Logout
2. Enter username `boffola`
3. Tap "Sign in with Passkey"
4. Select passkey from sheet
5. Authenticate with Face ID/Touch ID
6. Should navigate to dashboard

### Add New Model Property
1. Add property to model struct (must match backend JSON)
2. Codable will handle automatically if names match
3. Use `CodingKeys` enum if JSON key differs:
```swift
enum CodingKeys: String, CodingKey {
    case myProperty = "my_property"
}
```

### Debug Network Calls
1. Check `Logger.network` output in console
2. Verify endpoint in `APIEndpoint.swift`
3. Test with curl:
```bash
curl -X GET https://yapt.fi/api/portfolio/summary \
  -H "Cookie: yapt.sid=YOUR_SESSION_COOKIE"
```

### Handle 401 Unauthorized
`APIClient` automatically triggers logout on 401:
```swift
if response.statusCode == 401 {
    sessionManager.logout()
    // User redirected to login
}
```

## Implementation Status

### Phase 1 (Auth + Dashboard) — ✅ Complete
- ✅ Passkey authentication
- ✅ Session persistence
- ✅ Portfolio dashboard
- ✅ Positions list (APY vs. rewards-based logic)
- ✅ Wallets list
- ✅ Settings & logout
- ✅ Pull-to-refresh
- ✅ Error handling
- ✅ Caching

### Phase 2 (Add Wallet & Discovery) — ✅ Complete
- ✅ Add wallet flow (address/ENS input)
- ✅ SSE discovery progress (real-time protocol scanning)
- ✅ Wallet detail view with positions
- ✅ Rescan wallet (SSE)
- ✅ Remove wallet (swipe-to-delete)

### Phase 3 (Notifications) — ✅ iOS Complete, ⏳ Backend Pending
- ✅ Notification settings UI (depeg/APY alerts, thresholds, severity)
- ✅ Notification history feed with pagination
- ✅ Notification detail view
- ⏳ Awaiting backend: `GET/PUT /api/notifications/settings`, `GET /api/notifications/history`
- See `yapt-backend-notifications.md` for backend API spec

### Out of Scope (Phase 3b+)
- ❌ APNs push notifications (planned)
- ❌ User registration

## Testing Checklist

Before committing changes:

1. **Authentication**
   - [ ] Login works with passkey
   - [ ] Session persists after app restart
   - [ ] Logout clears cookies
   - [ ] 401 triggers re-login

2. **Data Display**
   - [ ] Portfolio values match backend
   - [ ] APY positions show APY fields
   - [ ] Rewards positions show absolute yield (NO APY)
   - [ ] Wallets show ENS names

3. **Error Handling**
   - [ ] Network errors show retry
   - [ ] Offline mode shows cached data
   - [ ] Empty states handled

4. **Accessibility**
   - [ ] VoiceOver labels present
   - [ ] Dynamic Type works
   - [ ] Color contrast sufficient

## Troubleshooting

### "No passkeys available"
- Ensure testing on **physical device** (not Simulator)
- Verify Associated Domains configured
- Check AASA file is reachable
- Confirm passkey exists for username on yapt.fi

### "Session expired" on launch
- Cookies may have expired (backend sets TTL)
- User will be redirected to login automatically

### Data not updating
- Check cache TTLs in `Constants.swift`
- Use pull-to-refresh to force update
- Verify backend API is returning data

### Build errors
- Clean build folder (⇧⌘K)
- Delete DerivedData
- Ensure all files added to Yapt target

## Code Style

- Use Swift naming conventions (camelCase, PascalCase for types)
- No force unwraps (`!`) - use `guard let` or optional chaining
- Keep ViewModels testable (no UIKit dependencies)
- Extract magic numbers to `Constants.swift`
- Add comments for non-obvious business logic

## Resources

- **PRD**: `yapt-ios-prd.md` - Full requirements
- **Implementation Summary**: `IMPLEMENTATION_SUMMARY.md` - What's built
- **Backend API**: Check yapt.fi backend for endpoint contracts
- **Apple Docs**: [ASAuthorization](https://developer.apple.com/documentation/authenticationservices/asauthorization)

## Questions to Ask Before Making Changes

1. Does this change affect the APY vs. rewards-based position logic?
2. Do I need to update the backend contract?
3. Should this be cached? What's the TTL?
4. Does this need to work offline?
5. Does the backend endpoint exist? (See `yapt-backend-notifications.md` for pending endpoints)

## When in Doubt

- Check existing similar code first
- Follow MVVM pattern strictly
- Prefer Combine publishers over callbacks
- Keep Views dumb, ViewModels smart
- Log errors, don't crash
