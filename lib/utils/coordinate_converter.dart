import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Utilities for converting between meters and degrees (latitude/longitude)
class CoordinateConverter {
  CoordinateConverter._();

  /// Earth's radius in meters
  static const double earthRadiusMeters = 6378137.0;

  /// Convert meters to degrees of latitude
  /// This is constant everywhere on Earth
  static double metersToLatitudeDegrees(double meters) {
    return meters / 111320.0; // Approximate: 1 degree latitude ≈ 111,320 meters
  }

  /// Convert meters to degrees of longitude
  /// This varies with latitude (smaller at poles, larger at equator)
  static double metersToLongitudeDegrees(double meters, double latitude) {
    final latRad = latitude * pi / 180.0;
    return meters / (111320.0 * cos(latRad));
  }

  /// Convert degrees of latitude to meters
  static double latitudeDegreesToMeters(double degrees) {
    return degrees * 111320.0;
  }

  /// Convert degrees of longitude to meters
  static double longitudeDegreesToMeters(double degrees, double latitude) {
    final latRad = latitude * pi / 180.0;
    return degrees * 111320.0 * cos(latRad);
  }

  /// Calculate distance in meters between two positions using Haversine formula
  static double distanceInMeters(Position p1, Position p2) {
    final lat1Rad = p1.lat * pi / 180.0;
    final lat2Rad = p2.lat * pi / 180.0;
    final deltaLatRad = (p2.lat - p1.lat) * pi / 180.0;
    final deltaLngRad = (p2.lng - p1.lng) * pi / 180.0;

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Add meters to a position (moving north/east)
  static Position addMetersToPosition(
    Position position,
    double metersNorth,
    double metersEast,
  ) {
    final latDelta = metersToLatitudeDegrees(metersNorth);
    final lngDelta = metersToLongitudeDegrees(metersEast, position.lat.toDouble());

    return Position(
      position.lng + lngDelta,
      position.lat + latDelta,
    );
  }

  /// Rotate a point around a center by angle (in degrees)
  static Position rotatePointAroundCenter(
    Position point,
    Position center,
    double angleDegrees,
  ) {
    final angleRad = angleDegrees * pi / 180.0;

    // Convert to local coordinate system (meters)
    final dxMeters = longitudeDegreesToMeters((point.lng - center.lng).toDouble(), center.lat.toDouble());
    final dyMeters = latitudeDegreesToMeters((point.lat - center.lat).toDouble());

    // Rotate
    final cosAngle = cos(angleRad);
    final sinAngle = sin(angleRad);
    final rotatedXMeters = dxMeters * cosAngle - dyMeters * sinAngle;
    final rotatedYMeters = dxMeters * sinAngle + dyMeters * cosAngle;

    // Convert back to degrees
    final rotatedLng = center.lng + metersToLongitudeDegrees(rotatedXMeters.toDouble(), center.lat.toDouble());
    final rotatedLat = center.lat + metersToLatitudeDegrees(rotatedYMeters.toDouble());

    return Position(rotatedLng, rotatedLat);
  }
}

