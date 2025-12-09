# Mapbox Integration Setup Guide

This guide explains how to set up Mapbox Maps SDK in the WorldTile Flutter app with a Flutter-safe .env system.

## 📋 Prerequisites

1. A Mapbox account (sign up at https://account.mapbox.com/)
2. A Mapbox public access token (starts with `pk.`)
3. Flutter SDK installed and configured

## 🔑 Step 1: Get Your Mapbox Public Token

1. Go to https://account.mapbox.com/access-tokens/
2. Create a new token or use an existing one
3. **IMPORTANT**: Use a **PUBLIC** token (starts with `pk.`)
   - ❌ Do NOT use secret tokens (start with `sk.`)
   - ✅ Public tokens are safe for client-side use

## 📦 Step 2: Configure Environment Variables

### 2.1 Update `.env` File

1. Navigate to `frontend_app/assets/.env`
2. Replace the placeholder token with your actual Mapbox public token:

```env
MAPBOX_PUBLIC_TOKEN=pk.your_actual_token_here
```

### 2.2 Verify `.env.example` (Optional)

The `.env.example` file serves as a template. Make sure your `.env` file follows the same format.

## 🤖 Step 3: Configure Android

### 3.1 Update `gradle.properties`

1. Open `frontend_app/android/gradle.properties`
2. Find the `MAPBOX_ACCESS_TOKEN` property
3. Replace the placeholder with your actual token:

```properties
MAPBOX_ACCESS_TOKEN=pk.your_actual_token_here
```

### 3.2 Verify Android Configuration Files

The following files have been pre-configured:
- ✅ `android/app/src/main/AndroidManifest.xml` - Contains Mapbox meta-data
- ✅ `android/app/src/main/res/values/strings.xml` - Contains token reference
- ✅ `android/app/build.gradle.kts` - Configured to use the token from gradle.properties

## 🍎 Step 4: Configure iOS

### 4.1 Update Xcode Build Settings

1. Open `frontend_app/ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project in the navigator
3. Go to **Build Settings** tab
4. Search for "User-Defined" settings
5. Add or update `MAPBOX_ACCESS_TOKEN`:
   - Click the `+` button
   - Name: `MAPBOX_ACCESS_TOKEN`
   - Value: `pk.your_actual_token_here`

### 4.2 Verify Info.plist

The `Info.plist` file has been pre-configured with:
```xml
<key>MBXAccessToken</key>
<string>$(MAPBOX_ACCESS_TOKEN)</string>
```

## 📱 Step 5: Install Dependencies

Run the following command to install all required packages:

```bash
cd frontend_app
flutter pub get
```

This will install:
- `flutter_dotenv` - For loading .env files
- `mapbox_maps_flutter` - Official Mapbox Maps SDK for Flutter

## 🗺️ Step 6: Using the World Map

### Basic Usage

The `WorldMapPage` widget is located at:
```
lib/screens/map/world_map_page.dart
```

To navigate to the world map from any screen:

```dart
import 'package:worldtile_app/screens/map/world_map_page.dart';

// Navigate to world map
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const WorldMapPage(),
  ),
);
```

### Features

- ✅ Full world view (zoom level 0)
- ✅ Centered at coordinates (0, 0)
- ✅ Uses Mapbox Streets style
- ✅ Automatic token validation
- ✅ Error handling for missing/invalid tokens
- ✅ Loading states

## 🏗️ Project Structure

```
frontend_app/
├── assets/
│   ├── .env                    # Your Mapbox token (gitignored)
│   └── .env.example            # Template file
├── android/
│   ├── app/
│   │   ├── build.gradle.kts    # Configured with Mapbox token
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Contains Mapbox meta-data
│   │       └── res/values/
│   │           └── strings.xml      # Token reference
│   └── gradle.properties       # Contains MAPBOX_ACCESS_TOKEN
├── ios/
│   └── Runner/
│       └── Info.plist          # Contains MBXAccessToken
└── lib/
    ├── main.dart               # Loads .env on startup
    └── screens/
        └── map/
            └── world_map_page.dart  # World map widget
```

## 🔍 Verification

### Check Token Loading

1. Run the app: `flutter run`
2. The app should load without errors
3. Navigate to `WorldMapPage`
4. The map should display correctly

### Common Issues

#### Issue: "MAPBOX_PUBLIC_TOKEN not found in .env file"
**Solution**: 
- Verify `assets/.env` exists
- Check that `pubspec.yaml` includes `assets/.env` in the assets section
- Ensure the token is on a single line without quotes

#### Issue: "Invalid Mapbox token. Must start with 'pk.'"
**Solution**: 
- Verify you're using a **public** token (starts with `pk.`)
- Do NOT use secret tokens (start with `sk.`)

#### Issue: Map doesn't load on Android
**Solution**:
- Verify `gradle.properties` has the correct token
- Clean and rebuild: `flutter clean && flutter pub get && flutter run`

#### Issue: Map doesn't load on iOS
**Solution**:
- Verify Xcode build settings have `MAPBOX_ACCESS_TOKEN` defined
- Clean build folder in Xcode: Product → Clean Build Folder
- Rebuild the app

## 🔒 Security Notes

1. **Never commit `.env` file** - It's already in `.gitignore`
2. **Use public tokens only** - Public tokens (pk.*) are safe for client-side use
3. **Token restrictions** - Consider setting URL restrictions in Mapbox dashboard
4. **Rotate tokens** - Regularly rotate tokens if compromised

## 📚 Additional Resources

- [Mapbox Maps SDK for Flutter Documentation](https://docs.mapbox.com/flutter/maps/guides/)
- [Mapbox Access Tokens Guide](https://docs.mapbox.com/accounts/guides/tokens/)
- [Flutter Dotenv Package](https://pub.dev/packages/flutter_dotenv)

## ✅ Checklist

Before running the app, ensure:

- [ ] Mapbox account created
- [ ] Public token obtained (starts with `pk.`)
- [ ] `assets/.env` file updated with your token
- [ ] `android/gradle.properties` updated with your token
- [ ] iOS Xcode build settings configured (if building for iOS)
- [ ] Dependencies installed (`flutter pub get`)
- [ ] App runs without errors

---

**Need Help?** Check the error messages in the app - they provide specific guidance for common configuration issues.

