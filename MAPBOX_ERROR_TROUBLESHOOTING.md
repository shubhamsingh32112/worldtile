# Mapbox Map Loading Error - Troubleshooting Guide

## Error Message
```
Map configuration error, failed to initialize map: instance of "MapLoadingErrorEventData"
```

## Common Causes & Solutions

### 1. **Network Connectivity Issues in Emulator** ⚠️ MOST COMMON

**Problem**: Android emulators sometimes have network connectivity issues that prevent Mapbox from loading map tiles.

**Solutions**:
- **Check Emulator Internet**: Open browser in emulator and try to load a website
- **Restart Emulator**: Close and restart the Android emulator
- **Check Host Machine Internet**: Ensure your computer has internet connection
- **Use Physical Device**: If possible, test on a physical device instead
- **Cold Boot Emulator**: In Android Studio → AVD Manager → Cold Boot Now

### 2. **Mapbox Token Not Properly Configured**

**Problem**: The Mapbox access token might not be set correctly in all required locations.

**Required Locations**:
1. ✅ `assets/.env` - For Flutter code
2. ✅ `android/gradle.properties` - For native Android build
3. ✅ `android/app/src/main/AndroidManifest.xml` - For native Android runtime

**Verification Steps**:

1. **Check `.env` file**:
   ```bash
   # Location: frontend_app/assets/.env
   MAPBOX_PUBLIC_TOKEN=pk.your_token_here
   ```
   - Token must start with `pk.` (public token)
   - No quotes around the token
   - No spaces before/after the token

2. **Check `gradle.properties`**:
   ```bash
   # Location: frontend_app/android/gradle.properties
   MAPBOX_ACCESS_TOKEN=pk.your_token_here
   ```
   - Must match the token in `.env`
   - No quotes or spaces

3. **Verify AndroidManifest.xml**:
   ```xml
   <!-- Location: android/app/src/main/AndroidManifest.xml -->
   <meta-data
       android:name="MAPBOX_ACCESS_TOKEN"
       android:value="${MAPBOX_ACCESS_TOKEN}" />
   ```
   - Should reference the gradle property

4. **Verify main.dart**:
   ```dart
   // Location: lib/main.dart
   final mapboxToken = dotenv.env["MAPBOX_PUBLIC_TOKEN"];
   if (mapboxToken != null && mapboxToken.isNotEmpty) {
     MapboxOptions.setAccessToken(mapboxToken);
   }
   ```

### 3. **Token Invalid or Expired**

**Problem**: The Mapbox token might be invalid, expired, or have insufficient permissions.

**Solutions**:
- **Get New Token**: 
  1. Go to https://account.mapbox.com/access-tokens/
  2. Create a new public token (starts with `pk.`)
  3. Ensure it has "Downloads:Read" and "Styles:Read" scopes
  4. Update all configuration files with the new token

- **Verify Token**:
  - Token must be a **public token** (starts with `pk.`)
  - Do NOT use secret tokens (start with `sk.`)
  - Token should be at least 100 characters long

### 4. **Missing Internet Permission**

**Problem**: Android app might not have INTERNET permission.

**Solution**: Verify `AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 5. **Build Configuration Issues**

**Problem**: The app might not have been rebuilt after configuration changes.

**Solution**: Clean and rebuild:
```bash
cd frontend_app
flutter clean
flutter pub get
flutter run
```

### 6. **Emulator-Specific Issues**

**Problem**: Some Android emulator configurations can cause network issues.

**Solutions**:
- **Use Different Emulator**: Try a different AVD (Android Virtual Device)
- **Check Emulator Settings**: 
  - Settings → Network → Ensure "Cellular" is enabled
  - Settings → Network → Check proxy settings
- **Use x86_64 Emulator**: Some ARM emulators have network issues
- **Increase Emulator RAM**: Low RAM can cause network timeouts

## Debugging Steps

### Step 1: Check Console Logs

When the error occurs, check the Flutter console for:
```
🔍 Debug info:
  - Token exists: true/false
  - Token starts with pk.: true/false
  - Token length: XXX
❌ Map creation error (full): ...
❌ Map creation error (type): ...
```

### Step 2: Verify Token Configuration

Run this in your terminal:
```bash
# Check .env file
cat frontend_app/assets/.env | grep MAPBOX

# Check gradle.properties
cat frontend_app/android/gradle.properties | grep MAPBOX
```

Both should show the same token (starting with `pk.`).

### Step 3: Test Network in Emulator

1. Open browser in emulator
2. Navigate to: https://www.mapbox.com
3. If it doesn't load, the emulator has network issues

### Step 4: Test Token Validity

1. Open browser on your computer
2. Navigate to: `https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=YOUR_TOKEN`
3. Replace `YOUR_TOKEN` with your actual token
4. Should return JSON, not an error

## Quick Fix Checklist

- [ ] Restart Android emulator
- [ ] Verify internet connection on host machine
- [ ] Check `assets/.env` has valid token (starts with `pk.`)
- [ ] Check `android/gradle.properties` has same token
- [ ] Run `flutter clean && flutter pub get`
- [ ] Rebuild app: `flutter run`
- [ ] Check console logs for detailed error
- [ ] Try on physical device if emulator issues persist

## Error Recovery

The app now includes:
- ✅ **Retry Button**: Click "Retry" to attempt loading the map again
- ✅ **Better Error Messages**: More detailed error information
- ✅ **Troubleshooting Tips**: Built-in tips shown in error screen
- ✅ **Debug Logging**: Console logs help diagnose the issue

## Still Not Working?

If none of the above solutions work:

1. **Check Mapbox Status**: https://status.mapbox.com/
2. **Verify Token Scopes**: Ensure token has required permissions
3. **Try Different Map Style**: Change `MapboxStyles.MAPBOX_STREETS` to `MapboxStyles.MAPBOX_OUTDOORS`
4. **Check Flutter/Mapbox Versions**: Ensure compatibility
5. **File an Issue**: Include console logs and error details

## Prevention

To avoid this error in the future:

1. ✅ Always set token in both `.env` and `gradle.properties`
2. ✅ Use `flutter clean` after changing configuration
3. ✅ Test on physical device for production builds
4. ✅ Keep Mapbox token up to date
5. ✅ Monitor Mapbox account for token expiration

## Additional Resources

- [Mapbox Flutter SDK Documentation](https://docs.mapbox.com/flutter/maps/guides/)
- [Mapbox Access Tokens Guide](https://docs.mapbox.com/accounts/guides/tokens/)
- [Flutter Network Troubleshooting](https://docs.flutter.dev/tools/debugging)

---

**Last Updated**: Based on Mapbox Maps Flutter SDK v2.17.0

