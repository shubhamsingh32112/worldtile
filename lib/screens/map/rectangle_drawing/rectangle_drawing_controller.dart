import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_model.dart';
import 'package:worldtile_app/theme/app_theme.dart';

/// Controls rectangle drawing lifecycle and Mapbox style updates.
///
/// Responsibilities:
/// - Keep a single RectangleModel in sync with a GeoJSON source.
/// - Manage fill/line layers for rectangle rendering.
/// - Provide APIs for placement and mutation (move/update corner).
class RectangleDrawingController {
  RectangleDrawingController();

  static const String _sourceId = 'rectangle-geojson-source';
  static const String _fillLayerId = 'rectangle-fill-layer';
  static const String _lineLayerId = 'rectangle-line-layer';

  MapboxMap? _mapboxMap;
  RectangleModel? _rectangle;
  bool _initialized = false;
  bool _placementMode = false;

  RectangleModel? get rectangle => _rectangle;
  bool get isPlacementMode => _placementMode;
  bool get isInitialized => _initialized;

  /// Must be called after the map's style is loaded.
  Future<void> init(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _ensureStyleObjects();
    _initialized = true;
  }

  /// Enable placement mode; the next tap should call [placeAt].
  void enterPlacementMode() {
    _placementMode = true;
  }

  /// Place a default-acre rectangle centered at [center].
  Future<void> placeAt(Position center) async {
    _assertInitialized();
    _rectangle = RectangleModel.defaultAt(center);
    _placementMode = false;
    await _syncGeoJson();
  }

  /// Move rectangle by a delta (lon/lat).
  Future<void> move(Position delta) async {
    _assertInitialized();
    if (_rectangle == null) return;
    final movedCoords = _rectangle!.coordinates
        .map((p) => Position(p.lng + delta.lng, p.lat + delta.lat))
        .toList(growable: false);
    _rectangle = _rectangle!.copyWith(coordinates: movedCoords);
    await _syncGeoJson();
  }

  /// Update a specific corner (0-3) to a new position.
  Future<void> updateCorner(int cornerIndex, Position newPosition) async {
    _assertInitialized();
    if (_rectangle == null) return;
    final updated = _rectangle!.copyWith(
      coordinates: _rectangle!.coordinates
          .asMap()
          .entries
          .map((entry) =>
              entry.key == cornerIndex ? newPosition : entry.value)
          .toList(growable: false),
    );
    _rectangle = updated;
    await _syncGeoJson();
  }

  /// Clear the current rectangle (remove from map).
  Future<void> clear() async {
    _assertInitialized();
    _rectangle = null;
    _placementMode = false;
    await _syncGeoJson();
  }

  /// Removes layers and sources. Safe to call multiple times.
  Future<void> dispose() async {
    final style = _mapboxMap?.style;
    if (style == null) return;
    await _removeLayer(style, _fillLayerId);
    await _removeLayer(style, _lineLayerId);
    await _removeSource(style, _sourceId);
    _mapboxMap = null;
    _rectangle = null;
    _initialized = false;
  }

  // --- Internal helpers ---

  void _assertInitialized() {
    if (!_initialized || _mapboxMap == null) {
      throw StateError('RectangleDrawingController.init must be called first.');
    }
  }

  Future<void> _ensureStyleObjects() async {
    final style = _mapboxMap?.style;
    if (style == null) {
      throw StateError('Map style is not available.');
    }
    await _addSourceIfMissing(style);
    await _addFillLayerIfMissing(style);
    await _addLineLayerIfMissing(style);
  }

  Future<void> _addSourceIfMissing(StyleManager style) async {
    try {
      await style.addSource(GeoJsonSource(
        id: _sourceId,
        data: jsonEncode(_emptyFeatureCollection),
      ));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Source $_sourceId add skipped/failed: $e');
      }
    }
  }

Future<void> _addFillLayerIfMissing(StyleManager style) async {
  try {
    await style.addLayer(
      FillLayer(
        id: _fillLayerId,
        sourceId: _sourceId,
        fillColor: AppTheme.primaryColor.value, // MUST be int, not Color
        fillOpacity: 0.3,
      ),
    );
  } catch (e) {
    if (kDebugMode) debugPrint("Fill layer add skipped/failed: $e");
  }
}

Future<void> _addLineLayerIfMissing(StyleManager style) async {
  try {
    await style.addLayer(
      LineLayer(
        id: _lineLayerId,
        sourceId: _sourceId,
        lineColor: AppTheme.primaryColor.value, // int
        lineWidth: 2.0,
      ),
    );
  } catch (e) {
    if (kDebugMode) debugPrint("Line layer add skipped/failed: $e");
  }
}



  Future<void> _removeLayer(StyleManager style, String layerId) async {
    try {
      await style.removeStyleLayer(layerId);
    } catch (_) {
      // Ignore if not present.
    }
  }

  Future<void> _removeSource(StyleManager style, String sourceId) async {
    try {
      await style.removeStyleSource(sourceId);
    } catch (_) {
      // Ignore if not present.
    }
  }

  Future<void> _syncGeoJson() async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    final featureCollection = _rectangle == null
        ? _emptyFeatureCollection
        : {
            'type': 'FeatureCollection',
            'features': [_rectangle!.toGeoJsonFeature()],
          };

    try {
await style.setStyleSourceProperty(
  _sourceId,
  "data",
  jsonEncode(featureCollection),
);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update GeoJSON source: $e');
      }
    }
  }

  Map<String, dynamic> get _emptyFeatureCollection => {
        'type': 'FeatureCollection',
        'features': [],
      };
}

