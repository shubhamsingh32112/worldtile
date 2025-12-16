import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_model_new.dart';

/// Handle types for rectangle manipulation
enum HandleType {
  sideTop,      // Index 0
  sideRight,    // Index 1
  sideBottom,   // Index 2
  sideLeft,     // Index 3
  rotation,     // Index 4 (special)
}

/// Manages gesture interactions for rectangles
class RectangleGestures {
  static const double _hitTestRadius = 15.0; // pixels

  /// Hit test for handles - returns handle type if tapped, null otherwise
  static Future<HandleType?> hitTestHandle(
    Position tapPosition,
    RectangleModel rectangle,
    MapboxMap mapboxMap,
  ) async {
    try {
      // Convert tap to pixel coordinates
      final tapPixel = await mapboxMap.pixelForCoordinate(
        Point(coordinates: tapPosition),
      );

      // Check side handles (midpoints of edges)
      final corners = rectangle.corners;
      final sideHandles = [
        // Top
        Position(
          (corners[2].lng + corners[3].lng) / 2,
          (corners[2].lat + corners[3].lat) / 2,
        ),
        // Right
        Position(
          (corners[1].lng + corners[2].lng) / 2,
          (corners[1].lat + corners[2].lat) / 2,
        ),
        // Bottom
        Position(
          (corners[0].lng + corners[1].lng) / 2,
          (corners[0].lat + corners[1].lat) / 2,
        ),
        // Left
        Position(
          (corners[3].lng + corners[0].lng) / 2,
          (corners[3].lat + corners[0].lat) / 2,
        ),
      ];

      // Check each side handle
      for (int i = 0; i < sideHandles.length; i++) {
        final handlePixel = await mapboxMap.pixelForCoordinate(
          Point(coordinates: sideHandles[i]),
        );

        final dx = tapPixel.x - handlePixel.x;
        final dy = tapPixel.y - handlePixel.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < _hitTestRadius) {
          return HandleType.values[i];
        }
      }

      // Check rotation handle (above top edge)
      final topMidpoint = sideHandles[0];
      final offsetMeters = rectangle.heightMeters * 0.15;
      final rotationHandle = Position(
        topMidpoint.lng,
        topMidpoint.lat + (offsetMeters / 111320.0),
      );

      final rotationHandlePixel = await mapboxMap.pixelForCoordinate(
        Point(coordinates: rotationHandle),
      );

      final dx = tapPixel.x - rotationHandlePixel.x;
      final dy = tapPixel.y - rotationHandlePixel.y;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance < _hitTestRadius) {
        return HandleType.rotation;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Hit test error: $e');
      return null;
    }
  }

  /// Disable map gestures during drag (disable scrolling to prevent map movement)
  static Future<void> disableMapGestures(MapboxMap mapboxMap) async {
    try {
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          scrollEnabled: false,  // Disable scrolling to prevent map movement
          scrollMode: ScrollMode.HORIZONTAL_AND_VERTICAL,
          rotateEnabled: false,
          pitchEnabled: false,
          pinchToZoomEnabled: false,
          quickZoomEnabled: false,
          doubleTapToZoomInEnabled: false,
          doubleTouchToZoomOutEnabled: false,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to disable map gestures: $e');
    }
  }

  /// Restore map gestures after drag
  static Future<void> restoreMapGestures(MapboxMap mapboxMap) async {
    try {
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
    } catch (e) {
      debugPrint('⚠️ Failed to restore map gestures: $e');
    }
  }
}

