import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Geometry helpers for rectangle creation and manipulation.
class GeometryUtils {
  GeometryUtils._();

  /// Default rectangle size in degrees for roughly one acre at the equator.
  static const double _acreSizeInDegrees = 0.000571;

  /// Create a closed polygon (5 positions) for a square acre centered on [center].
  static List<Position> createDefaultRectangle(Position center) {
    const halfSize = _acreSizeInDegrees / 2;

    return [
      Position(center.lng - halfSize, center.lat - halfSize), // bottom-left
      Position(center.lng + halfSize, center.lat - halfSize), // bottom-right
      Position(center.lng + halfSize, center.lat + halfSize), // top-right
      Position(center.lng - halfSize, center.lat + halfSize), // top-left
      Position(center.lng - halfSize, center.lat - halfSize), // close polygon
    ];
  }

  /// Ensures a polygon list is closed by repeating the first coordinate at the end.
  static List<Position> ensureClosedPolygon(List<Position> coordinates) {
    if (coordinates.isEmpty) return [];
    final isClosed = coordinates.first.lng == coordinates.last.lng &&
        coordinates.first.lat == coordinates.last.lat;
    return isClosed ? List<Position>.from(coordinates) : [...coordinates, coordinates.first];
  }

  /// Returns the centroid of the first four corners (assumes rectangle ordering).
  static Position getCenter(List<Position> coordinates) {
    if (coordinates.length < 4) {
      throw ArgumentError('Rectangle requires at least 4 coordinates.');
    }
    final firstFour = coordinates.take(4).toList();
    final sumLat = firstFour.fold<double>(0, (sum, p) => sum + p.lat);
    final sumLon = firstFour.fold<double>(0, (sum, p) => sum + p.lng);
    return Position(sumLon / firstFour.length, sumLat / firstFour.length);
  }

  /// Translates all coordinates by [deltaLon] and [deltaLat].
  static List<Position> translate(
    List<Position> coordinates, {
    required double deltaLon,
    required double deltaLat,
  }) {
    return coordinates
        .map((p) => Position(p.lng + deltaLon, p.lat + deltaLat))
        .toList(growable: false);
  }

  /// Updates the corner at [cornerIndex] (0-3) and keeps the polygon closed.
  static List<Position> updateCorner({
    required List<Position> coordinates,
    required int cornerIndex,
    required Position newPosition,
  }) {
    if (cornerIndex < 0 || cornerIndex > 3) {
      throw ArgumentError('cornerIndex must be between 0 and 3');
    }
    if (coordinates.length < 4) {
      throw ArgumentError('Rectangle requires at least 4 coordinates.');
    }

    final updated = List<Position>.from(coordinates);
    updated[cornerIndex] = newPosition;
    final closed = ensureClosedPolygon(updated.take(4).toList());
    return closed;
  }
}

