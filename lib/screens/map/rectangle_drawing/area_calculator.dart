import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbox;

class AreaCalculator {
  AreaCalculator._();

  /// Converts lat/lng degrees to meters using Web Mercator approximation.
  static Point _toMeters(double lng, double lat) {
    const earthRadius = 6378137.0; // meters
    final x = earthRadius * lng * pi / 180.0;
    final y = earthRadius * log(tan((lat * pi / 180.0) / 2 + pi / 4));
    return Point(x, y);
  }

  /// Calculates area of ANY polygon using the shoelace formula.
  static double calculateAreaInSquareMeters(List<mbox.Position> closed) {
    if (closed.length < 3) return 0;

    final meters = closed
        .map((p) => _toMeters(p.lng.toDouble(), p.lat.toDouble()))
        .toList(growable: false);

    double sum = 0;
    for (int i = 0; i < meters.length; i++) {
      final p1 = meters[i];
      final p2 = meters[(i + 1) % meters.length];
      sum += p1.x * p2.y - p2.x * p1.y;
    }

    return (sum.abs() / 2.0);
  }

  static double squareMetersToAcres(double m2) => m2 * 0.000247105;

  static double calculateAreaInAcres(List<mbox.Position> coords) {
    return squareMetersToAcres(calculateAreaInSquareMeters(coords));
  }

  static String formatArea(double acres) {
    if (acres < 0.01) return '${(acres * 43560).toStringAsFixed(0)} sq ft';
    if (acres < 1) return '${acres.toStringAsFixed(3)} acres';
    return '${acres.toStringAsFixed(2)} acres';
  }

  /// Clean MongoDB GeoJSON output
  static Map<String, dynamic> toMongoGeoJson(List<mbox.Position> closed) {
    final coords = closed
        .map((p) => [p.lng.toDouble(), p.lat.toDouble()])
        .toList(growable: false);

    return {
      "type": "Polygon",
      "coordinates": [coords],
    };
  }
}

/// Simple math point
class Point {
  final double x;
  final double y;
  const Point(this.x, this.y);
}
