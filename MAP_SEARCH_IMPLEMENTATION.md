# Map Search Bar Implementation

## 📋 Overview

This document describes the implementation of a search bar feature for the World Map that allows users to search for places and zoom to their locations. The implementation follows best practices and integrates seamlessly with the existing codebase.

## ✅ Implementation Summary

### Features Implemented
1. **Place Search**: Users can search for places using Mapbox Geocoding API
2. **Autocomplete**: Real-time search suggestions as user types
3. **Zoom to Location**: Automatic zoom animation when a place is selected
4. **Clear Button**: Easy way to clear the search and reset
5. **Error Handling**: Graceful error messages for network issues
6. **Loading States**: Visual feedback during search operations

## 🏗️ Architecture

### Directory Structure
```
frontend_app/
├── lib/
│   ├── services/
│   │   └── geocoding_service.dart      # Mapbox Geocoding API integration
│   ├── widgets/
│   │   └── map_search_bar.dart         # Reusable search bar widget
│   └── screens/
│       └── map/
│           └── world_map_page.dart     # Updated with search integration
```

### Component Breakdown

#### 1. GeocodingService (`lib/services/geocoding_service.dart`)
- **Purpose**: Handles all geocoding operations using Mapbox Geocoding API
- **Key Methods**:
  - `searchPlaces(String query, {int limit, Map<String, double>? proximity})`: Search for places
  - `reverseGeocode(double lng, double lat)`: Convert coordinates to place name
- **Data Model**: `PlaceResult` class represents search results
- **Error Handling**: Returns structured error responses
- **API**: Uses Mapbox Geocoding API v5 (`https://api.mapbox.com/geocoding/v5/mapbox.places`)

#### 2. MapSearchBar Widget (`lib/widgets/map_search_bar.dart`)
- **Purpose**: Reusable search bar component with autocomplete dropdown
- **Features**:
  - Real-time search with 500ms debounce
  - Autocomplete dropdown with place suggestions
  - Clear button (appears when text is entered)
  - Loading indicator during search
  - Error message display
  - Keyboard submission support
- **State Management**: Uses StatefulWidget with proper lifecycle management
- **Styling**: Matches app theme (AppTheme.surfaceColor, AppTheme.primaryColor)

#### 3. WorldMapPage Updates (`lib/screens/map/world_map_page.dart`)
- **New Methods**:
  - `_zoomToLocation(double latitude, double longitude, {double zoom, int duration})`: Animates camera to location
  - `_onPlaceSelected(double latitude, double longitude)`: Handles place selection from search bar
- **UI Integration**: Search bar overlay positioned on top of map
- **Visibility**: Search bar only shows when map is ready

## 🔧 Technical Details

### Library Versions Used
- **Flutter SDK**: >=3.0.0 <4.0.0
- **mapbox_maps_flutter**: ^2.17.0
- **http**: ^1.1.0
- **flutter_dotenv**: ^5.1.0

### API Integration
- **Service**: Mapbox Geocoding API
- **Authentication**: Uses `MAPBOX_PUBLIC_TOKEN` from `.env` file
- **Endpoint**: `/geocoding/v5/mapbox.places/{query}.json`
- **Features**: 
  - Place, locality, neighborhood, address, and POI search
  - Relevance-based sorting
  - Optional proximity biasing

### Camera Animation
- **Method**: `mapboxMap.flyTo()`
- **Default Zoom**: 12.0 (city level)
- **Animation Duration**: 1500ms
- **Options**: Smooth camera transition with MapAnimationOptions

### Search Behavior
- **Debounce**: 500ms delay to reduce API calls
- **Result Limit**: 5 suggestions (configurable)
- **Types**: Filters to places, localities, neighborhoods, addresses, and POIs
- **Sorting**: Results sorted by relevance score

## 📝 Code Examples

### Searching for a Place
```dart
final result = await GeocodingService.searchPlaces('rt nagar', limit: 5);

if (result['success'] == true) {
  final places = result['places'] as List<PlaceResult>;
  // Handle places list
}
```

### Zooming to a Location
```dart
await mapboxMap.flyTo(
  CameraOptions(
    center: Point(coordinates: Position(longitude, latitude)),
    zoom: 12.0,
  ),
  MapAnimationOptions(duration: 1500),
);
```

### Using the Search Bar Widget
```dart
MapSearchBar(
  onPlaceSelected: (lat, lng) {
    // Handle place selection
    _zoomToLocation(lat, lng);
  },
  hintText: 'Search for a place (e.g., rt nagar)',
)
```

## 🎨 UI/UX Features

### Search Bar Design
- **Position**: Top overlay on map (16px margins)
- **Background**: Dark surface color with shadow
- **Border**: Rounded corners (12px radius)
- **Icons**: Search icon (prefix), Clear icon (suffix when text present)
- **Typography**: Matches app theme (bodyLarge for text, bodySmall for hints)

### Dropdown Results
- **Position**: Below search bar
- **Max Height**: 300px with scrolling
- **Items**: Place name, context (city, state, country)
- **Interaction**: Tap to select, hover effects
- **Visual**: Location icon, styled list tiles

### Loading States
- **Searching**: Circular progress indicator with "Searching..." text
- **Error**: Error icon with message in red accent color
- **Empty**: No dropdown shown when no results

## 🔐 Security & Best Practices

### Token Management
- Token loaded from `.env` file
- No hardcoded credentials
- Error handling when token missing

### Error Handling
- Network errors caught and displayed to user
- API errors parsed and shown with user-friendly messages
- Graceful degradation when service unavailable

### Performance
- Debounced search to reduce API calls
- Limited result set (5 items)
- Efficient widget rebuilds with proper state management
- Dispose controllers and focus nodes properly

### Code Quality
- Follows existing codebase patterns
- Consistent naming conventions
- Proper documentation
- No linter errors
- Type-safe implementation

## 🧪 Testing Checklist

### Manual Testing
- [ ] Search bar appears when map is ready
- [ ] Typing shows loading indicator
- [ ] Search results appear in dropdown
- [ ] Selecting a place zooms to location
- [ ] Clear button appears when text is entered
- [ ] Clear button clears search and hides results
- [ ] Error messages display for network failures
- [ ] Keyboard submission selects first result
- [ ] Search works with various place names (cities, neighborhoods, addresses)

### Edge Cases
- [ ] Empty search query handled gracefully
- [ ] Network timeout handled
- [ ] Invalid Mapbox token shows error
- [ ] No search results handled
- [ ] Rapid typing doesn't cause issues (debounce works)
- [ ] Map not ready doesn't show search bar

## 📚 Usage Guide

### For Users
1. Open the "Buy Land" tab
2. Wait for map to load
3. Use the search bar at the top to search for places
4. Select a place from the dropdown
5. Map will automatically zoom to the selected location
6. Use clear button (X) to reset search

### For Developers
1. Search bar is integrated in `WorldMapPage`
2. Geocoding service can be used independently for other features
3. Search bar widget is reusable - can be used in other map screens
4. Zoom functionality can be extended for other camera operations

## 🚀 Future Enhancements

### Potential Improvements
1. **Recent Searches**: Store and display recent search queries
2. **Favorites**: Allow users to save favorite locations
3. **Current Location**: Add button to zoom to user's current location
4. **Map Markers**: Add markers at searched locations
5. **Route Planning**: Integrate directions to searched places
6. **Offline Search**: Cache recent searches for offline use
7. **Search History**: Maintain search history across sessions
8. **Voice Search**: Add voice input support

## 📖 API Reference

### GeocodingService
- `searchPlaces(String query, {int limit = 5, Map<String, double>? proximity})`: Search for places
- `reverseGeocode(double lng, double lat)`: Convert coordinates to place name

### PlaceResult
- `id`: Unique place identifier
- `name`: Primary place name
- `placeName`: Full place name with context
- `latitude`: Latitude coordinate
- `longitude`: Longitude coordinate
- `context`: Location context (city, state, country)
- `relevance`: Relevance score (0.0 - 1.0)

### MapSearchBar Widget
- `onPlaceSelected`: Callback when place is selected (lat, lng)
- `hintText`: Optional placeholder text

## 🐛 Troubleshooting

### Search Not Working
1. Verify `MAPBOX_PUBLIC_TOKEN` in `assets/.env`
2. Check internet connection
3. Verify Mapbox token has geocoding API access
4. Check console for error messages

### No Results Showing
1. Try different search terms
2. Check if place exists in Mapbox database
3. Verify API response in network logs
4. Check for API rate limits

### Zoom Not Working
1. Ensure map is fully loaded (`_isMapReady == true`)
2. Verify coordinates are valid
3. Check console for camera animation errors
4. Ensure Mapbox Maps SDK is properly initialized

## 📄 Files Modified/Created

### New Files
- `lib/services/geocoding_service.dart` - Geocoding service implementation
- `lib/widgets/map_search_bar.dart` - Search bar widget
- `MAP_SEARCH_IMPLEMENTATION.md` - This documentation

### Modified Files
- `lib/screens/map/world_map_page.dart` - Added search bar integration and zoom functionality

## ✅ Completion Status

All planned features have been implemented:
- ✅ Geocoding service with Mapbox API integration
- ✅ Search bar widget with autocomplete
- ✅ Clear button functionality
- ✅ Zoom to location on place selection
- ✅ Error handling and loading states
- ✅ Proper integration with existing codebase
- ✅ Follows app theme and design patterns

---

**Implementation Date**: 2024
**Status**: ✅ Complete and Ready for Testing







