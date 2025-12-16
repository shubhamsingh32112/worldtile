import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// WorldMapController provides a singleton controller for camera commands
/// 
/// This allows other parts of the app to send camera commands to the persistent
/// WorldMapPage without navigating or recreating the map.
/// 
/// Usage:
/// ```dart
/// WorldMapController.instance.zoomToIndia();
/// ```
class WorldMapController {
  /// Singleton instance
  static final WorldMapController instance = WorldMapController._();

  WorldMapController._();

  /// The bound MapboxMap instance (set by WorldMapPage)
  MapboxMap? _map;

  /// Binds the controller to a MapboxMap instance
  /// This should be called from WorldMapPage._onMapCreated
  void bind(MapboxMap map) {
    _map = map;
    debugPrint('🗺️ WorldMapController bound to map instance');
  }

  /// Unbinds the controller (called when map is disposed)
  void unbind() {
    _map = null;
    debugPrint('🗺️ WorldMapController unbound');
  }

  /// Zooms the map to India
  /// Coordinates: (77.0, 23.5) - approximate center of India
  /// Zoom level: 3.75 - shows India clearly
  Future<void> zoomToIndia() async {
    if (_map == null) {
      debugPrint('⚠️ WorldMapController: Map not bound, cannot zoom to India');
      return;
    }

    try {
      await _map!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(77.0, 23.5), // India center
          ),
          zoom: 3.75,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 1800),
      );
      debugPrint('✅ WorldMapController: Zoomed to India');
    } catch (e) {
      debugPrint('❌ WorldMapController: Error zooming to India: $e');
    }
  }

  /// Checks if the map is currently bound
  bool get isBound => _map != null;
}

