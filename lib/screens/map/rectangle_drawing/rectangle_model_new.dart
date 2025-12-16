import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/area_calculator.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/area_increase_event.dart';
import 'package:worldtile_app/utils/coordinate_converter.dart';

/// Minimum area required: 1 acre = 4046.86 square meters
const double MINIMUM_AREA_METERS_SQUARED = 4046.86;

/// Center-based rectangle model with width, height, rotation, and area tracking
class RectangleModel {
  final String id;
  final String? mongoId;
  final Position center;
  final double widthMeters;
  final double heightMeters;
  final double rotationDegrees; // 0-360 degrees
  final DateTime createdAt;
  final List<AreaIncreaseEvent> areaIncreaseHistory;

  RectangleModel({
    required this.id,
    this.mongoId,
    required this.center,
    required this.widthMeters,
    required this.heightMeters,
    this.rotationDegrees = 0.0,
    DateTime? createdAt,
    List<AreaIncreaseEvent>? areaIncreaseHistory,
  })  : createdAt = createdAt ?? DateTime.now(),
        areaIncreaseHistory = areaIncreaseHistory ?? [],
        assert(widthMeters > 0, 'Width must be positive'),
        assert(heightMeters > 0, 'Height must be positive'),
        assert(rotationDegrees >= 0 && rotationDegrees < 360,
            'Rotation must be 0-360 degrees');

  /// Create a rectangle from center point with dimensions
  factory RectangleModel.fromCenter({
    required Position center,
    required double widthMeters,
    required double heightMeters,
    double rotationDegrees = 0.0,
    String? id,
    String? mongoId,
    DateTime? createdAt,
    List<AreaIncreaseEvent>? areaIncreaseHistory,
  }) {
    return RectangleModel(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      mongoId: mongoId,
      center: center,
      widthMeters: widthMeters,
      heightMeters: heightMeters,
      rotationDegrees: rotationDegrees % 360.0,
      createdAt: createdAt,
      areaIncreaseHistory: areaIncreaseHistory,
    );
  }

  /// Create default rectangle (20×20 meters) at center
  factory RectangleModel.defaultAt(
    Position center, {
    String? id,
  }) {
    return RectangleModel.fromCenter(
      center: center,
      widthMeters: 20.0,
      heightMeters: 20.0,
      rotationDegrees: 0.0,
      id: id,
    );
  }

  /// Create from MongoDB data
  factory RectangleModel.fromMongoData(Map<String, dynamic> data) {
    final mongoId = (data['id'] ?? data['_id'])?.toString();

    // Try to reconstruct from center/width/height/rotation (preferred)
    if (data.containsKey('center') &&
        data.containsKey('widthMeters') &&
        data.containsKey('heightMeters')) {
      final centerData = data['center'] as Map<String, dynamic>;
      return RectangleModel.fromCenter(
        id: mongoId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        mongoId: mongoId,
        center: Position(
          (centerData['lng'] as num).toDouble(),
          (centerData['lat'] as num).toDouble(),
        ),
        widthMeters: (data['widthMeters'] as num).toDouble(),
        heightMeters: (data['heightMeters'] as num).toDouble(),
        rotationDegrees: (data['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
        createdAt: data['createdAt'] != null
            ? DateTime.parse(data['createdAt'])
            : null,
        areaIncreaseHistory: (data['areaIncreaseHistory'] as List?)
                ?.map((e) => AreaIncreaseEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    }

    // Fallback: Reconstruct from geometry coordinates
    // This is more complex - compute center, width, height from corners
    final geoJson = data['geometry'] as Map<String, dynamic>;
    final coords = (geoJson['coordinates'][0] as List)
        .map((coord) => Position(
              (coord[0] as num).toDouble(),
              (coord[1] as num).toDouble(),
            ))
        .toList();

    // Compute center
    double sumLat = 0, sumLng = 0;
    for (int i = 0; i < 4 && i < coords.length; i++) {
      sumLat += coords[i].lat;
      sumLng += coords[i].lng;
    }
    final computedCenter = Position(sumLng / 4, sumLat / 4);

    // Approximate width/height from first two corners
    final width = CoordinateConverter.distanceInMeters(coords[0], coords[1]);
    final height = CoordinateConverter.distanceInMeters(coords[1], coords[2]);

    return RectangleModel.fromCenter(
      id: mongoId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      mongoId: mongoId,
      center: computedCenter,
      widthMeters: width,
      heightMeters: height,
      rotationDegrees: 0.0, // Can't determine from coordinates easily
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : null,
      areaIncreaseHistory: (data['areaIncreaseHistory'] as List?)
              ?.map((e) => AreaIncreaseEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Compute the 4 corners of the rectangle
  List<Position> computeCorners() {
    // Half dimensions in meters
    final halfWidth = widthMeters / 2.0;
    final halfHeight = heightMeters / 2.0;

    // Corners in local coordinate system (before rotation)
    final cornersLocal = [
      Position(-halfWidth, -halfHeight), // Bottom-left
      Position(halfWidth, -halfHeight),  // Bottom-right
      Position(halfWidth, halfHeight),   // Top-right
      Position(-halfWidth, halfHeight),  // Top-left
    ];

    // Convert to degrees and rotate around center
    final cornersDegrees = cornersLocal.map((local) {
      // Convert local meters to degrees offset
      final latOffset = CoordinateConverter.metersToLatitudeDegrees(local.lat.toDouble());
      final lngOffset = CoordinateConverter.metersToLongitudeDegrees(
          local.lng.toDouble(), center.lat.toDouble());

      // Create unrotated corner
      final unrotated = Position(
        center.lng + lngOffset,
        center.lat + latOffset,
      );

      // Apply rotation if needed
      if (rotationDegrees != 0.0) {
        return CoordinateConverter.rotatePointAroundCenter(
          unrotated,
          center,
          rotationDegrees,
        );
      }

      return unrotated;
    }).toList();

    return cornersDegrees;
  }

  /// Get coordinates as closed polygon (5 points: 4 corners + closing point)
  List<Position> get coordinates {
    final corners = computeCorners();
    return [...corners, corners[0]]; // Close polygon
  }

  /// Get corner positions only (4 corners)
  List<Position> get corners => computeCorners();

  /// Calculate area in square meters (width * height)
  double get area => widthMeters * heightMeters;

  /// Calculate area in acres
  double get areaInAcres => AreaCalculator.squareMetersToAcres(area);

  /// Check if rectangle meets minimum area requirement
  bool get isValidArea => area >= MINIMUM_AREA_METERS_SQUARED;

  /// Record an area increase event
  RectangleModel recordAreaIncrease(AreaIncreaseEvent event) {
    final updatedHistory = [...areaIncreaseHistory, event];
    return copyWith(areaIncreaseHistory: updatedHistory);
  }

  /// Copy with optional updates
  RectangleModel copyWith({
    String? id,
    String? mongoId,
    Position? center,
    double? widthMeters,
    double? heightMeters,
    double? rotationDegrees,
    DateTime? createdAt,
    List<AreaIncreaseEvent>? areaIncreaseHistory,
  }) {
    return RectangleModel(
      id: id ?? this.id,
      mongoId: mongoId ?? this.mongoId,
      center: center ?? this.center,
      widthMeters: widthMeters ?? this.widthMeters,
      heightMeters: heightMeters ?? this.heightMeters,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      createdAt: createdAt ?? this.createdAt,
      areaIncreaseHistory: areaIncreaseHistory ?? this.areaIncreaseHistory,
    );
  }

  /// Check if a point is inside the rectangle
  bool containsPoint(num lng, num lat) {
    final corners = computeCorners();
    final pts = [...corners, corners[0]]; // Closed polygon

    bool inside = false;
    for (int i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      final xi = pts[i].lng;
      final yi = pts[i].lat;
      final xj = pts[j].lng;
      final yj = pts[j].lat;

      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi + 0.00000001) + xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// Convert to GeoJSON feature for Mapbox rendering
  Map<String, dynamic> toGeoJsonFeature() {
    final coords = coordinates;
    final polygon = [
      coords.map((pos) => [pos.lng, pos.lat]).toList(growable: false),
    ];
    return {
      'type': 'Feature',
      'geometry': {'type': 'Polygon', 'coordinates': polygon},
      'properties': {
        'id': id,
        'area_acres': areaInAcres,
        'area_meters_squared': area,
      },
    };
  }

  /// Convert to MongoDB format
  Map<String, dynamic> toMongoData() {
    return {
      'center': {
        'lng': center.lng,
        'lat': center.lat,
      },
      'widthMeters': widthMeters,
      'heightMeters': heightMeters,
      'rotationDegrees': rotationDegrees,
      'geometry': toGeoJsonFeature()['geometry'],
      'areaInAcres': areaInAcres,
      'areaInMetersSquared': area,
      'areaIncreaseHistory': areaIncreaseHistory.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

