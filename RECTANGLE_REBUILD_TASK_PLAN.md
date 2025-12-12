# Rectangle Drawing System Rebuild - Complete Task Plan

## Overview
Complete rebuild of rectangle drawing system for Mapbox Flutter SDK v2.12.0 with clean architecture, uniform scaling, rotation, 1-acre minimum validation, and MongoDB persistence.

---

## Task 1: CLEANUP & RESET

### 1.1 Remove from `world_map_page.dart`:
- All rectangle-related state variables (lines 36-52)
- `_onMapTap` rectangle logic (lines 412-503)
- `_onScroll` rectangle-specific logic (lines 505-512)
- `_onPanStart`, `_onPanUpdate`, `_onPanEnd` (lines 514-598)
- `_onDragEndFallback` (lines 590-597)
- Resize mode state management (lines 37-44, 660-699)
- Gesture disable/enable methods (lines 704-738)
- Old rectangle controller initialization (lines 227-245)
- Save/load polygon methods (lines 850-903, 740-847)

### 1.2 Keep in `world_map_page.dart`:
- Map widget setup
- Camera change listener (zoom tracking only)
- Style loading (fog/halo removal)
- Search bar functionality
- Draw button UI component
- Rectangle controls UI component

---

## Task 2: NEW ARCHITECTURE STRUCTURE

### Directory Structure:
```
lib/screens/map/rectangle_drawing/
├── rectangle_model.dart          # Center-based rectangle model
├── rectangle_controller.dart     # Core business logic
├── rectangle_renderer.dart       # Mapbox layer management
└── rectangle_gestures.dart       # Handle interaction logic
```

---

## Task 3: RECTANGLE MODEL (`rectangle_model.dart`)

### Requirements:
- Store center point (LatLng)
- Store width and height (meters)
- Store rotation angle (degrees, 0-360)
- Store area (square meters)
- Store area increase history
- Convert to/from MongoDB format
- Compute 4 corners from center + dimensions + rotation
- Validate minimum area (1 acre = 4046.86 m²)

### Key Methods:
```dart
// Creation
RectangleModel.fromCenter({
  required Position center,
  required double widthMeters,
  required double heightMeters,
  double rotationDegrees = 0.0,
})

// MongoDB
RectangleModel.fromMongoData(Map<String, dynamic> data)
Map<String, dynamic> toMongoData()

// Geometry
List<Position> computeCorners()  // 4 corners based on center/dims/rotation
double calculateArea()           // width * height in meters, convert to m²
bool isValidArea()               // >= 4046.86 m²

// Area tracking
void recordAreaIncrease(double delta)
List<AreaIncreaseEvent> get areaHistory
```

### Area History Event Model:
```dart
class AreaIncreaseEvent {
  final DateTime timestamp;
  final double deltaMetersSquared;
  final double previousArea;
  final double newArea;
}
```

---

## Task 4: RECTANGLE CONTROLLER (`rectangle_controller.dart`)

### Responsibilities:
- Rectangle lifecycle (create, update, delete)
- Uniform scaling logic
- Rotation logic
- Area validation
- Area tracking
- Coordinate system conversions (meters ↔ degrees)

### Key Methods:
```dart
// Initialization
Future<void> init(MapboxMap mapboxMap)

// Creation
Future<void> createAtCenter(Position center)
  // Creates default 20×20m rectangle

// Scaling (UNIFORM ONLY)
Future<void> startUniformScale(int handleIndex)
Future<void> updateUniformScale(Position dragPosition)
Future<void> endUniformScale()
  // Must maintain width/height ratio
  // Scale both dimensions equally
  // Validate minimum area after scale

// Rotation
Future<void> startRotation()
Future<void> updateRotation(Position dragPosition)
Future<void> endRotation()
  // Compute angle from center to drag position
  // Normalize to 0-360 degrees
  // Recompute all corners

// Validation
bool _validateArea(double areaMetersSquared)  // >= 4046.86
void _rollbackToLastValid()                   // Revert on validation failure

// Area Tracking
void _trackAreaChange(double oldArea, double newArea)
  // Only log increases
  // Append to history
  // Emit event to UI
```

### Internal State:
- `RectangleModel? _currentRectangle`
- `RectangleModel? _lastValidRectangle`  // For rollback
- `double _previousArea`
- `HandleDragState? _activeDragState`

---

## Task 5: RECTANGLE RENDERER (`rectangle_renderer.dart`)

### Responsibilities:
- Mapbox GeoJSON source management
- Layer creation (fill, line, handles)
- Handle rendering (4 side handles + 1 rotation handle)
- Selection highlighting
- Single source updates (performance)

### Layer IDs:
```dart
static const String _sourceId = 'rectangle-geojson-source';
static const String _fillLayerId = 'rectangle-fill-layer';
static const String _lineLayerId = 'rectangle-line-layer';
static const String _handleSourceId = 'rectangle-handle-source';
static const String _handleLayerId = 'rectangle-handle-layer';
static const String _rotationHandleSourceId = 'rectangle-rotation-handle-source';
static const String _rotationHandleLayerId = 'rectangle-rotation-handle-layer';
```

### Key Methods:
```dart
// Initialization
Future<void> initialize(StyleManager style)

// Updates (ONLY update source data, NOT layers)
Future<void> updateRectangle(RectangleModel? rectangle)
Future<void> updateHandles(RectangleModel? rectangle, bool visible)
Future<void> updateRotationHandle(RectangleModel? rectangle, bool visible)

// Selection
Future<void> setSelected(bool selected)

// Cleanup
Future<void> dispose()
```

### Handle Positions:
- Side handles: Midpoints of each edge (4 handles)
- Rotation handle: Position slightly above top edge (for rotation)

---

## Task 6: RECTANGLE GESTURES (`rectangle_gestures.dart`)

### Responsibilities:
- Handle hit testing (pixel-perfect)
- Drag state management
- Gesture type detection (scale vs rotate)
- Mapbox gesture control

### Handle Types:
```dart
enum HandleType {
  sideTop,      // Index 0
  sideRight,    // Index 1
  sideBottom,   // Index 2
  sideLeft,     // Index 3
  rotation,     // Index 4 (special)
}
```

### Key Methods:
```dart
// Hit Testing
Future<HandleType?> hitTestHandle(
  Position tapPosition,
  RectangleModel rectangle,
  MapboxMap mapboxMap,
) async
  // Convert tap to pixel coordinates
  // Check each handle with 15px radius
  // Return handle type or null

// Gesture Control
Future<void> disableMapGestures(MapboxMap mapboxMap)
Future<void> restoreMapGestures(MapboxMap mapboxMap)
  // During drag: scrollEnabled=true (for events), scrollMode=NONE
  // During drag: rotateEnabled=false, pitchEnabled=false
  // After drag: restore all settings
```

---

## Task 7: RECTANGLE CREATION FLOW

### Flow:
1. User taps "Draw Rectangle" button
2. Controller enters placement mode
3. User taps map → tap becomes rectangle center
4. Create default rectangle (20×20m, 0° rotation)
5. Render rectangle + handles on map
6. Exit placement mode

### Implementation:
```dart
// In controller
void enterPlacementMode() { _placementMode = true; }

Future<void> createAtCenter(Position center) async {
  final defaultWidth = 20.0;  // meters
  final defaultHeight = 20.0; // meters
  
  _currentRectangle = RectangleModel.fromCenter(
    center: center,
    widthMeters: defaultWidth,
    heightMeters: defaultHeight,
    rotationDegrees: 0.0,
  );
  
  _lastValidRectangle = _currentRectangle;
  _previousArea = _currentRectangle.area;
  
  await _renderer.updateRectangle(_currentRectangle);
  await _renderer.updateHandles(_currentRectangle, true);
  await _renderer.updateRotationHandle(_currentRectangle, true);
  
  _placementMode = false;
}
```

---

## Task 8: UNIFORM SCALING RULE

### Rules:
- Must preserve rectangle shape (width/height ratio constant)
- All handles scale uniformly (both width and height change by same factor)
- Compute scale factor from drag distance in meters
- Apply scale to both width and height
- Recompute corners based on center + new dimensions + rotation

### Implementation:
```dart
Future<void> updateUniformScale(Position dragPosition) async {
  if (_currentRectangle == null || _dragState == null) return;
  
  // Get drag distance in meters from center
  final center = _currentRectangle.center;
  final dragDistanceMeters = _calculateDistanceMeters(center, dragPosition);
  
  // Original dimensions
  final originalWidth = _currentRectangle.widthMeters;
  final originalHeight = _currentRectangle.heightMeters;
  final originalDistance = sqrt(
    pow(originalWidth / 2, 2) + pow(originalHeight / 2, 2)
  );
  
  // Compute scale factor (preserve ratio)
  final scaleFactor = dragDistanceMeters / originalDistance;
  
  // Apply uniform scale
  final newWidth = originalWidth * scaleFactor;
  final newHeight = originalHeight * scaleFactor;
  
  // Create updated rectangle
  final updated = _currentRectangle!.copyWith(
    widthMeters: newWidth,
    heightMeters: newHeight,
  );
  
  // Validate area
  if (!updated.isValidArea()) {
    // Show warning, revert
    _showAreaWarning();
    return;
  }
  
  // Track area increase
  _trackAreaChange(_currentRectangle!.area, updated.area);
  
  // Update
  _currentRectangle = updated;
  await _renderer.updateRectangle(_currentRectangle);
}
```

---

## Task 9: MINIMUM AREA VALIDATION

### Constants:
```dart
static const double MINIMUM_AREA_METERS_SQUARED = 4046.86; // 1 acre
```

### Validation Points:
1. After each resize operation
2. After rotation (if it somehow affects area computation)
3. Before saving to MongoDB

### Implementation:
```dart
bool _validateArea(double areaMetersSquared) {
  return areaMetersSquared >= MINIMUM_AREA_METERS_SQUARED;
}

Future<void> _validateAndUpdate(RectangleModel updated) async {
  if (!updated.isValidArea()) {
    // Revert to last valid
    if (_lastValidRectangle != null) {
      _currentRectangle = _lastValidRectangle;
      await _renderer.updateRectangle(_currentRectangle);
    }
    
    // Show UI warning
    _onValidationFailed?.call();
    return;
  }
  
  // Valid - update
  _lastValidRectangle = _currentRectangle;
  _currentRectangle = updated;
  await _renderer.updateRectangle(_currentRectangle);
}

// UI callback for warnings
Function()? _onValidationFailed;
void setValidationFailedCallback(Function() callback) {
  _onValidationFailed = callback;
}
```

### UI Warning (in world_map_page.dart):
```dart
void _showAreaWarning() {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Rectangle must be at least 1 acre (4046.86 m²)'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 2),
    ),
  );
}
```

---

## Task 10: AREA INCREASE LOGGING

### Area History Model:
```dart
class AreaIncreaseEvent {
  final DateTime timestamp;
  final double deltaMetersSquared;
  final double previousArea;
  final double newArea;
  
  AreaIncreaseEvent({
    required this.timestamp,
    required this.deltaMetersSquared,
    required this.previousArea,
    required this.newArea,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'deltaMetersSquared': deltaMetersSquared,
    'previousArea': previousArea,
    'newArea': newArea,
  };
}
```

### Tracking Logic:
```dart
void _trackAreaChange(double oldArea, double newArea) {
  if (newArea > oldArea) {
    final delta = newArea - oldArea;
    final event = AreaIncreaseEvent(
      timestamp: DateTime.now(),
      deltaMetersSquared: delta,
      previousArea: oldArea,
      newArea: newArea,
    );
    
    _currentRectangle?.recordAreaIncrease(event);
    _onAreaIncreased?.call(event);
  }
  
  _previousArea = newArea;
}

// UI callback
Function(AreaIncreaseEvent)? _onAreaIncreased;
void setAreaIncreasedCallback(Function(AreaIncreaseEvent) callback) {
  _onAreaIncreased = callback;
}
```

### MongoDB Storage:
Add to Polygon model:
```typescript
areaIncreaseHistory: [{
  timestamp: Date,
  deltaMetersSquared: Number,
  previousArea: Number,
  newArea: Number,
}]
```

---

## Task 11: ROTATION IMPLEMENTATION

### Rotation Handle Position:
- Positioned slightly outside the top edge of rectangle
- Distance: ~10% of rectangle height above center

### Angle Calculation:
```dart
double _calculateRotationAngle(
  Position center,
  Position dragPosition,
) {
  // Convert to radians
  final dx = dragPosition.lng - center.lng;
  final dy = dragPosition.lat - center.lat;
  
  // Compute angle in radians
  final angleRadians = atan2(dy, dx);
  
  // Convert to degrees
  var angleDegrees = angleRadians * 180 / pi;
  
  // Normalize to 0-360
  if (angleDegrees < 0) angleDegrees += 360;
  
  return angleDegrees;
}
```

### Implementation:
```dart
Future<void> updateRotation(Position dragPosition) async {
  if (_currentRectangle == null) return;
  
  final center = _currentRectangle.center;
  final newAngle = _calculateRotationAngle(center, dragPosition);
  
  // Normalize angle (0-360)
  final normalizedAngle = newAngle % 360;
  
  // Create updated rectangle
  final updated = _currentRectangle!.copyWith(
    rotationDegrees: normalizedAngle,
  );
  
  // Validate (rotation doesn't change area, but check anyway)
  if (!updated.isValidArea()) {
    _showAreaWarning();
    return;
  }
  
  _currentRectangle = updated;
  await _renderer.updateRectangle(_currentRectangle);
  await _renderer.updateRotationHandle(_currentRectangle, true);
}
```

---

## Task 12: MAPBOX GESTURE CONTROL FIXES

### During Resize/Rotate:
```dart
Future<void> disableMapGestures(MapboxMap mapboxMap) async {
  await mapboxMap.gestures.updateSettings(
    GesturesSettings(
      scrollEnabled: true,  // Keep enabled for drag events
      scrollMode: ScrollMode.NONE,  // But disable actual scrolling
      rotateEnabled: false,
      pitchEnabled: false,
      pinchToZoomEnabled: false,
      quickZoomEnabled: false,
      doubleTapToZoomInEnabled: false,
      doubleTouchToZoomOutEnabled: false,
    ),
  );
}
```

### After Resize/Rotate:
```dart
Future<void> restoreMapGestures(MapboxMap mapboxMap) async {
  await mapboxMap.gestures.updateSettings(
    GesturesSettings(
      scrollEnabled: true,
      scrollMode: ScrollMode.HORIZONTAL_AND_VERTICAL,
      rotateEnabled: true,
      pitchEnabled: true,
      pinchToZoomEnabled: true,
      quickZoomEnabled: true,
      doubleTapToZoomInEnabled: true,
      doubleTouchToZoomOutEnabled: true,
    ),
  );
}
```

---

## Task 13: STABLE RENDERING PIPELINE

### Single GeoJSON Source:
- Use ONE source for rectangle polygon
- FillLayer and LineLayer both reference same source
- Only update source data, never rebuild layers

### Handle Rendering:
- Separate source for handles (CircleLayer)
- Separate source for rotation handle (CircleLayer)
- Update source data on drag, layers auto-redraw

### Implementation Pattern:
```dart
// Initialize ONCE
Future<void> initialize(StyleManager style) async {
  // Add sources
  await style.addSource(GeoJsonSource(
    id: _sourceId,
    data: jsonEncode(_emptyFeatureCollection),
  ));
  
  // Add layers ONCE
  await style.addLayer(FillLayer(...));
  await style.addLayer(LineLayer(...));
  await style.addLayer(CircleLayer(...)); // handles
  await style.addLayer(CircleLayer(...)); // rotation handle
}

// Update ONLY source data
Future<void> updateRectangle(RectangleModel? rectangle) async {
  final featureCollection = rectangle == null
      ? _emptyFeatureCollection
      : {
          'type': 'FeatureCollection',
          'features': [rectangle.toGeoJsonFeature()],
        };
  
  await style.setStyleSourceProperty(
    _sourceId,
    'data',
    jsonEncode(featureCollection),
  );
}
```

---

## Task 14: MONGODB SAVE

### Backend Model Update:
```typescript
// backend/src/models/Polygon.model.ts
export interface IPolygon extends Document {
  userId: mongoose.Types.ObjectId;
  name?: string;
  description?: string;
  geometry: {
    type: 'Polygon';
    coordinates: number[][][];
  };
  center: {
    lng: number;
    lat: number;
  };
  widthMeters: number;
  heightMeters: number;
  rotationDegrees: number;
  areaInAcres: number;
  areaInMetersSquared: number;
  areaIncreaseHistory: Array<{
    timestamp: Date;
    deltaMetersSquared: number;
    previousArea: number;
    newArea: number;
  }>;
  createdAt: Date;
  updatedAt: Date;
}
```

### Frontend Save:
```dart
Future<void> saveRectangle(String? name) async {
  if (_currentRectangle == null) return;
  
  final rect = _currentRectangle!;
  
  final result = await LandService.saveRectangle(
    center: {
      'lng': rect.center.lng,
      'lat': rect.center.lat,
    },
    widthMeters: rect.widthMeters,
    heightMeters: rect.heightMeters,
    rotationDegrees: rect.rotationDegrees,
    geometry: rect.toGeoJsonFeature()['geometry'],
    areaInAcres: rect.areaInAcres,
    areaInMetersSquared: rect.area,
    areaIncreaseHistory: rect.areaHistory.map((e) => e.toJson()).toList(),
    name: name,
  );
  
  if (result['success'] == true) {
    // Update with MongoDB ID
    _currentRectangle = rect.copyWith(mongoId: result['rectangle']['id']);
  }
}
```

---

## Task 15: MONGODB LOAD & RESTORE

### Load from MongoDB:
```dart
Future<void> loadFromMongoData(Map<String, dynamic> data) async {
  final rect = RectangleModel.fromMongoData(data);
  
  _currentRectangle = rect;
  _lastValidRectangle = rect;
  _previousArea = rect.area;
  
  await _renderer.updateRectangle(rect);
  await _renderer.updateHandles(rect, false); // Hide until selected
  await _renderer.updateRotationHandle(rect, false);
}
```

### RectangleModel.fromMongoData:
```dart
factory RectangleModel.fromMongoData(Map<String, dynamic> data) {
  // Option 1: Reconstruct from center/width/height/rotation
  if (data.containsKey('center') && 
      data.containsKey('widthMeters') && 
      data.containsKey('heightMeters')) {
    return RectangleModel.fromCenter(
      center: Position(
        data['center']['lng'],
        data['center']['lat'],
      ),
      widthMeters: data['widthMeters'],
      heightMeters: data['heightMeters'],
      rotationDegrees: data['rotationDegrees'] ?? 0.0,
      id: data['id'] ?? data['_id'],
      mongoId: data['id'] ?? data['_id'],
      areaHistory: (data['areaIncreaseHistory'] ?? [])
          .map((e) => AreaIncreaseEvent.fromJson(e))
          .toList(),
    );
  }
  
  // Option 2: Reconstruct from geometry (legacy)
  final geoJson = data['geometry'];
  final coords = (geoJson['coordinates'][0] as List)
      .map((coord) => Position(coord[0], coord[1]))
      .toList();
  
  // Compute center, width, height, rotation from coordinates
  // (This is more complex - prefer storing explicitly)
  ...
}
```

---

## Task 16: EDGE CASE HANDLING

### Prevent Scale < 0:
```dart
final scaleFactor = max(0.01, dragDistanceMeters / originalDistance);
```

### Normalize Rotation (0-360°):
```dart
double normalizeAngle(double angle) {
  angle = angle % 360;
  if (angle < 0) angle += 360;
  return angle;
}
```

### Prevent Off-Map Dragging:
```dart
Position _clampToVisibleBounds(Position position) {
  // Get map bounds (optional - can skip if not critical)
  // For now, rely on user not dragging off screen
  return position;
}
```

### Debounce Updates:
```dart
Timer? _updateDebounceTimer;

Future<void> _debouncedUpdate() async {
  _updateDebounceTimer?.cancel();
  _updateDebounceTimer = Timer(Duration(milliseconds: 16), () async {
    await _renderer.updateRectangle(_currentRectangle);
  });
}
```

---

## Task 17: PERFORMANCE OPTIMIZATIONS

### Update Strategy:
1. During drag: Update model immediately, debounce renderer updates (16ms)
2. After drag: Immediate final update
3. Use single GeoJSON source (no layer rebuilds)
4. Batch handle updates if needed

### Coordinate Conversion Caching:
```dart
final _coordinateCache = <String, Position>{};

Position _cachedPixelToCoordinate(ScreenCoordinate pixel) {
  final key = '${pixel.x}_${pixel.y}';
  if (_coordinateCache.containsKey(key)) {
    return _coordinateCache[key]!;
  }
  // Compute and cache
  ...
}
```

---

## Task 18: INTEGRATION INTO WORLD_MAP_PAGE

### Clean Integration:
```dart
class _WorldMapPageState extends State<WorldMapPage> {
  MapboxMap? mapboxMap;
  RectangleController? _rectangleController;
  
  @override
  void initState() {
    super.initState();
    // ... existing init
  }
  
  Future<void> _onStyleLoaded(StyleLoadedEventData eventData) async {
    // ... existing style loading
    
    // Initialize rectangle controller
    if (_rectangleController == null) {
      _rectangleController = RectangleController();
      await _rectangleController!.init(mapboxMap!);
      
      // Set callbacks
      _rectangleController!.setValidationFailedCallback(() {
        _showAreaWarning();
      });
      
      _rectangleController!.setAreaIncreasedCallback((event) {
        debugPrint('Area increased by ${event.deltaMetersSquared} m²');
      });
    }
  }
  
  void _onMapTap(MapContentGestureContext ctx) async {
    if (_rectangleController == null) return;
    
    final tap = ctx.point.coordinates;
    
    // Handle rectangle creation/selection
    await _rectangleController!.handleMapTap(tap);
    
    if (mounted) setState(() {});
  }
  
  void onDrawButtonPressed() {
    _rectangleController?.enterPlacementMode();
    if (mounted) setState(() {});
  }
  
  Future<void> saveCurrentRectangle() async {
    await _rectangleController?.saveRectangle();
  }
  
  @override
  void dispose() {
    _rectangleController?.dispose();
    super.dispose();
  }
}
```

---

## Implementation Order:

1. **Task 3**: Create new `rectangle_model.dart` (center-based)
2. **Task 5**: Create `rectangle_renderer.dart` (rendering logic)
3. **Task 6**: Create `rectangle_gestures.dart` (hit testing, gesture control)
4. **Task 4**: Create `rectangle_controller.dart` (core logic)
5. **Task 8**: Implement uniform scaling
6. **Task 9**: Implement area validation
7. **Task 10**: Implement area tracking
8. **Task 11**: Implement rotation
9. **Task 12**: Fix gesture control
10. **Task 13**: Optimize rendering
11. **Task 14**: Update MongoDB save
12. **Task 15**: Implement MongoDB load
13. **Task 16**: Handle edge cases
14. **Task 17**: Performance optimizations
15. **Task 1**: Cleanup old code
16. **Task 18**: Integrate into world_map_page

---

## Testing Checklist:

- [ ] Rectangle creation at tap location
- [ ] Uniform scaling from all handles
- [ ] Rotation from rotation handle
- [ ] 1-acre minimum validation (reject smaller, show warning)
- [ ] Area increase logging (only increases, not decreases)
- [ ] MongoDB save (all fields including history)
- [ ] MongoDB load (reconstruct rectangle correctly)
- [ ] Gesture control (map doesn't move during resize/rotate)
- [ ] Handle visibility (show/hide on selection)
- [ ] Performance (smooth 60fps dragging)
- [ ] Edge cases (scale < 0, rotation > 360°, off-map)

