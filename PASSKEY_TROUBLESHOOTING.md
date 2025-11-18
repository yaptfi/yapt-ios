# Passkey Authentication Troubleshooting Guide

## Issue: 1Password Passkey Not Appearing

If you tap "Sign in with Passkey" but don't see your 1Password passkey, follow these steps:

### 1. Verify iOS Passkey Provider Setup

1. Open **iOS Settings**
2. Go to **Passwords**
3. Tap **Password Options**
4. Under "AutoFill Passwords and Passkeys", ensure **1Password** is enabled
5. Make sure **iCloud Keychain** is also enabled (for system integration)

### 2. Verify Passkey Exists in 1Password

**Important**: You need a **passkey** (WebAuthn credential), not just a password.

1. Open the **1Password app**
2. Find the **yapt.fi** entry
3. Look for a **Passkey** field (not just "Password")
4. If you only see a password field, you need to create a passkey:
   - Go to https://yapt.fi in Safari
   - Log in (if not already logged in)
   - Go to Settings → Security
   - Click "Add Passkey" or "Register New Device"
   - When prompted, choose **1Password** as the passkey provider
   - Enter your username: `boffola`

### 3. Verify Associated Domains Configuration

The app must be properly linked to `yapt.fi`:

1. **Check App Entitlements:**
   - File: `Yapt/Yapt.entitlements`
   - Should contain: `webcredentials:yapt.fi`

2. **Verify AASA File:**
   - Visit: https://yapt.fi/.well-known/apple-app-site-association
   - Should contain: `9626BEV4Z4.com.yapt.Yapt`
   - If this file is missing or incorrect, passkeys won't work

3. **iOS Verification:**
   - iOS validates Associated Domains when the app is first installed
   - If you recently changed the AASA file, try:
     - Delete the app from your device
     - Reinstall it from Xcode
     - Wait a few minutes for iOS to re-validate

### 4. Check Backend Configuration

The backend must be configured correctly:

1. **Environment Variables:**
   ```env
   RP_ID=yapt.fi
   ORIGIN=https://yapt.fi
   ```

2. **No `localhost` for Device Testing:**
   - The app uses `yapt.fi` as RP_ID
   - Testing on a physical device requires a real domain
   - Localhost won't work for passkeys on iOS

### 5. Understanding `allowCredentials`

When you tap "Sign in with Passkey", check the Xcode Console logs:

```
=== WebAuthn Authentication Debug ===
RP ID: yapt.fi
...
allowCredentials: ...
```

**If `allowCredentials` is NOT nil:**
- The backend is filtering which passkeys can be used
- Only passkeys with matching credential IDs will appear
- Your 1Password passkey must have been registered with this specific backend instance

**If `allowCredentials` is nil:**
- Any passkey for `yapt.fi` should work
- If your passkey still doesn't appear, the issue is with iOS configuration

### 6. Debug Logs to Check

Run the app from Xcode and check the Console for these logs:

**When tapping "Sign in with Passkey":**
```
Starting passkey authentication for RP: yapt.fi
=== WebAuthn Authentication Debug ===
RP ID: yapt.fi
Challenge length: 32 bytes
allowCredentials: ...
Calling ASAuthorizationController.performRequests() - passkey sheet should appear now
```

**If passkey fails:**
```
=== Passkey Authentication Error ===
Error: ...
ASAuthorizationError code: ...
Possible reasons: ...
```

Common error codes:
- **Code 1001** (canceled): User tapped "Cancel" on the passkey sheet
- **Code 1004** (failed): No passkeys available, or provider not configured
- **Code 1003** (notHandled): System couldn't handle the passkey request

### 7. Testing Checklist

- [ ] 1Password is enabled in iOS Settings > Passwords > Password Options
- [ ] A passkey (not password) exists for `yapt.fi` in 1Password
- [ ] The passkey username matches what you entered in the app
- [ ] App entitlements contain `webcredentials:yapt.fi`
- [ ] AASA file is accessible at https://yapt.fi/.well-known/apple-app-site-association
- [ ] AASA file contains correct bundle ID: `9626BEV4Z4.com.yapt.Yapt`
- [ ] App has been installed and launched at least once (for iOS to validate domains)
- [ ] Testing on a physical iOS device (iOS 16+), not Simulator

### 8. Alternative: Create New Passkey in App

If you want to register a new passkey directly from the iOS app:

**Note**: Phase 1 doesn't include registration UI. You'll need to:
1. Register on the web first (https://yapt.fi)
2. Or wait for Phase 2 which will include registration flow

### 9. Still Not Working?

**Collect debug information:**

1. Run the app from Xcode
2. Tap "Sign in with Passkey"
3. Copy all logs from Xcode Console
4. Check what `allowCredentials` shows
5. Check the error code if it fails

**Common fixes:**
- Restart the iPhone
- Re-install the app
- Re-enable 1Password in iOS Settings
- Verify the passkey exists in 1Password for the correct domain (`yapt.fi`, not `app.yapt.fi` or similar)

### 10. Understanding How It Works

When you tap "Sign in with Passkey":

1. **App → Backend**: `POST /api/auth/login/generate-options` with `{ username: "boffola" }`
2. **Backend → App**: Returns WebAuthn options including challenge and optional `allowCredentials`
3. **App → iOS**: Calls `ASAuthorizationController.performRequests()`
4. **iOS**: Shows passkey sheet with all available passkeys for `yapt.fi`
   - Searches iCloud Keychain
   - Searches 1Password (if enabled)
   - Filters by `allowCredentials` if provided
5. **User**: Selects passkey and authenticates (Face ID/Touch ID)
6. **iOS → App**: Returns signed assertion
7. **App → Backend**: `POST /api/auth/login/verify` with assertion
8. **Backend**: Verifies signature and sets session cookie
9. **Success**: User is logged in

The system should **automatically** show 1Password passkeys if they exist and iOS is configured correctly.

## Quick Reference: iOS Settings Path

```
Settings
  └─ Passwords
      └─ Password Options
          └─ AutoFill Passwords and Passkeys
              ├─ ☑ iCloud Keychain
              └─ ☑ 1Password
```

## Backend Verification

To verify the backend is sending correct options:

```bash
curl -X POST https://yapt.fi/api/auth/login/generate-options \
  -H "Content-Type: application/json" \
  -d '{"username":"boffola"}' \
  --cookie-jar cookies.txt

# Check the response for:
# - rpId: "yapt.fi"
# - challenge: (base64url encoded string)
# - allowCredentials: (array of credential IDs, or absent)
```

If `allowCredentials` is present and non-empty, those are the only credential IDs that will be accepted. Your 1Password passkey must match one of them.
