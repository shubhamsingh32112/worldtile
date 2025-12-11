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
// ---- Corner handle IDs ----
  static const String _handleSourceId = "rectangle-handle-source";
  static const String _handleLayerId = "rectangle-handle-layer";
  int? _draggingCornerIndex; // null = not dragging

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
          .map((entry) => entry.key == cornerIndex ? newPosition : entry.value)
          .toList(growable: false),
    );
    _rectangle = updated;
    await _syncGeoJson();
  }

  /// Start dragging a specific corner
  void startCornerDrag(int cornerIndex) {
    _draggingCornerIndex = cornerIndex;
  }

  /// Update dragging corner with new map position (preserve rectangle shape)
  Future<void> updateCornerDrag(Position newPos) async {
    if (_draggingCornerIndex == null || _rectangle == null) return;
    await _resizeFromCorner(_draggingCornerIndex!, newPos);
  }

  /// Stop dragging
  void endCornerDrag() {
    _draggingCornerIndex = null;
  }

  /// Highlight rectangle when selected (true) or reset (false)
  Future<void> updateSelectionHighlight(bool isSelected) async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    try {
      // Update FILL COLOR + OPACITY
      await style.setStyleLayerProperty(
        _fillLayerId,
        "fill-color",
        isSelected ? "#FFD54F" : "#00FFAA", // gold / original
      );

      await style.setStyleLayerProperty(
        _fillLayerId,
        "fill-opacity",
        isSelected ? 0.45 : 0.30,
      );

      // Update BORDER COLOR
      await style.setStyleLayerProperty(
        _lineLayerId,
        "line-color",
        isSelected ? "#FFA000" : "#00FFAA", // darker gold border
      );

      await style.setStyleLayerProperty(
        _lineLayerId,
        "line-width",
        isSelected ? 3.0 : 2.0,
      );
    } catch (e) {
      debugPrint("⚠️ updateSelectionHighlight failed: $e");
    }
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
    await _addSelectionLayerIfMissing(style);
    await _addHandleLayerIfMissing(style); // NEW
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

  /// Resize rectangle keeping opposite corner anchored.
  /// This ALWAYS keeps 90° angles.
  Future<void> _resizeFromCorner(int cornerIndex, Position movedCorner) async {
    _assertInitialized();
    final rect = _rectangle!;
    final corners = rect.corners;

    final anchorIndex = (cornerIndex + 2) % 4; // diagonal opposite
    final anchor = corners[anchorIndex];

    final dx = movedCorner.lng - anchor.lng;
    final dy = movedCorner.lat - anchor.lat;

    // Compute new other corners assuming rectangle axis-aligned
    final newCorners = List<Position>.from(corners);

    // cornerIndex is changing, others get recomputed
    switch (cornerIndex) {
      case 0:
        newCorners[0] = movedCorner;
        newCorners[1] = Position(anchor.lng + dx, anchor.lat);
        newCorners[3] = Position(anchor.lng, anchor.lat + dy);
        break;

      case 1:
        newCorners[1] = movedCorner;
        newCorners[0] = Position(anchor.lng + dx, anchor.lat);
        newCorners[2] = Position(anchor.lng, anchor.lat + dy);
        break;

      case 2:
        newCorners[2] = movedCorner;
        newCorners[1] = Position(anchor.lng, anchor.lat + dy);
        newCorners[3] = Position(anchor.lng + dx, anchor.lat);
        break;

      case 3:
        newCorners[3] = movedCorner;
        newCorners[0] = Position(anchor.lng, anchor.lat + dy);
        newCorners[2] = Position(anchor.lng + dx, anchor.lat);
        break;
    }

    _rectangle = rect.copyWith(coordinates: [
      newCorners[0],
      newCorners[1],
      newCorners[2],
      newCorners[3],
      newCorners[0], // closed polygon
    ]);

    await _syncGeoJson();
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

// --- New selection source/layer IDs ---
  static const String _selectionSourceId = 'rectangle-selection-source';
  static const String _selectionLayerId = 'rectangle-selection-layer';

// Add a symbol layer to enable tapping rectangles
  Future<void> _addSelectionLayerIfMissing(StyleManager style) async {
    try {
      await style.addSource(GeoJsonSource(
        id: _selectionSourceId,
        data: jsonEncode(_emptyFeatureCollection),
      ));
    } catch (_) {}

    try {
      await style.addLayer(
        SymbolLayer(
          id: _selectionLayerId,
          sourceId: _selectionSourceId,
          iconSize: 1.0,
          // Replace with an actual icon in your assets
          iconImage: "marker-15",
          iconOpacity: 0.01, // nearly invisible
        ),
      );
    } catch (_) {}
  }

  Future<void> _addHandleLayerIfMissing(StyleManager style) async {
    // 1) Add source
    try {
      await style.addSource(
        GeoJsonSource(
          id: _handleSourceId,
          data: jsonEncode(_emptyFeatureCollection),
        ),
      );
    } catch (_) {}

    // 2) Add SymbolLayer for handles
    try {
      await style.addLayer(
        SymbolLayer(
          id: _handleLayerId,
          sourceId: _handleSourceId,
          iconImage: "marker-15",
          iconSize: 1.0,
          iconColor: 0xFFFF0000, // <-- FIXED
        ),
      );
    } catch (e) {
      debugPrint("Handle layer add skipped/failed: $e");
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

    // ---- update rectangle fill/line source ----
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

    // ---- update selection marker source ----
    try {
      final selectionData = _rectangle == null
          ? _emptyFeatureCollection
          : {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [
                      _rectangle!.center.lng,
                      _rectangle!.center.lat,
                    ]
                  },
                  "properties": {"id": _rectangle!.id},
                }
              ]
            };

      await style.setStyleSourceProperty(
        _selectionSourceId,
        "data",
        jsonEncode(selectionData),
      );
    } catch (_) {}

    // ---- update corner handles source ----
    try {
      if (_rectangle == null) {
        await style.setStyleSourceProperty(
          _handleSourceId,
          "data",
          jsonEncode(_emptyFeatureCollection),
        );
      } else {
        final corners = _rectangle!.corners;

        final handleFeatures = corners.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;

          return {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [p.lng, p.lat]
            },
            "properties": {"cornerIndex": i},
          };
        }).toList();

        final handleCollection = {
          "type": "FeatureCollection",
          "features": handleFeatures
        };

        await style.setStyleSourceProperty(
          _handleSourceId,
          "data",
          jsonEncode(handleCollection),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Failed updating rectangle handle source: $e");
    }
  }

  /// Returns the corner index if tap is near handle, else null.
  int? hitTestHandle(Position tap, {double threshold = 0.0002}) {
    if (_rectangle == null) return null;

    final corners = _rectangle!.corners;

    for (int i = 0; i < corners.length; i++) {
      final c = corners[i];
      final dx = (tap.lng - c.lng).abs();
      final dy = (tap.lat - c.lat).abs();
      if (dx < threshold && dy < threshold) return i;
    }

    return null;
  }

  Map<String, dynamic> get _emptyFeatureCollection => {
        'type': 'FeatureCollection',
        'features': [],
      };
}
