# Repository Guidelines

## Project Structure & Module Organization
- `Yapt/App` hosts the SwiftUI entry point (`YaptApp`, `RootView`) and the dependency container (`AppEnvironment`).
- `Yapt/Core` keeps shared services, networking, and models; `Yapt/Features/<Feature>` owns SwiftUI views, view models, and APIs for that slice—add new files there instead of `App`.
- `Yapt/Resources` bundles assets, localized strings, and entitlements, while `Yapt/Mocking` stores mock clients plus JSON fixtures.
- Tests live in `YaptTests` (unit/specs using the `Testing` framework) and `YaptUITests` (XCTest-driven UI flows).

## Build, Test, and Development Commands
- `xcodebuild -scheme Yapt -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build` — Debug build that talks to the live backend.
- `xcodebuild test -scheme Yapt -destination 'platform=iOS Simulator,name=iPhone 15 Pro'` — runs unit coverage; append `-only-testing:YaptUITests` for UI-only passes.
- `xcodebuild -scheme Yapt-Mock -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build` — uses the Debug-Mock configuration with the `-D MOCK_API` flag for offline development.

## Coding Style & Naming Conventions
- Swift 5.9 with SwiftUI-first patterns: prefer structs, value semantics, and inject dependencies through `@EnvironmentObject` or dedicated initializers.
- Four-space indentation, `UpperCamelCase` types, `lowerCamelCase` members, and `snake_case` only when matching backend payloads; separate concerns with `// MARK:` comments.
- Use shared modifiers/components from `Core`, declare previews alongside the view, and mirror filenames to the primary type (e.g., `PortfolioSummaryView.swift`).

## Testing Guidelines
- Author `@Test` cases in `YaptTests` using the `Testing` framework; name each test for the behavior under scrutiny (e.g., `@Test func portfolioLoadsWithMockData()`).
- UI automation belongs in `YaptUITests`; rely on accessibility identifiers instead of view order.
- Run `xcodebuild test` before every PR, add fixtures under `Yapt/Mocking/MockData` when mocking new responses, and confirm the Debug-Mock scheme still compiles.

## Commit & Pull Request Guidelines
- Match the existing history style: concise imperative summaries with optional scopes (`Implement notification settings`, `Refactor: PositionDisplayable protocol`) and reference issues with `#123` when applicable.
- PRs should outline motivation, testing (note whether mock mode or UI tests were run), and include screenshots for visual changes; keep commits narrow to aid review.

## Mock API & Environment Tips
- Follow `MOCK_API_SETUP.md` to add the `Mocking` folder, enable Debug-Mock, and surface the `Yapt-Mock` scheme for local testing without the backend.
- Tweak `MockConfiguration.scenario` and `networkDelay` to demo empty states, auth failures, or latency; avoid calling mock-only symbols from production code so Release builds stay clean.
