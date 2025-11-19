# Mock API Setup Guide

This guide explains how to complete the Mock API setup in Xcode.

## Files Created

The following mock infrastructure files have been created:

### Mock Implementation
- `Yapt/Mocking/MockAPIClient.swift` - Mock API client that returns JSON data
- `Yapt/Mocking/MockConfiguration.swift` - Configuration for mock scenarios
- `Yapt/Mocking/MockDataLoader.swift` - Utility to load JSON files from bundle

### Mock Data Files
- `Yapt/Mocking/MockData/user.json` - Mock user response
- `Yapt/Mocking/MockData/portfolio-summary.json` - Portfolio with data
- `Yapt/Mocking/MockData/portfolio-summary-empty.json` - Empty portfolio
- `Yapt/Mocking/MockData/positions.json` - Positions with data
- `Yapt/Mocking/MockData/positions-empty.json` - Empty positions
- `Yapt/Mocking/MockData/wallets.json` - Wallets with data
- `Yapt/Mocking/MockData/wallets-empty.json` - Empty wallets
- `Yapt/Mocking/MockData/error-401.json` - Unauthorized error
- `Yapt/Mocking/MockData/error-500.json` - Server error

### Modified Files
- `Yapt/Features/Auth/AuthService.swift` - Added mock mode to bypass passkeys
- `Yapt/App/AppEnvironment.swift` - Uses MockAPIClient in mock mode

## Steps to Complete Setup in Xcode

### 1. Add Files to Xcode Project

1. Open `Yapt.xcodeproj` in Xcode
2. Right-click on the `Yapt` folder in the Project Navigator
3. Select "Add Files to 'Yapt'..."
4. Navigate to `Yapt/Mocking/` folder
5. Select the `Mocking` folder
6. **IMPORTANT**: Check "Create folder references" (not "Create groups")
7. Ensure "Add to targets: Yapt" is checked
8. Click "Add"

### 2. Configure MockData Folder

The JSON files in `MockData/` need to be included in the app bundle:

1. Select the Yapt project in Project Navigator
2. Select the "Yapt" target
3. Go to "Build Phases" tab
4. Expand "Copy Bundle Resources"
5. Click the "+" button
6. Select all files in `Mocking/MockData/` folder (all .json files)
7. Click "Add"

### 3. Create Debug-Mock Build Configuration

1. Select the Yapt project in Project Navigator
2. Select the project (not the target) - the blue icon at the top
3. Go to "Info" tab
4. Under "Configurations", click the "+" button at the bottom
5. Select "Duplicate 'Debug' Configuration"
6. Rename it to "Debug-Mock"

### 4. Add MOCK_API Compiler Flag

1. Select the Yapt project in Project Navigator
2. Select the "Yapt" target
3. Go to "Build Settings" tab
4. Search for "Swift Compiler - Custom Flags"
5. Find "Other Swift Flags"
6. Expand "Debug-Mock" (the configuration you just created)
7. Double-click on the value field
8. Click the "+" button
9. Add: `-D MOCK_API`
10. Press Enter

### 5. Create Yapt-Mock Scheme

1. In Xcode menu, go to Product → Scheme → Manage Schemes...
2. Click the "+" button at the bottom
3. Name: "Yapt-Mock"
4. Target: "Yapt"
5. Click "OK"
6. Select the new "Yapt-Mock" scheme from the list
7. Click "Edit..."
8. On the left, select "Run"
9. In the "Info" tab, change "Build Configuration" to "Debug-Mock"
10. On the left, select "Test" (if you have tests)
11. Change "Build Configuration" to "Debug-Mock"
12. Click "Close"
13. Click "Close" on the Manage Schemes dialog

### 6. Verify Setup

1. In Xcode, select the "Yapt-Mock" scheme from the scheme selector (top left, next to the Run button)
2. Build the project (⌘B)
3. Check the build log for: `[MOCK] Using MockAPIClient - all API calls will use mock data`
4. If you see this log, the setup is complete!

## Usage

### To Use Mock API:
1. Select "Yapt-Mock" scheme
2. Build and Run (⌘R)
3. Login with any username (passkey is bypassed)
4. All API calls will return mock JSON data

### To Use Real API:
1. Select "Yapt" scheme
2. Build and Run (⌘R)
3. Login requires real passkey authentication
4. All API calls go to https://yapt.fi

## Mock Scenarios

You can change mock behavior in `MockConfiguration.swift`:

```swift
// In MockConfiguration.swift, change the scenario:
static var scenario: MockScenario = .success  // Normal data
static var scenario: MockScenario = .empty    // Empty states
static var scenario: MockScenario = .unauthorized  // 401 error
static var scenario: MockScenario = .serverError   // 500 error
static var scenario: MockScenario = .networkTimeout // Timeout

// Add network delay (in seconds):
static var networkDelay: TimeInterval = 1.0  // Simulates slow network
```

## Troubleshooting

### "Failed to find user.json in bundle"
- Check that MockData folder is added as folder reference (blue folder icon)
- Verify JSON files are in "Copy Bundle Resources" build phase
- Clean build folder (⇧⌘K) and rebuild

### Mock mode not activating
- Verify "Debug-Mock" build configuration has `-D MOCK_API` flag
- Check you're using "Yapt-Mock" scheme
- Look for `[MOCK]` logs in console

### Compilation errors in MockAPIClient
- The mock files are wrapped in `#if MOCK_API` guards
- They won't compile in Release or Debug builds (only Debug-Mock)
- This is intentional to keep mock code out of production

## Files Not Included in Release

All mock code is wrapped in `#if MOCK_API` conditional compilation blocks. When building for Release or App Store:
- Mock files won't be compiled
- Mock code is completely excluded
- No runtime overhead
- No mock data in app bundle

This ensures production builds are clean and contain only production code.
