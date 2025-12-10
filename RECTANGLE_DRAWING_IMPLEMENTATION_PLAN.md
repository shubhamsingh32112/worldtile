# Rectangle Drawing Feature - Implementation Plan

## 📋 Overview

This document provides a detailed implementation plan for adding rectangle drawing functionality to the WorldTile Flutter application. The feature allows users to draw, resize, move, and delete rectangles on the map with real-time area calculations.

## 🔍 Codebase Analysis

### Current Setup
- **Frontend**: Flutter app (`frontend_app/`)
- **Backend**: Node.js/Express with TypeScript (`backend/`)
- **Map SDK**: `mapbox_maps_flutter: ^2.17.0`
- **Flutter SDK**: `>=3.0.0 <4.0.0`
- **Dart SDK**: `>=3.7.0 <4.0.0`

### Key Files
- **Map Page**: `lib/screens/map/world_map_page.dart`
- **Theme**: `lib/theme/app_theme.dart`
- **Land Service**: `lib/services/land_service.dart`

### Available Dependencies
- `mapbox_maps_flutter: ^2.17.0` - Map rendering and annotations
- `turf: ^0.0.10` (transitive) - Geospatial calculations
- `flutter` - UI framework
- `permission_handler: ^11.3.1` - Location permissions

## 🎯 Feature Requirements

### High-Level Flow
1. User zooms in enough (zoom >= 12) → Show floating "Draw Rectangle" button
2. User taps "Draw Rectangle" → Enter placement mode
3. User taps map → Rectangle appears at tap location (default 1 acre)
4. Rectangle rendered with:
   - FillLayer/FillAnnotation for fill
   - LineLayer/LineAnnotation for border
   - 4 corner PointAnnotations as resize handles
   - 1 center PointAnnotation for dragging
   - Area text displayed inside rectangle
5. User drags handles → Rectangle resizes, area recalculates
6. User drags center → Rectangle moves
7. User taps delete button → Rectangle removed

## 📐 Technical Architecture

### Component Structure
```
lib/
├── screens/
│   └── map/
│       ├── world_map_page.dart (modified)
│       └── rectangle_drawing/
│           ├── rectangle_drawing_controller.dart
│           ├── rectangle_model.dart
│           ├── rectangle_widget.dart
│           └── area_calculator.dart
├── widgets/
│   └── map/
│       ├── draw_rectangle_button.dart
│       └── rectangle_controls.dart
└── utils/
    └── geometry_utils.dart
```

## 🔧 Implementation Details

### 1. Rectangle Model (`rectangle_model.dart`)

```dart
class RectangleModel {
  final String id;
  List<Position> coordinates; // 4 corners + closing point (5 total)
  double areaInAcres;
  DateTime createdAt;

  RectangleModel({
    required this.id,
    required this.coordinates,
    required this.areaInAcres,
    required this.createdAt,
  });

  // Convert to GeoJSON Polygon
  Map<String, dynamic> toGeoJson() {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          coordinates.map((pos) => [pos.lon, pos.lat]).toList(),
        ],
      },
      'properties': {
        'id': id,
        'area': areaInAcres,
      },
    };
  }

  // Get center point
  Position getCenter() {
    double sumLat = 0, sumLon = 0;
    for (int i = 0; i < 4; i++) {
      sumLat += coordinates[i].lat;
      sumLon += coordinates[i].lon;
    }
    return Position(sumLon / 4, sumLat / 4);
  }

  // Get corner positions (without closing point)
  List<Position> getCorners() {
    return coordinates.sublist(0, 4);
  }
}
```

### 2. Area Calculator (`area_calculator.dart`)

```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:turf/turf.dart' as turf;

class AreaCalculator {
  /// Calculate area of a rectangle in square meters
  /// Uses Turf.js area calculation
  static double calculateAreaInSquareMeters(List<Position> coordinates) {
    // Convert Position to Turf Point format
    final turfCoordinates = coordinates
        .map((pos) => [pos.lon, pos.lat])
        .toList();
    
    // Create Turf Polygon
    final polygon = turf.Polygon(
      coordinates: [turfCoordinates],
    );
    
    // Calculate area using Turf
    // Note: Turf area returns square meters
    final area = turf.area(polygon);
    return area;
  }

  /// Convert square meters to acres
  static double squareMetersToAcres(double squareMeters) {
    return squareMeters * 0.000247105; // 1 sq meter = 0.000247105 acres
  }

  /// Calculate area in acres
  static double calculateAreaInAcres(List<Position> coordinates) {
    final sqMeters = calculateAreaInSquareMeters(coordinates);
    return squareMetersToAcres(sqMeters);
  }

  /// Format area for display
  static String formatArea(double acres) {
    if (acres < 0.01) {
      return '${(acres * 43560).toStringAsFixed(0)} sq ft';
    } else if (acres < 1) {
      return '${acres.toStringAsFixed(3)} acres';
    } else {
      return '${acres.toStringAsFixed(2)} acres';
    }
  }
}
```

### 3. Geometry Utils (`geometry_utils.dart`)

```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class GeometryUtils {
  /// Create a rectangle centered at a point with default 1 acre size
  /// 1 acre ≈ 63.6149 meters (assuming square)
  /// At equator: 1 degree ≈ 111,320 meters
  /// So 1 acre ≈ 0.000571 degrees
  static List<Position> createDefaultRectangle(Position center) {
    const double acreSizeInDegrees = 0.000571; // Approximate
    const double halfSize = acreSizeInDegrees / 2;

    return [
      Position(center.lon - halfSize, center.lat - halfSize), // Bottom-left
      Position(center.lon + halfSize, center.lat - halfSize), // Bottom-right
      Position(center.lon + halfSize, center.lat + halfSize), // Top-right
      Position(center.lon - halfSize, center.lat + halfSize), // Top-left
      Position(center.lon - halfSize, center.lat - halfSize), // Close polygon
    ];
  }

  /// Update rectangle corner at index
  static List<Position> updateCorner(
    List<Position> coordinates,
    int cornerIndex,
    Position newPosition,
  ) {
    final updated = List<Position>.from(coordinates);
    
    // Update the corner
    updated[cornerIndex] = newPosition;
    
    // Update adjacent corners to maintain rectangle shape
    // This is a simplified approach - for true rectangle, we'd need more complex logic
    // For now, we'll just update the corner and let the user adjust
    
    // Ensure polygon is closed
    updated[4] = updated[0];
    
    return updated;
  }

  /// Move entire rectangle by offset
  static List<Position> moveRectangle(
    List<Position> coordinates,
    double deltaLon,
    double deltaLat,
  ) {
    return coordinates.map((pos) {
      return Position(pos.lon + deltaLon, pos.lat + deltaLat);
    }).toList();
  }
}
```

### 4. Rectangle Drawing Controller (`rectangle_drawing_controller.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../rectangle_model.dart';
import '../area_calculator.dart';
import '../geometry_utils.dart';

class RectangleDrawingController {
  final MapboxMap mapboxMap;
  final StyleManager style;
  
  // Rectangle state
  final Map<String, RectangleModel> _rectangles = {};
  String? _selectedRectangleId;
  bool _isPlacementMode = false;

  // Layer IDs
  static const String _fillSourceId = 'rectangle-fill-source';
  static const String _fillLayerId = 'rectangle-fill-layer';
  static const String _lineSourceId = 'rectangle-line-source';
  static const String _lineLayerId = 'rectangle-line-layer';
  static const String _handleSourceId = 'rectangle-handle-source';
  static const String _handleLayerId = 'rectangle-handle-layer';

  RectangleDrawingController({
    required this.mapboxMap,
    required this.style,
  });

  /// Initialize drawing layers
  Future<void> initialize() async {
    // Create GeoJSON sources for fill, line, and handles
    await _createSources();
    await _createLayers();
  }

  Future<void> _createSources() async {
    // Fill source
    await style.addSource(
      GeoJsonSource(
        id: _fillSourceId,
        data: _createEmptyFeatureCollection(),
      ),
    );

    // Line source
    await style.addSource(
      GeoJsonSource(
        id: _lineSourceId,
        data: _createEmptyFeatureCollection(),
      ),
    );

    // Handle source
    await style.addSource(
      GeoJsonSource(
        id: _handleSourceId,
        data: _createEmptyFeatureCollection(),
      ),
    );
  }

  Future<void> _createLayers() async {
    // Fill layer
    await style.addLayer(
      FillLayer(
        id: _fillLayerId,
        sourceId: _fillSourceId,
        fillColor: const Color.fromRGBO(0, 217, 255, 0.3), // AppTheme.primaryColor with opacity
        fillOutlineColor: const Color.fromRGBO(0, 217, 255, 1.0),
      ),
    );

    // Line layer (border)
    await style.addLayer(
      LineLayer(
        id: _lineLayerId,
        sourceId: _lineSourceId,
        lineColor: const Color.fromRGBO(0, 217, 255, 1.0),
        lineWidth: 2.0,
      ),
    );

    // Handle layer (points for corners and center)
    await style.addLayer(
      CircleLayer(
        id: _handleLayerId,
        sourceId: _handleSourceId,
        circleRadius: 8.0,
        circleColor: const Color.fromRGBO(255, 0, 110, 1.0), // AppTheme.accentColor
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white,
      ),
    );
  }

  String _createEmptyFeatureCollection() {
    return '''
    {
      "type": "FeatureCollection",
      "features": []
    }
    ''';
  }

  /// Enter placement mode
  void enterPlacementMode() {
    _isPlacementMode = true;
  }

  /// Exit placement mode
  void exitPlacementMode() {
    _isPlacementMode = false;
  }

  bool get isPlacementMode => _isPlacementMode;

  /// Handle map tap - place rectangle if in placement mode
  Future<void> onMapTap(Position position) async {
    if (!_isPlacementMode) return;

    // Create default rectangle
    final coordinates = GeometryUtils.createDefaultRectangle(position);
    final area = AreaCalculator.calculateAreaInAcres(coordinates);
    
    final rectangle = RectangleModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      coordinates: coordinates,
      areaInAcres: area,
      createdAt: DateTime.now(),
    );

    _rectangles[rectangle.id] = rectangle;
    _selectedRectangleId = rectangle.id;
    _isPlacementMode = false;

    await _updateLayers();
  }

  /// Handle handle drag - resize rectangle
  Future<void> onHandleDrag(String rectangleId, int handleIndex, Position newPosition) async {
    final rectangle = _rectangles[rectangleId];
    if (rectangle == null) return;

    final updatedCoordinates = GeometryUtils.updateCorner(
      rectangle.coordinates,
      handleIndex,
      newPosition,
    );

    final area = AreaCalculator.calculateAreaInAcres(updatedCoordinates);

    _rectangles[rectangleId] = RectangleModel(
      id: rectangle.id,
      coordinates: updatedCoordinates,
      areaInAcres: area,
      createdAt: rectangle.createdAt,
    );

    await _updateLayers();
  }

  /// Handle center drag - move rectangle
  Future<void> onCenterDrag(String rectangleId, Position newCenter) async {
    final rectangle = _rectangles[rectangleId];
    if (rectangle == null) return;

    final oldCenter = rectangle.getCenter();
    final deltaLon = newCenter.lon - oldCenter.lon;
    final deltaLat = newCenter.lat - oldCenter.lat;

    final updatedCoordinates = GeometryUtils.moveRectangle(
      rectangle.coordinates,
      deltaLon,
      deltaLat,
    );

    // Area doesn't change when moving
    _rectangles[rectangleId] = RectangleModel(
      id: rectangle.id,
      coordinates: updatedCoordinates,
      areaInAcres: rectangle.areaInAcres,
      createdAt: rectangle.createdAt,
    );

    await _updateLayers();
  }

  /// Delete rectangle
  Future<void> deleteRectangle(String rectangleId) async {
    _rectangles.remove(rectangleId);
    if (_selectedRectangleId == rectangleId) {
      _selectedRectangleId = null;
    }
    await _updateLayers();
  }

  /// Update all layers with current rectangle data
  Future<void> _updateLayers() async {
    final fillFeatures = <Map<String, dynamic>>[];
    final lineFeatures = <Map<String, dynamic>>[];
    final handleFeatures = <Map<String, dynamic>>[];

    for (final rectangle in _rectangles.values) {
      // Fill and line features
      final polygon = rectangle.toGeoJson();
      fillFeatures.add(polygon);
      lineFeatures.add(polygon);

      // Handle features (corners + center)
      final corners = rectangle.getCorners();
      for (int i = 0; i < corners.length; i++) {
        handleFeatures.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [corners[i].lon, corners[i].lat],
          },
          'properties': {
            'rectangleId': rectangle.id,
            'handleIndex': i,
            'type': 'corner',
          },
        });
      }

      // Center handle
      final center = rectangle.getCenter();
      handleFeatures.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [center.lon, center.lat],
        },
        'properties': {
          'rectangleId': rectangle.id,
          'handleIndex': -1, // -1 indicates center
          'type': 'center',
        },
      });
    }

    // Update sources
    await style.updateGeoJsonSource(
      _fillSourceId,
      _createFeatureCollection(fillFeatures),
    );
    await style.updateGeoJsonSource(
      _lineSourceId,
      _createFeatureCollection(lineFeatures),
    );
    await style.updateGeoJsonSource(
      _handleSourceId,
      _createFeatureCollection(handleFeatures),
    );
  }

  String _createFeatureCollection(List<Map<String, dynamic>> features) {
    return '''
    {
      "type": "FeatureCollection",
      "features": ${features.map((f) => f.toString()).join(',')}
    }
    ''';
  }

  /// Get rectangle by ID
  RectangleModel? getRectangle(String id) {
    return _rectangles[id];
  }

  /// Get all rectangles
  List<RectangleModel> get allRectangles => _rectangles.values.toList();

  /// Cleanup
  Future<void> dispose() async {
    try {
      await style.removeLayer(_fillLayerId);
      await style.removeLayer(_lineLayerId);
      await style.removeLayer(_handleLayerId);
      await style.removeSource(_fillSourceId);
      await style.removeSource(_lineSourceId);
      await style.removeSource(_handleSourceId);
    } catch (e) {
      debugPrint('Error disposing rectangle drawing: $e');
    }
  }
}
```

### 5. Draw Rectangle Button (`draw_rectangle_button.dart`)

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DrawRectangleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isVisible;

  const DrawRectangleButton({
    super.key,
    required this.onPressed,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      top: 80, // Below search bar
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(
          Icons.crop_free,
          color: AppTheme.backgroundColor,
        ),
      ),
    );
  }
}
```

### 6. Rectangle Controls Widget (`rectangle_controls.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../theme/app_theme.dart';
import '../area_calculator.dart';
import '../rectangle_model.dart';

class RectangleControls extends StatelessWidget {
  final RectangleModel rectangle;
  final VoidCallback onDelete;
  final Position centerPosition;

  const RectangleControls({
    super.key,
    required this.rectangle,
    required this.onDelete,
    required this.centerPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Position will be calculated based on centerPosition
      // This is a simplified version - actual positioning needs screen coordinates
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AreaCalculator.formatArea(rectangle.areaInAcres),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: 16,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 7. Modified World Map Page (`world_map_page.dart`)

Key modifications to add:

```dart
// Add imports
import '../widgets/map/draw_rectangle_button.dart';
import '../screens/map/rectangle_drawing/rectangle_drawing_controller.dart';
import '../screens/map/rectangle_drawing/rectangle_model.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class _WorldMapPageState extends State<WorldMapPage> {
  // ... existing code ...
  
  // Add new state variables
  RectangleDrawingController? _rectangleController;
  bool _showDrawButton = false;
  double _currentZoom = 0.0;
  
  // Modify _onMapCreated
  void _onMapCreated(MapboxMap mapboxMapController) async {
    // ... existing code ...
    
    // Initialize rectangle drawing controller
    if (mapboxMap != null) {
      _rectangleController = RectangleDrawingController(
        mapboxMap: mapboxMap!,
        style: mapboxMap!.style,
      );
      await _rectangleController!.initialize();
      
      // Set up map tap listener
      mapboxMap!.onMapClickListener = _onMapTap;
      
      // Set up camera change listener for zoom
      mapboxMap!.onCameraChangeListener = _onCameraChange;
    }
  }
  
  // Handle map tap
  void _onMapTap(MapTapEventData eventData) async {
    if (_rectangleController?.isPlacementMode ?? false) {
      await _rectangleController!.onMapTap(
        Position(eventData.coordinate.lon, eventData.coordinate.lat),
      );
    }
  }
  
  // Handle camera change (for zoom detection)
  void _onCameraChange(CameraChangedEventData eventData) {
    final zoom = eventData.cameraState.zoom;
    setState(() {
      _currentZoom = zoom;
      _showDrawButton = zoom >= 12.0; // Show button when zoomed in enough
    });
  }
  
  // Handle draw button press
  void _onDrawButtonPressed() {
    setState(() {
      _rectangleController?.enterPlacementMode();
    });
  }
  
  // Modify build method
  @override
  Widget build(BuildContext context) {
    // ... existing code ...
    
    return Stack(
      children: [
        // ... existing map widget ...
        MapWidget(
          // ... existing properties ...
          onMapClickListener: _onMapTap,
        ),
        
        // Search bar overlay
        if (_isMapReady)
          MapSearchBar(
            onPlaceSelected: _onPlaceSelected,
            hintText: 'Search for a place (e.g., rt nagar, Bangalore)',
          ),
        
        // Draw rectangle button
        if (_isMapReady && _showDrawButton)
          DrawRectangleButton(
            onPressed: _onDrawButtonPressed,
            isVisible: _showDrawButton,
          ),
        
        // Loading indicator
        if (!_isMapReady)
          // ... existing loading indicator ...
      ],
    );
  }
  
  @override
  void dispose() {
    _rectangleController?.dispose();
    // ... existing dispose code ...
  }
}
```

## 📦 Dependencies

### Required Packages (Already Available)
- `mapbox_maps_flutter: ^2.17.0` ✅
- `turf: ^0.0.10` (transitive) ✅
- `flutter` ✅

### No Additional Dependencies Needed
All required functionality is available through the existing Mapbox Maps Flutter SDK.

## 🎨 UI/UX Considerations

### Visual Design
- **Rectangle Fill**: Semi-transparent primary color (30% opacity)
- **Rectangle Border**: Solid primary color (2px width)
- **Control Handles**: Accent color circles (8px radius) with white border
- **Area Text**: Displayed in center of rectangle with delete button
- **Draw Button**: Floating action button with rectangle icon

### User Feedback
- Show cursor change when in placement mode
- Highlight selected rectangle
- Animate handle appearance/disappearance
- Show loading state during area calculation

## 🧪 Testing Strategy

### Unit Tests
- `AreaCalculator` - Test area calculations
- `GeometryUtils` - Test rectangle creation and manipulation
- `RectangleModel` - Test data model conversions

### Integration Tests
- Map tap → Rectangle placement
- Handle drag → Rectangle resize
- Center drag → Rectangle move
- Delete button → Rectangle removal
- Zoom level → Button visibility

## 🚀 Implementation Steps

1. **Create directory structure**
   - `lib/screens/map/rectangle_drawing/`
   - `lib/widgets/map/`
   - `lib/utils/`

2. **Implement core models and utilities**
   - `rectangle_model.dart`
   - `area_calculator.dart`
   - `geometry_utils.dart`

3. **Implement drawing controller**
   - `rectangle_drawing_controller.dart`

4. **Create UI widgets**
   - `draw_rectangle_button.dart`
   - `rectangle_controls.dart`

5. **Integrate into world_map_page.dart**
   - Add state management
   - Add event handlers
   - Add UI overlays

6. **Test and refine**
   - Test on physical device
   - Optimize performance
   - Polish UI/UX

## ⚠️ Important Notes

### Mapbox Maps Flutter SDK 2.17.0 API
**IMPORTANT**: The actual API methods may differ. Before implementation, verify:
1. **Map Click Events**: Check if `MapWidget` has `onMapClickListener` or similar property
   - Alternative: Use `GestureDetector` wrapper around `MapWidget`
   - Alternative: Use annotation managers with tap callbacks
2. **Layer Management**: Verify exact API for:
   - `GeoJsonSource` creation and updates
   - `FillLayer`, `LineLayer`, `CircleLayer` creation
   - Source data updates (`updateGeoJsonSource` method)
3. **Camera Changes**: Check for `onCameraChangeListener` or similar
   - Alternative: Use periodic polling of camera state
   - Alternative: Use `MapWidget` callbacks
4. **Annotation Managers**: The SDK may use annotation managers instead of direct layers
   - Check for `PointAnnotationManager`, `FillAnnotationManager`, `LineAnnotationManager`
   - These may have different APIs than layer-based approach

### Recommended Approach
1. **Start with simple implementation** using known APIs from existing code
2. **Test incrementally** - implement one feature at a time
3. **Use GestureDetector** as fallback for map taps if SDK doesn't support it directly
4. **Check SDK examples** in mapbox_maps_flutter package documentation

### Area Calculation
- Uses Turf.js (Dart port) for accurate geospatial calculations
- Accounts for Earth's curvature
- Converts square meters to acres

### Coordinate System
- Mapbox uses [longitude, latitude] format
- Position class: `Position(lon, lat)`

### Performance Considerations
- Limit number of rectangles (suggest max 10)
- Debounce area calculations during drag
- Use efficient layer updates

## 💾 Persistence with Supabase PostgreSQL

### Backend Implementation

#### 1. Rectangle Model (`backend/src/models/Rectangle.model.ts`)

```typescript
import { Sequelize, DataTypes, Model } from 'sequelize';
import { getSequelize } from '../config/postgis';

export interface IRectangle {
  id?: number;
  userId: string; // MongoDB user ID (from auth)
  coordinates: Array<[number, number]>; // [[lon, lat], ...] - 4 corners + closing point
  areaInAcres: number;
  name?: string;
  description?: string;
  geometry: any; // PostGIS POLYGON geometry
  createdAt?: Date;
  updatedAt?: Date;
}

class Rectangle extends Model<IRectangle> implements IRectangle {
  public id!: number;
  public userId!: string;
  public coordinates!: Array<[number, number]>;
  public areaInAcres!: number;
  public name?: string;
  public description?: string;
  public geometry!: any;
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

let isInitialized = false;

export const initializeRectangleModel = (): void => {
  if (isInitialized) {
    return;
  }

  const sequelize = getSequelize();

  Rectangle.init(
    {
      id: {
        type: DataTypes.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.STRING,
        allowNull: false,
        field: 'user_id',
      },
      coordinates: {
        type: DataTypes.JSONB,
        allowNull: false,
      },
      areaInAcres: {
        type: DataTypes.DECIMAL(10, 4),
        allowNull: false,
        field: 'area_in_acres',
      },
      name: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      description: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      geometry: {
        type: DataTypes.GEOMETRY('POLYGON', 4326),
        allowNull: false,
      },
    },
    {
      sequelize,
      modelName: 'Rectangle',
      tableName: 'rectangles',
      timestamps: true,
      indexes: [
        {
          fields: ['user_id'],
        },
        {
          fields: ['geometry'],
          using: 'GIST', // Spatial index for PostGIS
        },
      ],
    }
  );

  isInitialized = true;
};

const ensureInitialized = (): void => {
  if (!isInitialized) {
    try {
      initializeRectangleModel();
    } catch (error: any) {
      throw new Error(
        `Rectangle model not initialized: ${error.message}. Ensure database connection is established.`
      );
    }
  }
};

const RectangleProxy = new Proxy(Rectangle, {
  get(target, prop) {
    ensureInitialized();
    const value = (target as any)[prop];
    return typeof value === 'function' ? value.bind(target) : value;
  },
}) as typeof Rectangle;

export default RectangleProxy;
```

#### 2. Rectangle Routes (`backend/src/routes/rectangle.routes.ts`)

```typescript
import express from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.middleware';
import { getSequelize } from '../config/postgis';
import { QueryTypes } from 'sequelize';
import Rectangle from '../models/Rectangle.model';

const router = express.Router();

// @route   POST /api/rectangles
// @desc    Create a new rectangle
// @access  Private
router.post('/', authenticate, async (req: AuthRequest, res) => {
  try {
    const { coordinates, areaInAcres, name, description } = req.body;
    const userId = req.user!.id;

    if (!coordinates || !Array.isArray(coordinates) || coordinates.length < 4) {
      return res.status(400).json({
        success: false,
        message: 'Invalid coordinates. Must be an array of at least 4 points.',
      });
    }

    if (typeof areaInAcres !== 'number' || areaInAcres <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid area. Must be a positive number.',
      });
    }

    // Ensure polygon is closed (first and last point are the same)
    const closedCoordinates = [...coordinates];
    if (
      closedCoordinates[0][0] !== closedCoordinates[closedCoordinates.length - 1][0] ||
      closedCoordinates[0][1] !== closedCoordinates[closedCoordinates.length - 1][1]
    ) {
      closedCoordinates.push([closedCoordinates[0][0], closedCoordinates[0][1]]);
    }

    // Create PostGIS POLYGON geometry
    const sequelize = getSequelize();
    const polygonWKT = `POLYGON((${closedCoordinates
      .map((coord) => `${coord[0]} ${coord[1]}`)
      .join(', ')}))`;

    const query = `
      INSERT INTO rectangles (user_id, coordinates, area_in_acres, name, description, geometry, created_at, updated_at)
      VALUES (:userId, :coordinates::jsonb, :areaInAcres, :name, :description, ST_GeomFromText(:polygonWKT, 4326), NOW(), NOW())
      RETURNING *
    `;

    const [result] = await sequelize.query(query, {
      replacements: {
        userId,
        coordinates: JSON.stringify(closedCoordinates),
        areaInAcres,
        name: name || null,
        description: description || null,
        polygonWKT,
      },
      type: QueryTypes.SELECT,
    });

    res.status(201).json({
      success: true,
      rectangle: {
        id: (result as any).id,
        userId: (result as any).user_id,
        coordinates: closedCoordinates,
        areaInAcres: parseFloat((result as any).area_in_acres),
        name: (result as any).name,
        description: (result as any).description,
        createdAt: (result as any).created_at,
        updatedAt: (result as any).updated_at,
      },
    });
  } catch (error: any) {
    console.error('Create rectangle error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

// @route   GET /api/rectangles
// @desc    Get user's rectangles
// @access  Private
router.get('/', authenticate, async (req: AuthRequest, res) => {
  try {
    const userId = req.user!.id;

    const rectangles = await Rectangle.findAll({
      where: { userId },
      order: [['createdAt', 'DESC']],
    });

    res.status(200).json({
      success: true,
      count: rectangles.length,
      rectangles: rectangles.map((rect) => ({
        id: rect.id,
        userId: rect.userId,
        coordinates: rect.coordinates,
        areaInAcres: parseFloat(rect.areaInAcres.toString()),
        name: rect.name,
        description: rect.description,
        createdAt: rect.createdAt,
        updatedAt: rect.updatedAt,
      })),
    });
  } catch (error: any) {
    console.error('Get rectangles error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

// @route   PUT /api/rectangles/:id
// @desc    Update a rectangle
// @access  Private
router.put('/:id', authenticate, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const userId = req.user!.id;
    const { coordinates, areaInAcres, name, description } = req.body;

    const rectangle = await Rectangle.findOne({
      where: { id: parseInt(id), userId },
    });

    if (!rectangle) {
      return res.status(404).json({
        success: false,
        message: 'Rectangle not found',
      });
    }

    // Update coordinates if provided
    if (coordinates) {
      if (!Array.isArray(coordinates) || coordinates.length < 4) {
        return res.status(400).json({
          success: false,
          message: 'Invalid coordinates',
        });
      }

      // Ensure polygon is closed
      const closedCoordinates = [...coordinates];
      if (
        closedCoordinates[0][0] !== closedCoordinates[closedCoordinates.length - 1][0] ||
        closedCoordinates[0][1] !== closedCoordinates[closedCoordinates.length - 1][1]
      ) {
        closedCoordinates.push([closedCoordinates[0][0], closedCoordinates[0][1]]);
      }

      // Update PostGIS geometry
      const sequelize = getSequelize();
      const polygonWKT = `POLYGON((${closedCoordinates
        .map((coord) => `${coord[0]} ${coord[1]}`)
        .join(', ')}))`;

      await sequelize.query(
        `UPDATE rectangles SET geometry = ST_GeomFromText(:polygonWKT, 4326) WHERE id = :id`,
        {
          replacements: { polygonWKT, id: parseInt(id) },
        }
      );

      rectangle.coordinates = closedCoordinates;
    }

    // Update other fields
    if (areaInAcres !== undefined) {
      rectangle.areaInAcres = areaInAcres;
    }
    if (name !== undefined) {
      rectangle.name = name;
    }
    if (description !== undefined) {
      rectangle.description = description;
    }

    await rectangle.save();

    res.status(200).json({
      success: true,
      rectangle: {
        id: rectangle.id,
        userId: rectangle.userId,
        coordinates: rectangle.coordinates,
        areaInAcres: parseFloat(rectangle.areaInAcres.toString()),
        name: rectangle.name,
        description: rectangle.description,
        updatedAt: rectangle.updatedAt,
      },
    });
  } catch (error: any) {
    console.error('Update rectangle error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

// @route   DELETE /api/rectangles/:id
// @desc    Delete a rectangle
// @access  Private
router.delete('/:id', authenticate, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const userId = req.user!.id;

    const rectangle = await Rectangle.findOne({
      where: { id: parseInt(id), userId },
    });

    if (!rectangle) {
      return res.status(404).json({
        success: false,
        message: 'Rectangle not found',
      });
    }

    await rectangle.destroy();

    res.status(200).json({
      success: true,
      message: 'Rectangle deleted successfully',
    });
  } catch (error: any) {
    console.error('Delete rectangle error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

export default router;
```

#### 3. Update Server (`backend/src/server.ts`)

Add rectangle routes and model initialization:

```typescript
// Add import
import rectangleRoutes from './routes/rectangle.routes';
import { initializeRectangleModel } from './models/Rectangle.model';

// Add route
app.use('/api/rectangles', rectangleRoutes);

// In startServer function, after initializeLandTileModel:
initializeRectangleModel();
console.log('✅ Rectangle model initialized');
```

### Frontend Implementation

#### 1. Rectangle Service (`lib/services/rectangle_service.dart`)

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class RectangleService {
  // Get base URL (same as LandService)
  static String get baseUrl {
    try {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty && envUrl.trim().isNotEmpty) {
        if (kDebugMode) {
          print('🌐 Using API_BASE_URL from .env: $envUrl');
        }
        return envUrl.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load API_BASE_URL from .env: $e');
      }
    }

    if (kDebugMode) {
      print('⚠️ API_BASE_URL not set in .env, using platform default');
    }

    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  /// Get authentication token
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting auth token: $e');
      }
      return null;
    }
  }

  /// Get headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Save a rectangle
  static Future<Map<String, dynamic>> saveRectangle({
    required List<Position> coordinates,
    required double areaInAcres,
    String? name,
    String? description,
  }) async {
    try {
      // Convert Position to [lon, lat] format
      final coordList = coordinates
          .map((pos) => [pos.lon, pos.lat])
          .toList();

      final response = await http.post(
        Uri.parse('$baseUrl/rectangles'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'coordinates': coordList,
          'areaInAcres': areaInAcres,
          'name': name,
          'description': description,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'rectangle': data['rectangle'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to save rectangle',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Update a rectangle
  static Future<Map<String, dynamic>> updateRectangle({
    required int rectangleId,
    List<Position>? coordinates,
    double? areaInAcres,
    String? name,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (coordinates != null) {
        body['coordinates'] = coordinates
            .map((pos) => [pos.lon, pos.lat])
            .toList();
      }
      if (areaInAcres != null) {
        body['areaInAcres'] = areaInAcres;
      }
      if (name != null) {
        body['name'] = name;
      }
      if (description != null) {
        body['description'] = description;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/rectangles/$rectangleId'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'rectangle': data['rectangle'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update rectangle',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Get user's rectangles
  static Future<Map<String, dynamic>> getRectangles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rectangles'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'rectangles': (data['rectangles'] as List)
              .map((rect) => {
                // Convert coordinates back to Position objects
                final coords = (rect['coordinates'] as List)
                    .map((coord) => Position(
                          coord[0] as double, // lon
                          coord[1] as double, // lat
                        ))
                    .toList();
                return {
                  'id': rect['id'],
                  'userId': rect['userId'],
                  'coordinates': coords,
                  'areaInAcres': rect['areaInAcres'] as double,
                  'name': rect['name'],
                  'description': rect['description'],
                  'createdAt': rect['createdAt'],
                  'updatedAt': rect['updatedAt'],
                };
              })
              .toList(),
          'count': data['count'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch rectangles',
          'rectangles': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'rectangles': [],
        'count': 0,
      };
    }
  }

  /// Delete a rectangle
  static Future<Map<String, dynamic>> deleteRectangle(int rectangleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/rectangles/$rectangleId'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Rectangle deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete rectangle',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}
```

#### 2. Update Rectangle Model (`rectangle_model.dart`)

Add database ID and sync methods:

```dart
class RectangleModel {
  final String id; // Local ID (timestamp-based)
  final int? databaseId; // Database ID from Supabase
  final String? userId; // User ID from database
  List<Position> coordinates;
  double areaInAcres;
  String? name;
  String? description;
  DateTime createdAt;
  DateTime? updatedAt;
  bool isDirty; // Track if needs to be saved

  RectangleModel({
    required this.id,
    this.databaseId,
    this.userId,
    required this.coordinates,
    required this.areaInAcres,
    this.name,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.isDirty = false,
  });

  // Create from database response
  factory RectangleModel.fromDatabase(Map<String, dynamic> data) {
    return RectangleModel(
      id: data['id'].toString(), // Use database ID as local ID
      databaseId: data['id'] as int,
      userId: data['userId'] as String?,
      coordinates: (data['coordinates'] as List)
          .map((coord) => Position(coord[0] as double, coord[1] as double))
          .toList(),
      areaInAcres: data['areaInAcres'] as double,
      name: data['name'] as String?,
      description: data['description'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'] as String)
          : null,
      isDirty: false,
    );
  }

  // ... rest of existing methods ...
}
```

#### 3. Update Rectangle Drawing Controller

Add save/load functionality:

```dart
// Add import
import '../../services/rectangle_service.dart';

class RectangleDrawingController {
  // ... existing code ...

  /// Load rectangles from database
  Future<void> loadRectangles() async {
    final result = await RectangleService.getRectangles();
    
    if (result['success'] == true) {
      final rectangles = (result['rectangles'] as List)
          .map((data) => RectangleModel.fromDatabase(data))
          .toList();

      for (final rect in rectangles) {
        _rectangles[rect.id] = rect;
      }

      await _updateLayers();
    }
  }

  /// Save rectangle to database
  Future<bool> saveRectangle(RectangleModel rectangle) async {
    final result = await RectangleService.saveRectangle(
      coordinates: rectangle.coordinates,
      areaInAcres: rectangle.areaInAcres,
      name: rectangle.name,
      description: rectangle.description,
    );

    if (result['success'] == true) {
      final savedRect = result['rectangle'];
      // Update rectangle with database ID
      _rectangles[rectangle.id] = RectangleModel(
        id: rectangle.id,
        databaseId: savedRect['id'],
        userId: savedRect['userId'],
        coordinates: rectangle.coordinates,
        areaInAcres: rectangle.areaInAcres,
        name: rectangle.name,
        description: rectangle.description,
        createdAt: rectangle.createdAt,
        updatedAt: savedRect['updatedAt'] != null
            ? DateTime.parse(savedRect['updatedAt'])
            : null,
        isDirty: false,
      );
      return true;
    }
    return false;
  }

  /// Update rectangle in database
  Future<bool> updateRectangle(RectangleModel rectangle) async {
    if (rectangle.databaseId == null) {
      // If not saved yet, save it
      return await saveRectangle(rectangle);
    }

    final result = await RectangleService.updateRectangle(
      rectangleId: rectangle.databaseId!,
      coordinates: rectangle.coordinates,
      areaInAcres: rectangle.areaInAcres,
      name: rectangle.name,
      description: rectangle.description,
    );

    if (result['success'] == true) {
      rectangle.isDirty = false;
      return true;
    }
    return false;
  }

  /// Delete rectangle from database
  Future<bool> deleteRectangleFromDatabase(String rectangleId) async {
    final rectangle = _rectangles[rectangleId];
    if (rectangle?.databaseId == null) {
      return true; // Not in database, just remove locally
    }

    final result = await RectangleService.deleteRectangle(rectangle!.databaseId!);
    return result['success'] == true;
  }

  // Modify onMapTap to auto-save
  Future<void> onMapTap(Position position) async {
    // ... existing placement code ...
    
    // Auto-save to database
    await saveRectangle(rectangle);
  }

  // Modify onHandleDrag to auto-update
  Future<void> onHandleDrag(String rectangleId, int handleIndex, Position newPosition) async {
    // ... existing resize code ...
    
    // Auto-update in database
    final rectangle = _rectangles[rectangleId];
    if (rectangle != null) {
      await updateRectangle(rectangle);
    }
  }

  // Modify onCenterDrag to auto-update
  Future<void> onCenterDrag(String rectangleId, Position newCenter) async {
    // ... existing move code ...
    
    // Auto-update in database
    final rectangle = _rectangles[rectangleId];
    if (rectangle != null) {
      await updateRectangle(rectangle);
    }
  }

  // Modify deleteRectangle to delete from database
  Future<void> deleteRectangle(String rectangleId) async {
    await deleteRectangleFromDatabase(rectangleId);
    _rectangles.remove(rectangleId);
    if (_selectedRectangleId == rectangleId) {
      _selectedRectangleId = null;
    }
    await _updateLayers();
  }
}
```

#### 4. Update World Map Page

Load rectangles on map ready:

```dart
void _onMapCreated(MapboxMap mapboxMapController) async {
  // ... existing code ...

  // Initialize rectangle drawing controller
  if (mapboxMap != null) {
    _rectangleController = RectangleDrawingController(
      mapboxMap: mapboxMap!,
      style: mapboxMap!.style,
    );
    await _rectangleController!.initialize();
    
    // Load saved rectangles
    await _rectangleController!.loadRectangles();
    
    // ... rest of existing code ...
  }
}
```

### Database Migration

Create migration SQL for Supabase:

```sql
-- Create rectangles table
CREATE TABLE IF NOT EXISTS rectangles (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  coordinates JSONB NOT NULL,
  area_in_acres DECIMAL(10, 4) NOT NULL,
  name VARCHAR(255),
  description TEXT,
  geometry GEOMETRY(POLYGON, 4326) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_rectangles_user_id ON rectangles(user_id);
CREATE INDEX IF NOT EXISTS idx_rectangles_geometry ON rectangles USING GIST(geometry);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_rectangles_updated_at
  BEFORE UPDATE ON rectangles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

## 🔄 Future Enhancements

1. Rectangle snapping to grid
2. Multi-select rectangles
3. Rectangle properties (name, description) UI
4. Undo/redo functionality
5. Rectangle sharing between users
6. Rectangle search and filtering

## 📚 References

- [Mapbox Maps Flutter SDK Documentation](https://docs.mapbox.com/flutter/maps/)
- [Turf.js Documentation](http://turfjs.org/)
- [GeoJSON Specification](https://geojson.org/)

---

**Last Updated**: 2024
**Version**: 1.0.0

