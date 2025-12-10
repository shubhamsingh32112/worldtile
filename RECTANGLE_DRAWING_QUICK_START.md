# Rectangle Drawing Feature - Quick Start Guide

## 📋 Implementation Checklist

### Phase 1: Setup & Core Models
- [x] Create directory structure:
  - `lib/screens/map/rectangle_drawing/`
  - `lib/widgets/map/`
  - `lib/utils/`
- [x] Implement `rectangle_model.dart`
- [x] Implement `area_calculator.dart`
- [x] Implement `geometry_utils.dart`

### Phase 2: Drawing Controller
- [x] Implement `rectangle_drawing_controller.dart`
- [ ] Test layer creation and source management
- [ ] Test rectangle placement

### Phase 3: UI Components
- [x] Implement `draw_rectangle_button.dart`
- [x] Implement `rectangle_controls.dart`
- [ ] Test button visibility based on zoom

### Phase 4: Integration
- [x] Modify `world_map_page.dart`:
  - [x] Add rectangle controller initialization
  - [x] Add map tap handler
  - [x] Add camera change listener
  - [x] Add draw button to UI
- [ ] Test full flow: button → placement → rectangle

### Phase 5: Interactions
- [ ] Implement handle drag (resize)
- [ ] Implement center drag (move)
- [ ] Implement delete functionality
- [ ] Test all interactions

### Phase 6: Persistence (MongoDB)
- [x] Polygon model in backend (MongoDB with Mongoose)
- [x] Polygon routes (CRUD) - `/api/polygons`
- [x] MongoDB 2dsphere geospatial index configured
- [x] Save polygon functionality in frontend (LandService.savePolygon)
- [x] Load user polygons functionality (LandService.getUserPolygons)
- [x] RectangleModel supports MongoDB ID fields
- [x] Save/load integration in world_map_page.dart
- [ ] Test save/load on map load
- [ ] Test update and delete operations

### Phase 7: Polish & Testing
- [ ] Add visual feedback
- [ ] Optimize performance
- [ ] Test on physical device
- [ ] Test persistence (save, load, update, delete)
- [ ] Fix any issues

## 🚀 Quick Implementation Order

1. **Start Simple**: Create a rectangle model and basic placement
2. **Add Layers**: Implement fill and line layers
3. **Add Handles**: Add corner and center handles
4. **Add Interactions**: Implement drag handlers
5. **Add UI**: Add button and controls
6. **Polish**: Add area display, delete, etc.

## 🔑 Key Files to Create

### Frontend
```
lib/
├── screens/map/rectangle_drawing/
│   ├── rectangle_model.dart
│   ├── rectangle_drawing_controller.dart
│   ├── area_calculator.dart
│   └── geometry_utils.dart
├── widgets/map/
│   ├── draw_rectangle_button.dart
│   └── rectangle_controls.dart
├── services/
│   └── land_service.dart (✅ Already includes polygon methods)
└── utils/
    └── (if needed)
```

### Backend
```
backend/src/
├── models/
│   └── Polygon.model.ts (✅ Already exists - MongoDB)
├── routes/
│   └── polygon.routes.ts (✅ Already exists - CRUD endpoints)
└── server.ts (✅ Already configured - /api/polygons)
```

**Note**: Backend is already complete! The polygon API uses MongoDB with:
- GeoJSON Polygon format
- 2dsphere index for geospatial queries
- User authentication required for all operations
- CRUD endpoints: POST, GET, PUT, DELETE /api/polygons

## ⚡ Critical API Verification

Before implementing, verify these Mapbox Maps Flutter SDK 2.17.0 APIs:

1. **Map Click Events** ✅ Verified for 2.17.0
   ```dart
   // MapWidget supports onTapListener (verified in codebase)
   MapWidget(
     onTapListener: (MapContentGestureContext context) {
       final lng = context.point.coordinates.lng;
       final lat = context.point.coordinates.lat;
       // Handle tap
     },
   )
   ```

2. **Layer Management** ✅ Verified for 2.17.0
   ```dart
   // These methods exist and are working (verified in codebase)
   await style.addSource(GeoJsonSource(
     id: 'my-source',
     data: jsonEncode(geoJson),
   ));
   await style.addLayer(FillLayer(
     id: 'my-fill-layer',
     sourceId: 'my-source',
     fillColor: color.value, // Must be int, not Color
     fillOpacity: 0.3,
   ));
   // Update source data using setStyleSourceProperty
   await style.setStyleSourceProperty(
     'my-source',
     'data',
     jsonEncode(updatedGeoJson),
   );
   ```

3. **Camera Changes** ✅ Verified for 2.17.0
   ```dart
   // MapWidget supports onCameraChangeListener (verified in codebase)
   MapWidget(
     onCameraChangeListener: (CameraChangedEventData data) async {
       final cameraState = await mapboxMap.getCameraState();
       final zoom = cameraState.zoom;
       // Handle camera change
     },
   )
   ```

## 🎯 Default Rectangle Size

1 acre ≈ 63.6149 meters (square)
At equator: 1 degree ≈ 111,320 meters
So 1 acre ≈ 0.000571 degrees

```dart
const double acreSizeInDegrees = 0.000571;
const double halfSize = acreSizeInDegrees / 2;
```

## 📐 Area Calculation

**Current Implementation**: Uses custom shoelace formula with Web Mercator projection

```dart
// Current implementation in area_calculator.dart
import 'package:worldtile_app/screens/map/rectangle_drawing/area_calculator.dart';

// Calculate area in acres
final acres = AreaCalculator.calculateAreaInAcres(coordinates);

// Format for display
final formatted = AreaCalculator.formatArea(acres);
// Returns: "X.XX acres" or "X sq ft" for small areas

// Convert to MongoDB GeoJSON format
final geoJson = AreaCalculator.toMongoGeoJson(coordinates);
```

**Algorithm**: 
- Uses shoelace formula on Web Mercator projected coordinates
- More accurate than simple lat/lng calculations
- Handles polygons of any shape

## 🎨 Color Scheme (from AppTheme)

- **Fill**: `AppTheme.primaryColor` with 30% opacity
- **Border**: `AppTheme.primaryColor` solid
- **Handles**: `AppTheme.accentColor` circles
- **Text**: `AppTheme.textPrimary`

## 🐛 Common Issues & Solutions

### Issue: Map clicks not working
**Solution**: Wrap MapWidget in GestureDetector or use annotation tap callbacks

### Issue: Layers not updating
**Solution**: Ensure source data is valid GeoJSON, check layer order

### Issue: Area calculation wrong
**Solution**: 
- Verify coordinate order is [lng, lat] (longitude first)
- Ensure polygon is closed (first point = last point)
- Check that coordinates are valid lat/lng ranges
- Current implementation uses shoelace formula with Web Mercator projection

### Issue: Handles not draggable
**Solution**: Use PointAnnotationManager with draggable property, or implement custom gesture handling

## 💾 MongoDB Database Setup

**✅ Already Configured!** The backend uses MongoDB with Mongoose.

### Database Schema

The `Polygon` model stores rectangles/polygons in MongoDB:

```typescript
// backend/src/models/Polygon.model.ts
{
  userId: ObjectId,           // References User model
  name?: string,              // Optional name
  description?: string,       // Optional description
  geometry: {
    type: 'Polygon',
    coordinates: [[[lng, lat], ...]]  // GeoJSON format
  },
  areaInAcres: number,
  createdAt: Date,
  updatedAt: Date
}
```

### Indexes

MongoDB automatically creates these indexes:
- **2dsphere index** on `geometry` field for geospatial queries
- **Index** on `userId` for fast user polygon queries
- **Compound index** on `userId + createdAt` for sorted queries

### API Endpoints

All endpoints require authentication (JWT token):

- `POST /api/polygons` - Create a new polygon
- `GET /api/polygons` - Get all polygons for authenticated user
- `GET /api/polygons/:id` - Get specific polygon
- `PUT /api/polygons/:id` - Update polygon
- `DELETE /api/polygons/:id` - Delete polygon
- `GET /api/polygons/nearby?lat=X&lng=Y&radius=Z` - Get polygons near location (public)

### Environment Variables

```env
MONGODB_URI=mongodb://localhost:27017/worldtile
# Or use MongoDB Atlas connection string
```

### Frontend Integration

The `LandService` already provides methods:
- `savePolygon()` - Save rectangle as polygon
- `getUserPolygons()` - Load user's polygons
- `deletePolygon(id)` - Delete polygon

**No migration needed!** Everything is already set up.

## 🔐 Authentication Required

**Important**: Rectangle persistence requires user authentication. Ensure:
- User is logged in before drawing rectangles
- Auth token is available in SharedPreferences
- Backend routes use `authenticate` middleware

## 📋 Detailed Implementation Plan for Remaining Phases

### Phase 5: Interactive Dragging (Resize & Move)

**Goal**: Allow users to drag corner handles to resize and drag center to move rectangles.

#### 5.1 Add Handle Annotations

**File**: `lib/screens/map/rectangle_drawing/rectangle_handles.dart` (new)

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../rectangle_model.dart';
import '../../theme/app_theme.dart';

/// Manages visual handles (corner + center) for rectangle interaction
class RectangleHandles {
  final MapboxMap mapboxMap;
  final String sourceId = 'rectangle-handles-source';
  final String layerId = 'rectangle-handles-layer';
  
  List<PointAnnotation>? _handles;
  PointAnnotationManager? _manager;
  
  RectangleHandles(this.mapboxMap);
  
  /// Create handles for corners (0-3) and center (4)
  Future<void> updateHandles(RectangleModel? rectangle) async {
    // Remove existing handles
    await clear();
    
    if (rectangle == null) return;
    
    final manager = mapboxMap.annotations.createPointAnnotationManager();
    _manager = manager;
    
    // Create corner handles (0-3)
    final cornerHandles = rectangle.corners.asMap().entries.map((entry) {
      final idx = entry.key;
      final pos = entry.value;
      return PointAnnotation(
        id: 'corner-$idx',
        geometry: Point(coordinates: Position(pos.lng, pos.lat)),
        image: _createHandleImage(), // Circle icon
        draggable: true,
      );
    }).toList();
    
    // Create center handle (4)
    final center = rectangle.center;
    final centerHandle = PointAnnotation(
      id: 'center-4',
      geometry: Point(coordinates: Position(center.lng, center.lat)),
      image: _createCenterHandleImage(), // Different icon
      draggable: true,
    );
    
    _handles = [...cornerHandles, centerHandle];
    await manager.createMulti(_handles!);
    
    // Set up drag listeners
    manager.addOnPointAnnotationDragEndListener(_onHandleDragEnd);
  }
  
  Future<void> clear() async {
    await _manager?.deleteAll();
    _handles = null;
  }
  
  void _onHandleDragEnd(PointAnnotation annotation, ScreenCoordinate coordinate) async {
    // Determine which handle was dragged
    final id = annotation.id.toString();
    // Handle drag logic...
  }
  
  Uint8List _createHandleImage() {
    // Create a circle image for corner handles
    // Return as Uint8List PNG bytes
  }
}
```

**Key Implementation Notes**:
- Use `PointAnnotationManager` for draggable handles
- Handles must be recreated when rectangle changes
- Handle drag events to update rectangle coordinates
- Distinguish between corner drag (resize) and center drag (move)

#### 5.2 Implement Drag Handlers

**File**: `lib/screens/map/rectangle_drawing/rectangle_drawing_controller.dart` (modify)

```dart
// Add to RectangleDrawingController class:

RectangleHandles? _handles;

Future<void> init(MapboxMap mapboxMap) async {
  _mapboxMap = mapboxMap;
  await _ensureStyleObjects();
  
  // Initialize handles manager
  _handles = RectangleHandles(mapboxMap);
  
  _initialized = true;
}

/// Handle corner drag (resize)
Future<void> onCornerDragged(int cornerIndex, Position newPosition) async {
  await updateCorner(cornerIndex, newPosition);
  await _handles?.updateHandles(_rectangle);
}

/// Handle center drag (move)
Future<void> onCenterDragged(Position newPosition) async {
  if (_rectangle == null) return;
  final currentCenter = _rectangle!.center;
  final delta = Position(
    newPosition.lng - currentCenter.lng,
    newPosition.lat - currentCenter.lat,
  );
  await move(delta);
  await _handles?.updateHandles(_rectangle);
}

Future<void> clear() async {
  _rectangle = null;
  _placementMode = false;
  await _handles?.clear();
  await _syncGeoJson();
}

Future<void> dispose() async {
  await _handles?.clear();
  // ... existing dispose code
}
```

#### 5.3 Update WorldMapPage

**File**: `lib/screens/map/world_map_page.dart` (modify)

```dart
// After rectangle is placed, update handles
Future<void> _onMapTap(MapContentGestureContext context) async {
  if (_rectangleController == null || !_rectangleController!.isInitialized) {
    return;
  }

  if (_rectangleController!.isPlacementMode) {
    final position = Position(
      context.point.coordinates.lng,
      context.point.coordinates.lat,
    );

    await _rectangleController!.placeAt(position);
    
    // Update handles after placement
    await _rectangleController!.updateHandles();
    
    if (mounted) {
      setState(() {});
    }
  }
}
```

**Testing Checklist**:
- [ ] Corner handles appear at rectangle corners
- [ ] Center handle appears at rectangle center
- [ ] Dragging corner handle resizes rectangle
- [ ] Dragging center handle moves rectangle
- [ ] Area updates correctly when resizing
- [ ] Handles disappear when rectangle is deleted

---

### Phase 7: Polish & Testing

#### 7.1 Visual Feedback

**Tasks**:
- Add subtle animation when rectangle is placed
- Show loading state during area calculation
- Add haptic feedback on handle drag
- Improve handle visibility (larger, with shadow)

**File**: `lib/widgets/map/rectangle_controls.dart` (enhance)

```dart
// Add animation when controls appear
AnimatedSwitcher(
  duration: Duration(milliseconds: 200),
  child: rectangle != null 
    ? RectangleControls(...) 
    : SizedBox.shrink(),
)
```

#### 7.2 Performance Optimization

**Tasks**:
- Debounce area calculations during drag (wait 100ms after drag ends)
- Optimize GeoJSON updates (only update changed layers)
- Lazy load handles (only create when rectangle is placed)
- Cache area calculations for unchanged rectangles

**Example Debouncing**:

```dart
Timer? _areaCalculationTimer;

Future<void> updateCorner(int cornerIndex, Position newPosition) async {
  // Update coordinates immediately for visual feedback
  _rectangle = _rectangle!.copyWith(/* new coords */);
  await _syncGeoJson();
  
  // Debounce area calculation
  _areaCalculationTimer?.cancel();
  _areaCalculationTimer = Timer(Duration(milliseconds: 100), () {
    _recalculateArea();
  });
}
```

#### 7.3 Error Handling

**Tasks**:
- Handle network errors when saving
- Show user-friendly error messages
- Retry logic for failed saves
- Validate rectangle geometry before saving

#### 7.4 Testing Checklist

**Manual Testing**:
- [ ] Draw rectangle on map at various zoom levels
- [ ] Save rectangle and reload map (verify persistence)
- [ ] Edit rectangle (resize/move) and save
- [ ] Delete rectangle
- [ ] Test with slow network connection
- [ ] Test on physical Android device
- [ ] Test on physical iOS device
- [ ] Test with multiple rectangles

**Edge Cases**:
- [ ] Very small rectangles (< 0.01 acres)
- [ ] Very large rectangles (> 100 acres)
- [ ] Rectangles crossing date line (180° longitude)
- [ ] Rectangles at poles (near 90° latitude)
- [ ] Rapid tap/drag interactions
- [ ] Save while rectangle is being dragged

---

## 🛠️ Mapbox Flutter SDK 2.17.0 Best Practices

### Verified APIs (Working in Current Codebase)

1. **Map Widget Initialization**
   ```dart
   MapWidget(
     onMapCreated: (MapboxMap map) { },
     onStyleLoadedListener: (StyleLoadedEventData data) { },
     onTapListener: (MapContentGestureContext context) { },
     onCameraChangeListener: (CameraChangedEventData data) { },
   )
   ```

2. **GeoJSON Source Management**
   ```dart
   // Add source
   await style.addSource(GeoJsonSource(id: 'id', data: jsonString));
   
   // Update source
   await style.setStyleSourceProperty('id', 'data', jsonString);
   
   // Remove source
   await style.removeStyleSource('id');
   ```

3. **Layer Management**
   ```dart
   // Add fill layer
   await style.addLayer(FillLayer(
     id: 'layer-id',
     sourceId: 'source-id',
     fillColor: colorValue, // int value, not Color object
     fillOpacity: 0.3,
   ));
   
   // Add line layer
   await style.addLayer(LineLayer(
     id: 'line-id',
     sourceId: 'source-id',
     lineColor: colorValue,
     lineWidth: 2.0,
   ));
   ```

4. **Point Annotations (for handles)**
   ```dart
   final manager = mapboxMap.annotations.createPointAnnotationManager();
   
   final annotation = PointAnnotation(
     id: 'handle-1',
     geometry: Point(coordinates: Position(lng, lat)),
     image: imageBytes,
     draggable: true,
   );
   
   await manager.create(annotation);
   
   // Listen for drag events
   manager.addOnPointAnnotationDragEndListener((annotation, screenCoord) {
     // Handle drag end
   });
   ```

### Common Pitfalls to Avoid

1. **Color Values**: Always use `.value` for Color → int conversion
   ```dart
   // ✅ Correct
   fillColor: AppTheme.primaryColor.value
   
   // ❌ Wrong
   fillColor: AppTheme.primaryColor
   ```

2. **Async Operations**: Always await style operations
   ```dart
   // ✅ Correct
   await style.addSource(...);
   await style.addLayer(...);
   
   // ❌ Wrong (race conditions)
   style.addSource(...);
   style.addLayer(...);
   ```

3. **Error Handling**: Wrap style operations in try-catch
   ```dart
   try {
     await style.addLayer(layer);
   } catch (e) {
     // Layer might already exist, ignore
     debugPrint('Layer add skipped: $e');
   }
   ```

4. **Coordinate Format**: Always use [lng, lat] (longitude first!)
   ```dart
   // ✅ Correct
   Position(lng: -122.4, lat: 37.8)
   
   // ❌ Wrong
   Position(lat: 37.8, lng: -122.4)
   ```

---

## 📚 Reference

- **Mapbox Flutter SDK Docs**: https://docs.mapbox.com/flutter/maps/
- **MongoDB Geospatial Queries**: https://docs.mongodb.com/manual/geospatial-queries/
- **Backend API**: See `backend/src/routes/polygon.routes.ts`
- **Frontend Service**: See `lib/services/land_service.dart`
- See `RECTANGLE_DRAWING_IMPLEMENTATION_PLAN.md` for complete detailed implementation plan

