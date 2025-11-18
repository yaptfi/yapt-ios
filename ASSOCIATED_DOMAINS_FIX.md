# Associated Domains Validation Fix

## Error You're Seeing

```
Error: Unable to verify webcredentials association of 9626BEV4Z4.com.yapt.Yapt with domain yapt.fi
Error code: 1004
```

## What This Means

iOS is unable to verify that your app (`9626BEV4Z4.com.yapt.Yapt`) is legitimately associated with the domain `yapt.fi`. This prevents passkeys from working.

## Why It Happens

When you install an app with Associated Domains:
1. iOS contacts the domain to download the AASA file
2. iOS caches this validation
3. Sometimes the first validation fails or takes time
4. iOS will retry in the background

The error message says: **"Please try again in a few seconds"** - this is iOS telling you it will retry.

## Solutions (Try in Order)

### Solution 1: Wait and Retry (RECOMMENDED)

The error message explicitly says to "try again in a few seconds". This is because:
- iOS validates Associated Domains asynchronously
- The validation is cached for performance
- Initial validation might fail but subsequent attempts succeed

**Steps:**
1. Wait **2-5 minutes** (not seconds, despite what the error says)
2. Try tapping "Sign in with Passkey" again
3. Check Xcode Console logs again

If you still see error 1004 after waiting, proceed to Solution 2.

### Solution 2: Force Re-validation

1. **Delete the app** from your iPhone
   - Long press the app icon
   - Tap "Remove App" → "Delete App"

2. **Clear iOS cache** (optional but recommended):
   - Settings → General → iPhone Storage
   - Wait for the list to load
   - Find and delete any remaining Yapt data

3. **Reinstall from Xcode**:
   - In Xcode, clean build folder (⇧⌘K)
   - Build and run (⌘R)
   - iOS will re-download and validate the AASA file

4. **Wait 2-5 minutes** after installation before trying to log in

5. **Try logging in** and check logs again

### Solution 3: Verify AASA File from Device

Sometimes corporate or home networks block the AASA file. Test from your iPhone:

1. Open **Safari on your iPhone** (not Mac)
2. Navigate to: `https://yapt.fi/.well-known/apple-app-site-association`
3. You should see:
   ```json
   {
     "webcredentials": {
       "apps": [
         "9626BEV4Z4.com.yapt.Yapt"
       ]
     }
   }
   ```

**If the file doesn't load:**
- Your network might be blocking it
- Try on cellular data instead of WiFi
- Try on a different network
- Check if VPN is interfering

### Solution 4: Verify Entitlements Are Signed

1. **Check code signing** in Xcode:
   - Select the Yapt project
   - Select the Yapt target
   - Go to "Signing & Capabilities"
   - Ensure "Automatically manage signing" is checked
   - Verify your Team is selected
   - Under "Associated Domains", verify `webcredentials:yapt.fi` is listed

2. **Rebuild with clean**:
   ```
   Product → Clean Build Folder (⇧⌘K)
   Product → Build (⌘B)
   Product → Run (⌘R)
   ```

### Solution 5: Check Device Settings

1. **Verify date and time are correct**:
   - Settings → General → Date & Time
   - Enable "Set Automatically"
   - Incorrect time can cause SSL verification failures

2. **Verify network connectivity**:
   - Make sure iPhone can access yapt.fi
   - Try opening https://yapt.fi in Safari

## Understanding the Logs

Your logs show:

```
allowCredentials count: 1
  Credential 0: type=public-key, id=OKo-t40-XMimyJHFROQS..., transports=["internal", "hybrid"]
```

This means:
- ✅ The backend responded successfully
- ✅ There IS a passkey registered for your username
- ✅ The credential ID is being sent
- ❌ iOS can't verify the app-domain association, so it won't show the passkey sheet

## What Should Happen After Fix

Once Associated Domains validation succeeds:

1. Logs will show the same debug output
2. **Instead of error 1004**, you'll see the iOS passkey sheet appear
3. The sheet will show:
   - "Sign in to yapt.fi"
   - Your available passkeys (from iCloud Keychain or 1Password)
   - Option to use Face ID / Touch ID

## Testing the Fix

After trying a solution:

1. Tap "Sign in with Passkey"
2. Check Xcode Console

**Success looks like:**
```
Calling ASAuthorizationController.performRequests() - passkey sheet should appear now
(Passkey sheet appears on screen)
```

**Failure still looks like:**
```
ASAuthorizationController credential request failed with error: Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004
Unable to verify webcredentials association...
```

## Advanced: Verify AASA with Apple's CDN

Apple caches AASA files on their CDN. Check if Apple has the file:

```bash
# Check if Apple's CDN has your AASA file
curl -v https://app-site-association.cdn-apple.com/a/v1/yapt.fi 2>&1 | grep -A 20 "webcredentials"
```

If this returns your AASA content, Apple has cached it and iOS should be able to validate.

## Timeline Expectations

- **First install**: 2-5 minutes for initial validation
- **After app update**: Usually instant (cached)
- **After delete/reinstall**: 2-5 minutes again
- **Network issues**: Can fail permanently until network is fixed

## Still Not Working?

If you've tried all solutions and still get error 1004:

1. **Check the AASA file format**:
   - Must be valid JSON
   - Must be served with `Content-Type: application/json`
   - Must be accessible via HTTPS
   - Must not redirect

2. **Verify the AASA file with curl**:
   ```bash
   curl -i https://yapt.fi/.well-known/apple-app-site-association
   ```

   Should return:
   ```
   HTTP/1.1 200 OK
   Content-Type: application/json

   {"webcredentials":{"apps":["9626BEV4Z4.com.yapt.Yapt"]}}
   ```

3. **Check for typos**:
   - Bundle ID must be EXACT: `com.yapt.Yapt`
   - Team ID must be EXACT: `9626BEV4Z4`
   - Domain must be EXACT: `yapt.fi` (no www, no protocol)

4. **Contact Apple Developer Support** if it still fails after 24 hours

## Quick Fix Summary

**Most likely to work:**

1. Wait 2-5 minutes, try again
2. If that fails: Delete app, reinstall, wait 2-5 minutes, try again
3. Verify AASA is accessible from iPhone Safari
4. Check you're on a network that allows HTTPS to yapt.fi

The error message itself says "try again in a few seconds" - iOS is telling you it needs time to validate!
