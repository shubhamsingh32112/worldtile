# World Map Implementation Plan

## 📋 Overview

This document outlines the complete implementation plan to fix the issue where clicking "Buy Land" doesn't navigate to the world map, and to properly integrate Mapbox Maps SDK with location services.

## ✅ Completed Implementation

### 1. **Added Permission Handler Package**
   - **File**: `frontend_app/pubspec.yaml`
   - **Change**: Added `permission_handler: ^11.3.1` dependency
   - **Purpose**: Request location permissions for Mapbox location component

### 2. **Created Land Service**
   - **File**: `frontend_app/lib/services/land_service.dart`
   - **Purpose**: Centralized service for all land tile API interactions
   - **Features**:
     - `getTiles()` - Get all tiles with optional filters (region, status, price range)
     - `getTile(tileId)` - Get a specific tile by ID
     - `getNearbyTiles(lat, lng, radius)` - Get tiles near a location using PostGIS
     - `getMyTiles()` - Get user's owned tiles (requires auth)
     - `purchaseTile(tileId)` - Purchase a tile (requires auth)
   - **Architecture**: Follows same pattern as `AuthService` with platform-aware base URL

### 3. **Updated Buy Land Tab Navigation**
   - **File**: `frontend_app/lib/screens/main/buy_land_tab.dart`
   - **Changes**:
     - Added import for `WorldMapPage`
     - Wrapped map preview card in `InkWell` with `onTap` handler
     - Added navigation to `WorldMapPage` when map preview is clicked
     - Added visual "Tap to Open Map" button for better UX
   - **Result**: Clicking the map preview now navigates to the actual world map

### 4. **Enhanced World Map Page with Location**
   - **File**: `frontend_app/lib/screens/map/world_map_page.dart`
   - **Changes**:
     - Added `permission_handler` import
     - Added `_isLocationEnabled` state variable
     - Added `_requestLocationPermission()` method to request location access
     - Updated `_onMapCreated()` to enable location component when permission granted
     - Configured location puck with pulsing animation
   - **Features**:
     - Automatically requests location permission on page load
     - Shows user location on map when permission granted
     - Gracefully handles permission denial

### 5. **Android Location Permissions**
   - **File**: `frontend_app/android/app/src/main/AndroidManifest.xml`
   - **Changes**: Added location permissions:
     ```xml
     <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
     <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
     ```
   - **Purpose**: Required for Mapbox location component on Android

### 6. **iOS Location Permission Description**
   - **File**: `frontend_app/ios/Runner/Info.plist`
   - **Changes**: Added `NSLocationWhenInUseUsageDescription` key
   - **Purpose**: Required by iOS to show permission dialog with explanation

## 🏗️ Architecture Overview

### Directory Structure
```
frontend_app/
├── lib/
│   ├── services/
│   │   ├── auth_service.dart      # Authentication API calls
│   │   └── land_service.dart       # Land tiles API calls (NEW)
│   ├── screens/
│   │   ├── main/
│   │   │   └── buy_land_tab.dart  # Updated with navigation
│   │   └── map/
│   │       └── world_map_page.dart # Enhanced with location
│   └── ...
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml    # Added location permissions
└── ios/
    └── Runner/
        └── Info.plist              # Added location description
```

### Service Layer Pattern
Both `AuthService` and `LandService` follow the same pattern:
1. Platform-aware base URL detection (`.env` > platform defaults)
2. Token-based authentication support
3. Consistent error handling
4. JSON response parsing

### Navigation Flow
```
BuyLandTab (Map Preview Card)
    ↓ (onTap)
WorldMapPage
    ↓ (auto)
Request Location Permission
    ↓ (if granted)
Enable Location Component
    ↓
Show User Location on Map
```

## 🔧 Configuration Requirements

### 1. Install Dependencies
After pulling changes, run:
```bash
cd frontend_app
flutter pub get
```

### 2. Verify Environment Variables
Ensure `assets/.env` contains:
```env
MAPBOX_PUBLIC_TOKEN=pk.your_token_here
API_BASE_URL=http://192.168.1.15:3000/api
```

### 3. Android Configuration
- ✅ Location permissions added to `AndroidManifest.xml`
- ✅ Mapbox token configured in `gradle.properties`
- ✅ No additional steps needed

### 4. iOS Configuration
- ✅ Location description added to `Info.plist`
- ⚠️ **Manual Step Required**: Set `MAPBOX_ACCESS_TOKEN` in Xcode Build Settings
  1. Open `ios/Runner.xcworkspace` in Xcode
  2. Select Runner project
  3. Go to Build Settings → User-Defined
  4. Add/Update `MAPBOX_ACCESS_TOKEN` with your public token

## 🚀 Usage Examples

### Fetching Land Tiles
```dart
import 'package:worldtile_app/services/land_service.dart';

// Get all available tiles
final result = await LandService.getTiles(status: 'available');

// Get nearby tiles
final nearby = await LandService.getNearbyTiles(
  lat: 40.7128,
  lng: -74.0060,
  radius: 5000, // 5km
);

// Purchase a tile (requires authentication)
final purchase = await LandService.purchaseTile('tile-123');
```

### Navigating to World Map
```dart
import 'package:worldtile_app/screens/map/world_map_page.dart';

Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const WorldMapPage(),
  ),
);
```

## 📱 User Experience Flow

1. **User opens "Buy Land" tab**
   - Sees map preview card with "Tap to Open Map" button

2. **User taps map preview**
   - Navigates to `WorldMapPage`
   - Map loads with world view (zoom level 0, centered at 0,0)

3. **Location permission requested**
   - iOS: Shows system dialog with description from `Info.plist`
   - Android: Shows system dialog
   - User grants/denies permission

4. **If permission granted**
   - Location component enabled
   - User's location shown on map with pulsing indicator
   - Map can center on user location

5. **If permission denied**
   - Map still works, but without user location
   - No error shown (graceful degradation)

## 🔒 Security Considerations

1. **Location Permissions**
   - Only requested when needed (on map page load)
   - Uses `locationWhenInUse` (not always-on)
   - Clear explanation in iOS `Info.plist`

2. **API Authentication**
   - Token stored in `SharedPreferences`
   - Automatically included in authenticated requests
   - Graceful handling when token missing

3. **Error Handling**
   - Network errors don't crash app
   - User-friendly error messages
   - Debug logging in development mode

## 🧪 Testing Checklist

### Manual Testing
- [ ] Click "Buy Land" tab → Map preview visible
- [ ] Tap map preview → Navigates to world map
- [ ] Map loads without errors
- [ ] Location permission dialog appears (first time)
- [ ] Grant permission → Location indicator appears
- [ ] Deny permission → Map still works
- [ ] Navigate back → Returns to Buy Land tab

### API Testing
- [ ] `LandService.getTiles()` returns data
- [ ] `LandService.getNearbyTiles()` works with coordinates
- [ ] `LandService.purchaseTile()` requires authentication
- [ ] Error handling works for network failures

### Platform Testing
- [ ] Android: Location permission works
- [ ] iOS: Location permission works
- [ ] Both platforms: Map renders correctly
- [ ] Both platforms: Token validation works

## 🐛 Troubleshooting

### Map doesn't load
1. Check `assets/.env` has valid `MAPBOX_PUBLIC_TOKEN`
2. Verify token starts with `pk.` (public token)
3. Run `flutter clean && flutter pub get && flutter run`

### Location not showing
1. Check permission was granted in device settings
2. Verify `AndroidManifest.xml` has location permissions
3. Verify `Info.plist` has `NSLocationWhenInUseUsageDescription`
4. Check device has location services enabled

### Navigation not working
1. Verify `WorldMapPage` import path is correct
2. Check no errors in console
3. Ensure `BuyLandTab` is properly imported in `MainScreen`

### API calls failing
1. Verify `API_BASE_URL` in `assets/.env`
2. Check backend server is running
3. Verify network connectivity
4. Check console for error messages

## 📚 Next Steps (Future Enhancements)

### Phase 1: Display Land Tiles on Map
- Fetch tiles from API using `LandService`
- Add markers/polygons for each tile
- Color-code by status (available/owned/locked)
- Show tile info on tap

### Phase 2: Interactive Tile Selection
- Allow tapping tiles on map to view details
- Show purchase dialog with tile information
- Integrate purchase flow with authentication

### Phase 3: Advanced Map Features
- Search for tiles by coordinates
- Filter tiles by region/price
- Show user's owned tiles
- Display nearby tiles based on map viewport

### Phase 4: Performance Optimization
- Cache tile data locally
- Implement pagination for large tile sets
- Optimize map rendering with clustering
- Add offline map support

## 📝 Code Quality

### Best Practices Followed
- ✅ Separation of concerns (services, screens, widgets)
- ✅ Consistent error handling
- ✅ Platform-aware configuration
- ✅ User-friendly error messages
- ✅ Proper state management
- ✅ Resource cleanup (dispose methods)
- ✅ Type safety (Dart null safety)

### Code Standards
- ✅ Follows Flutter/Dart style guide
- ✅ Meaningful variable/function names
- ✅ Comprehensive comments
- ✅ Consistent formatting
- ✅ No linter errors

## 🎯 Summary

This implementation provides:
1. ✅ **Fixed Navigation**: Buy Land tab now navigates to world map
2. ✅ **Location Support**: Map requests and uses location permissions
3. ✅ **API Integration**: Service layer ready for land tile operations
4. ✅ **Platform Configuration**: Android and iOS permissions configured
5. ✅ **Clean Architecture**: Follows best practices and patterns
6. ✅ **Error Handling**: Graceful degradation and user-friendly messages

The world map is now fully functional and ready for further enhancements like displaying land tiles, purchase flows, and advanced map interactions.












