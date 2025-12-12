# Rectangle Drawing System Rebuild - Integration Guide

## Overview

The rectangle drawing system has been completely rebuilt with a clean architecture. This document provides integration instructions for `world_map_page.dart`.

## New Architecture Files

All new files are in `lib/screens/map/rectangle_drawing/`:

1. **rectangle_model_new.dart** - Center-based rectangle model with width/height/rotation
2. **rectangle_controller_new.dart** - Main controller for all rectangle operations
3. **rectangle_renderer.dart** - Mapbox layer management
4. **rectangle_gestures.dart** - Handle hit testing and gesture control
5. **area_increase_event.dart** - Area tracking event model
6. **coordinate_converter.dart** (in `lib/utils/`) - Meters ↔ degrees conversion

## Integration Steps

### Step 1: Update Imports

Replace old rectangle imports with new ones:

```dart
// OLD (remove):
import 'rectangle_drawing/rectangle_drawing_controller.dart';
import 'rectangle_drawing/rectangle_model.dart';

// NEW (add):
import 'rectangle_drawing/rectangle_controller_new.dart';
import 'rectangle_drawing/rectangle_model_new.dart';
import 'services/land_service.dart';
```

### Step 2: Update State Variables

In `_WorldMapPageState`, replace rectangle-related state:

```dart
// OLD (remove all of these):
RectangleModel? _selectedRectangle;
bool _isResizeModeActive = false;
bool _isDraggingHandle = false;
int? _activeCornerIndex;
bool _waitingForDragStart = false;
CameraState? _cameraStateBeforeDrag;
Offset? _lastPanPosition;
RectangleDrawingController? _rectangleController;

// NEW (add):
RectangleController? _rectangleController;  // Use new controller
bool _isRectangleSelected = false;  // Track selection state
```

### Step 3: Update Initialization

In `_onStyleLoaded`:

```dart
// OLD (remove):
if (_rectangleController == null) {
  _rectangleController = RectangleDrawingController();
  await _rectangleController!.init(currentMap);
  // ...
}

// NEW (replace with):
if (_rectangleController == null) {
  _rectangleController = RectangleController();
  await _rectangleController!.init(currentMap);
  
  // Set callbacks
  _rectangleController!.setValidationFailedCallback(() {
    _showAreaWarning();
  });
  
  _rectangleController!.setAreaIncreasedCallback((event) {
    debugPrint('Area increased by ${event.deltaMetersSquared.toStringAsFixed(2)} m²');
  });
  
  debugPrint('✅ Rectangle controller initialized');
}
```

### Step 4: Simplify Map Tap Handler

Replace `_onMapTap`:

```dart
/// Handles map tap events for rectangle creation and selection
void _onMapTap(MapContentGestureContext ctx) async {
  if (_rectangleController == null || !_rectangleController!.isInitialized) {
    return;
  }

  final tap = ctx.point.coordinates;
  
  // Check if tapping a handle (will be handled by drag gestures)
  final handleType = await RectangleGestures.hitTestHandle(
    tap,
    _rectangleController!.rectangle!,
    mapboxMap!,
  );
  
  if (handleType != null && _isRectangleSelected) {
    // Handle tapped - start drag (handled separately via GestureDetector)
    return;
  }

  // Handle map tap via controller
  final handled = await _rectangleController!.handleMapTap(tap);
  
  if (handled) {
    // Rectangle created or selected
    if (_rectangleController!.rectangle != null) {
      setState(() {
        _isRectangleSelected = true;
      });
      await _rectangleController!.setSelected(true);
    }
  } else {
    // Deselect
    if (_isRectangleSelected) {
      setState(() {
        _isRectangleSelected = false;
      });
      await _rectangleController!.setSelected(false);
    }
  }
  
  if (mounted) setState(() {});
}
```

### Step 5: Update Gesture Handlers

Replace old pan handlers with new ones:

```dart
/// Handle pan start for handle dragging
void _onPanStart(DragStartDetails details) async {
  if (_rectangleController == null || 
      _rectangleController!.rectangle == null || 
      !_isRectangleSelected ||
      mapboxMap == null) {
    return;
  }

  // Convert screen position to map coordinates
  final screenPos = ScreenCoordinate(
    x: details.localPosition.dx,
    y: details.localPosition.dy,
  );

  try {
    final mapCoord = await mapboxMap!.coordinateForPixel(screenPos);
    final tapPos = mapCoord.coordinates;

    // Check which handle was tapped
    final handleType = await RectangleGestures.hitTestHandle(
      tapPos,
      _rectangleController!.rectangle!,
      mapboxMap!,
    );

    if (handleType != null) {
      await _rectangleController!.startDrag(handleType, tapPos);
    }
  } catch (e) {
    debugPrint('⚠️ Pan start error: $e');
  }
}

/// Handle pan update for handle dragging
void _onPanUpdate(DragUpdateDetails details) async {
  if (_rectangleController == null || mapboxMap == null) {
    return;
  }

  final screenPos = ScreenCoordinate(
    x: details.localPosition.dx,
    y: details.localPosition.dy,
  );

  try {
    final mapCoord = await mapboxMap!.coordinateForPixel(screenPos);
    final dragPos = mapCoord.coordinates;

    await _rectangleController!.updateDrag(dragPos);
    
    if (mounted) setState(() {});
  } catch (e) {
    debugPrint('⚠️ Pan update error: $e');
  }
}

/// Handle pan end
Future<void> _onPanEnd(DragEndDetails details) async {
  if (_rectangleController == null) return;

  await _rectangleController!.endDrag();
  
  if (mounted) setState(() {});
}
```

### Step 6: Update Draw Button Handler

```dart
/// Handles draw button press to enter placement mode
void onDrawButtonPressed() {
  if (_rectangleController == null || !_rectangleController!.isInitialized) {
    debugPrint('⚠️ Rectangle controller not initialized');
    return;
  }

  _rectangleController!.enterPlacementMode();

  if (mounted) {
    setState(() {});
  }

  debugPrint('🎨 Entered rectangle placement mode');
}
```

### Step 7: Update Delete Handler

```dart
/// Handles rectangle delete action
Future<void> onDeleteRectangle() async {
  if (_rectangleController == null) return;

  try {
    await _rectangleController!.clear();

    if (mounted) {
      setState(() {
        _isRectangleSelected = false;
      });
    }

    debugPrint('🗑️ Rectangle deleted');
  } catch (e) {
    debugPrint('❌ Error deleting rectangle: $e');
  }
}
```

### Step 8: Update Save Handler

```dart
/// Save the current rectangle to MongoDB
Future<void> saveCurrentRectangle() async {
  if (_rectangleController?.rectangle == null) {
    debugPrint('⚠️ No rectangle to save');
    return;
  }

  final rectangle = _rectangleController!.rectangle!;
  final mongoData = rectangle.toMongoData();

  try {
    final result = await LandService.savePolygon(
      geometry: mongoData['geometry'] as Map<String, dynamic>,
      areaInAcres: rectangle.areaInAcres,
      name: 'My Rectangle ${DateTime.now().toString().substring(0, 10)}',
      center: mongoData['center'] as Map<String, double>,
      widthMeters: mongoData['widthMeters'] as double,
      heightMeters: mongoData['heightMeters'] as double,
      rotationDegrees: mongoData['rotationDegrees'] as double,
      areaInMetersSquared: mongoData['areaInMetersSquared'] as double,
      areaIncreaseHistory: mongoData['areaIncreaseHistory'] as List<Map<String, dynamic>>,
    );

    if (result['success'] == true) {
      // Reload polygons
      await _loadUserPolygons();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rectangle saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      debugPrint('✅ Rectangle saved successfully');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rectangle: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('❌ Error saving rectangle: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving rectangle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Step 9: Update Load Polygons

```dart
/// Load user polygons from backend
Future<void> _loadUserPolygons() async {
  if (_isLoadingPolygons) return;

  setState(() {
    _isLoadingPolygons = true;
  });

  try {
    final result = await LandService.getUserPolygons();

    if (result['success'] == true) {
      final polygonsData = result['polygons'] as List;

      // Load each polygon into controller
      for (final data in polygonsData) {
        await _rectangleController?.loadFromMongoData(
          data as Map<String, dynamic>,
        );
      }

      debugPrint('✅ Loaded ${polygonsData.length} user polygons');
    } else {
      debugPrint('⚠️ Failed to load polygons: ${result['message']}');
    }
  } catch (e) {
    debugPrint('❌ Error loading polygons: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingPolygons = false;
      });
    }
  }
}
```

### Step 10: Add Area Warning Helper

```dart
/// Show area validation warning
void _showAreaWarning() {
  if (!mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Rectangle must be at least 1 acre (4046.86 m²)'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 2),
    ),
  );
}
```

### Step 11: Remove Old Methods

Remove these old methods completely:
- `_onScroll` (rectangle-specific logic)
- `_onDragEndFallback`
- `_disableMapGestures` / `_enableMapGestures` (now handled by RectangleGestures)
- `onResizeButtonPressed` (not needed with new system)

### Step 12: Update GestureDetector

Keep the GestureDetector but update conditions:

```dart
final wrappedMap = GestureDetector(
  onPanStart: _isRectangleSelected ? _onPanStart : null,
  onPanUpdate: _isRectangleSelected ? _onPanUpdate : null,
  onPanEnd: _isRectangleSelected ? _onPanEnd : null,
  behavior: HitTestBehavior.opaque,
  child: mapWidget,
);
```

### Step 13: Update Widget Build

Update RectangleControls widget usage:

```dart
if (_isMapReady && _rectangleController?.rectangle != null)
  RectangleControls(
    rectangle: _rectangleController!.rectangle,
    onDelete: onDeleteRectangle,
    onSave: saveCurrentRectangle,
    // Remove onResize - not needed
  ),
```

## Key Differences

### Old System:
- Corner-based rectangle storage
- Non-uniform scaling
- Complex gesture handling in world_map_page
- Manual handle management

### New System:
- Center-based rectangle storage (center + width + height + rotation)
- Uniform scaling only (preserves shape)
- Gesture handling encapsulated in controller
- Automatic handle management via renderer
- Built-in area validation and tracking
- Debounced updates for performance

## Testing Checklist

After integration, test:
- [ ] Rectangle creation on tap
- [ ] Handle dragging (uniform scaling)
- [ ] Rotation handle dragging
- [ ] Area validation (1 acre minimum)
- [ ] Area increase tracking
- [ ] Save to MongoDB
- [ ] Load from MongoDB
- [ ] Selection/deselection
- [ ] Delete rectangle
- [ ] Performance (smooth dragging)

## Troubleshooting

### Rectangle not appearing
- Check controller initialization in `_onStyleLoaded`
- Verify renderer is initialized
- Check Mapbox style is loaded

### Handles not showing
- Ensure rectangle is selected (`setSelected(true)`)
- Check handle layers are created in renderer

### Scaling not uniform
- Verify using `HandleType.side*` handles (not corner handles)
- Check `_updateUniformScale` is called

### Area validation not working
- Verify `MINIMUM_AREA_METERS_SQUARED` constant (4046.86)
- Check `isValidArea` getter in model

### MongoDB save failing
- Verify backend model updated with new fields
- Check `LandService.savePolygon` includes all fields
- Verify authentication token

