# Phase 4: Rectangle Drawing Integration Plan

## 📋 Overview

This document provides the detailed implementation plan for integrating rectangle drawing functionality into `world_map_page.dart` according to Phase 4 requirements.

## 🔍 Codebase Analysis

### Library Versions
- **mapbox_maps_flutter**: `^2.17.0`
- **Flutter SDK**: `>=3.0.0 <4.0.0`
- **turf**: `^0.0.10` (transitive dependency)

### Existing Files (Already Implemented)
- ✅ `lib/screens/map/rectangle_drawing/rectangle_drawing_controller.dart`
- ✅ `lib/screens/map/rectangle_drawing/rectangle_model.dart`
- ✅ `lib/screens/map/rectangle_drawing/area_calculator.dart`
- ✅ `lib/widgets/map/draw_rectangle_button.dart`
- ✅ `lib/widgets/map/rectangle_controls.dart`
- ✅ `lib/utils/geometry_utils.dart`

### Mapbox Flutter SDK 2.17.0 API Reference

Based on `mapbox_flutter_documentation.md`:

1. **Map Tap Handler**: `MapWidget` supports `onTapListener: (MapContentGestureContext context) => void`
   - Access coordinates: `context.point.coordinates.lng` and `context.point.coordinates.lat`
   - Access touch position: `context.touchPosition.x` and `context.touchPosition.y`

2. **Camera Change Listener**: `MapWidget` supports `onCameraChangeListener: (CameraChangedEventData data) => void`
   - Access camera state via `mapboxMap.getCameraState()` to get zoom level

3. **Map Initialization**: Controller must be initialized after style loads via `onStyleLoadedListener`

## 🎯 Integration Requirements

### Phase 4 Checklist
- [ ] Modify `world_map_page.dart`:
  - [ ] Add rectangle controller initialization
  - [ ] Add map tap handler
  - [ ] Add camera change listener
  - [ ] Add draw button to UI
- [ ] Test full flow: button → placement → rectangle

## 📐 Implementation Details

### 1. State Variables to Add

```dart
RectangleDrawingController? _rectangleController;
double _currentZoom = 0.0;
```

### 2. Controller Initialization

Initialize the rectangle controller after the map style loads:

```dart
Future<void> _onStyleLoaded(StyleLoadedEventData eventData) async {
  // ... existing fog/halo code ...
  
  // Initialize rectangle drawing controller
  if (mapboxMap != null && _rectangleController == null) {
    _rectangleController = RectangleDrawingController();
    await _rectangleController!.init(mapboxMap!);
    
    // Get initial camera state
    final cameraState = await mapboxMap!.getCameraState();
    if (mounted) {
      setState(() {
        _currentZoom = cameraState.zoom;
      });
    }
  }
}
```

### 3. Map Tap Handler

Handle map taps to place rectangles when in placement mode:

```dart
void _onMapTap(MapContentGestureContext context) async {
  if (_rectangleController == null || !_rectangleController!.isInitialized) {
    return;
  }
  
  // Only handle taps if in placement mode
  if (_rectangleController!.isPlacementMode) {
    final position = Position(
      context.point.coordinates.lng,
      context.point.coordinates.lat,
    );
    
    await _rectangleController!.placeAt(position);
    
    if (mounted) {
      setState(() {
        // Trigger UI rebuild to show rectangle controls
      });
    }
  }
}
```

### 4. Camera Change Listener

Track zoom level to show/hide draw button:

```dart
void _onCameraChange(CameraChangedEventData data) async {
  if (mapboxMap == null) return;
  
  try {
    final cameraState = await mapboxMap!.getCameraState();
    if (mounted) {
      setState(() {
        _currentZoom = cameraState.zoom;
      });
    }
  } catch (e) {
    debugPrint('⚠️ Error getting camera state: $e');
  }
}
```

### 5. Draw Button Handler

Enable placement mode when button is pressed:

```dart
void _onDrawButtonPressed() {
  if (_rectangleController == null || !_rectangleController!.isInitialized) {
    return;
  }
  
  _rectangleController!.enterPlacementMode();
  
  if (mounted) {
    setState(() {
      // Trigger UI rebuild
    });
  }
}
```

### 6. Delete Handler

Remove rectangle when delete button is pressed:

```dart
Future<void> _onDeleteRectangle() async {
  if (_rectangleController == null) return;
  
  // Clear the rectangle by placing null
  // The controller should have a clear method or we dispose/recreate
  await _rectangleController!.dispose();
  
  // Reinitialize controller
  if (mapboxMap != null) {
    _rectangleController = RectangleDrawingController();
    await _rectangleController!.init(mapboxMap!);
  }
  
  if (mounted) {
    setState(() {
      // Trigger UI rebuild
    });
  }
}
```

### 7. UI Integration

Add widgets to the Stack in `build()` method:

```dart
Stack(
  children: [
    MapWidget(
      // ... existing props ...
      onTapListener: _onMapTap,
      onCameraChangeListener: _onCameraChange,
    ),
    // ... existing search bar and loading overlay ...
    
    // Rectangle drawing button (only visible when zoomed in enough)
    if (_isMapReady && _currentZoom >= 12.0)
      DrawRectangleButton(
        currentZoom: _currentZoom,
        isPlacementMode: _rectangleController?.isPlacementMode ?? false,
        onPressed: _onDrawButtonPressed,
      ),
    
    // Rectangle controls (only visible when rectangle exists)
    if (_isMapReady && _rectangleController?.rectangle != null)
      RectangleControls(
        rectangle: _rectangleController!.rectangle,
        onDelete: _onDeleteRectangle,
      ),
  ],
)
```

### 8. Cleanup

Dispose rectangle controller when widget is disposed:

```dart
@override
void dispose() {
  _loadingTimeout?.cancel();
  _rectangleController?.dispose();
  mapboxMap?.dispose();
  super.dispose();
}
```

## 🔧 Controller Enhancement

The controller needs a method to clear the rectangle. Add this to `rectangle_drawing_controller.dart`:

```dart
/// Clear the current rectangle (remove from map).
Future<void> clear() async {
  _rectangle = null;
  _placementMode = false;
  await _syncGeoJson();
}
```

## ✅ Testing Checklist

After implementation, test:

1. ✅ Map loads successfully
2. ✅ Draw button appears when zoom >= 12.0
3. ✅ Draw button disappears when zoom < 12.0
4. ✅ Tapping draw button enters placement mode (button text changes)
5. ✅ Tapping map in placement mode places rectangle
6. ✅ Rectangle appears with correct fill and border
7. ✅ Rectangle controls appear showing area
8. ✅ Delete button removes rectangle
9. ✅ Camera change listener updates zoom state
10. ✅ No errors in console

## 🐛 Potential Issues & Solutions

### Issue: Controller initialization timing
**Solution**: Initialize in `_onStyleLoaded` after style is ready, not in `_onMapCreated`

### Issue: Zoom state not updating
**Solution**: Use `mapboxMap.getCameraState()` in camera change listener (async operation)

### Issue: Rectangle not appearing
**Solution**: Ensure controller is initialized and style has loaded before placing

### Issue: Button not showing/hiding
**Solution**: Ensure `_currentZoom` state is properly updated and `setState` is called

## 📚 File Modifications

### Files to Modify
1. `lib/screens/map/world_map_page.dart` - Main integration
2. `lib/screens/map/rectangle_drawing/rectangle_drawing_controller.dart` - Add `clear()` method

### Import Statements to Add
```dart
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_drawing_controller.dart';
import 'package:worldtile_app/widgets/map/draw_rectangle_button.dart';
import 'package:worldtile_app/widgets/map/rectangle_controls.dart';
```

## 🚀 Implementation Order

1. Add `clear()` method to controller
2. Add state variables to `world_map_page.dart`
3. Add import statements
4. Modify `_onStyleLoaded` to initialize controller
5. Add `_onMapTap` handler
6. Add `_onCameraChange` handler
7. Add `_onDrawButtonPressed` handler
8. Add `_onDeleteRectangle` handler
9. Update `build()` method to include new widgets
10. Update `dispose()` method for cleanup
11. Test the complete flow

