import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/area_calculator.dart';
import 'package:worldtile_app/utils/geometry_utils.dart';

/// Data model representing a drawable rectangle on the map.
class RectangleModel {
  final String id; // MongoDB ID when saved, or local ID
  final String? mongoId; // MongoDB _id when saved
  final List<Position> coordinates; // 4 corners + closing point
  final double areaInAcres;
  final DateTime createdAt;

  const RectangleModel({
    required this.id,
    this.mongoId,
    required this.coordinates,
    required this.areaInAcres,
    required this.createdAt,
  });

  /// Creates a rectangle centered on [center] with a default acre size.
  factory RectangleModel.defaultAt(Position center, {String? id}) {
    final coords = GeometryUtils.createDefaultRectangle(center);
    return RectangleModel(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      coordinates: coords,
      areaInAcres: AreaCalculator.calculateAreaInAcres(coords),
      createdAt: DateTime.now(),
    );
  }

  /// Creates a rectangle from the provided corners (will auto-close polygon).
  factory RectangleModel.fromCorners({
    required String id,
    String? mongoId,
    required List<Position> corners,
    DateTime? createdAt,
  }) {
    final closed = GeometryUtils.ensureClosedPolygon(corners);
    return RectangleModel(
      id: id,
      mongoId: mongoId,
      coordinates: closed,
      areaInAcres: AreaCalculator.calculateAreaInAcres(closed),
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Creates a rectangle from MongoDB data
  factory RectangleModel.fromMongoData(Map<String, dynamic> data) {
    final geoJson = data['geometry'] as Map<String, dynamic>;
    final coords = (geoJson['coordinates'][0] as List)
        .map((coord) => Position(coord[0].toDouble(), coord[1].toDouble()))
        .toList();
    
    final mongoId = data['id'] ?? data['_id'];
    return RectangleModel(
      id: mongoId?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      mongoId: mongoId?.toString(),
      coordinates: coords,
      areaInAcres: (data['areaInAcres'] as num).toDouble(),
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  RectangleModel copyWith({
    String? id,
    String? mongoId,
    List<Position>? coordinates,
    double? areaInAcres,
    DateTime? createdAt,
  }) {
    final updatedCoords = coordinates ?? this.coordinates;
    return RectangleModel(
      id: id ?? this.id,
      mongoId: mongoId ?? this.mongoId,
      coordinates: GeometryUtils.ensureClosedPolygon(updatedCoords),
      areaInAcres: areaInAcres ?? AreaCalculator.calculateAreaInAcres(updatedCoords),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// GeoJSON feature representation for map layers.
  Map<String, dynamic> toGeoJsonFeature() {
    final polygon = [
      coordinates.map((pos) => [pos.lng, pos.lat]).toList(growable: false),
    ];
    return {
      'type': 'Feature',
      'geometry': {'type': 'Polygon', 'coordinates': polygon},
      'properties': {
        'id': id,
        'area_acres': areaInAcres,
      },
    };
  }

  /// Rectangle center derived from current coordinates.
  Position get center => GeometryUtils.getCenter(coordinates);

  /// Corner-only list (excludes closing point).
  List<Position> get corners => coordinates.take(4).toList(growable: false);
}

