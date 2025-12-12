import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_model.dart';
import 'package:worldtile_app/theme/app_theme.dart';
import 'dart:math';

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
  List<Position>? _dragStartCorners; // snapshot of rectangle at drag start
  Position? _dragAnchor; // fixed opposite corner
  final bool _enableResizeAnimation = true;
  final int _animationFrames = 8; // smoothness
  final Duration _animationDelay = const Duration(milliseconds: 12);
  bool _isAnimating = false; // prevents overlapping animations
  final bool _animateOnDragEnd =
      true; // enable optional settle animation after drag ends

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

  Position _lerpPos(Position a, Position b, double t) {
    return Position(
      a.lng + (b.lng - a.lng) * t,
      a.lat + (b.lat - a.lat) * t,
    );
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

    if (_rectangle == null) return;

    // snapshot of corners
    _dragStartCorners = List<Position>.from(_rectangle!.corners);

    // anchor is the diagonal opposite
    final anchorIndex = (cornerIndex + 2) % 4;
    _dragAnchor = _rectangle!.corners[anchorIndex];
  }

  Future<void> updateCornerDrag(Position newPos) async {
    // Fast path: while dragging, update immediately (no animation)
    if (_draggingCornerIndex == null ||
        _rectangle == null ||
        _dragStartCorners == null ||
        _dragAnchor == null) return;

    final cornerIndex = _draggingCornerIndex!;
    final original = _dragStartCorners!;
    final anchor = _dragAnchor!;

    final dx = newPos.lng - anchor.lng;
    final dy = newPos.lat - anchor.lat;

    // compute new corners from the drag-start snapshot (so deltas are stable)
    final updated = List<Position>.from(original);

    switch (cornerIndex) {
      case 0:
        updated[0] = newPos;
        updated[1] = Position(anchor.lng + dx, anchor.lat);
        updated[3] = Position(anchor.lng, anchor.lat + dy);
        break;
      case 1:
        updated[1] = newPos;
        updated[0] = Position(anchor.lng + dx, anchor.lat);
        updated[2] = Position(anchor.lng, anchor.lat + dy);
        break;
      case 2:
        updated[2] = newPos;
        updated[1] = Position(anchor.lng, anchor.lat + dy);
        updated[3] = Position(anchor.lng + dx, anchor.lat);
        break;
      case 3:
        updated[3] = newPos;
        updated[0] = Position(anchor.lng, anchor.lat + dy);
        updated[2] = Position(anchor.lng + dx, anchor.lat);
        break;
    }

    // Close polygon
    final coords = [...updated, updated[0]];

    // Apply immediately for responsive dragging
    _rectangle = _rectangle!.copyWith(coordinates: coords);
    await _syncGeoJson();
  }

  /// Stop dragging
  void endCornerDrag() {
    // capture final target before clearing drag state
    final finalCorners = _rectangle?.corners;

    _draggingCornerIndex = null;
    _dragStartCorners = null;
    _dragAnchor = null;

    // Optionally run a quick settle animation from the current displayed corners
    // to the final computed corners (if there's any difference).
    if (_animateOnDragEnd &&
        !_isAnimating &&
        _mapboxMap != null &&
        finalCorners != null) {
      // schedule async animation (don't block caller)
      _runSettleAnimation(finalCorners);
    }
  }

  Future<void> _runSettleAnimation(List<Position> finalCorners) async {
    if (!_enableResizeAnimation) return;
    if (_isAnimating) return;

    _isAnimating = true;
    try {
      // start = currently visible corners (can be fetched from _rectangle)
      final startCorners = _rectangle?.corners ?? finalCorners;
      // ensure length 4
      if (startCorners.length < 4 || finalCorners.length < 4) return;

      // Do a short animation over _animationFrames frames
      for (int i = 1; i <= _animationFrames; i++) {
        final t = i / _animationFrames;
        final interpolated = List<Position>.generate(4, (idx) {
          return _lerpPos(startCorners[idx], finalCorners[idx], t);
        });

        _rectangle = _rectangle!
            .copyWith(coordinates: [...interpolated, interpolated[0]]);
        await _syncGeoJson();
        await Future.delayed(_animationDelay);
      }
    } catch (e) {
      debugPrint('⚠️ _runSettleAnimation failed: $e');
    } finally {
      _isAnimating = false;
    }
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
      await setHandlesVisible(isSelected);
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

  /// Show or hide the red corner handles
  Future<void> setHandlesVisible(bool visible) async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    try {
      await style.setStyleLayerProperty(
        _handleLayerId,
        "circle-opacity",
        visible ? 1.0 : 0.0,
      );
    } catch (e) {
      debugPrint("⚠️ Failed updating handle visibility: $e");
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
    // 1) Create/ensure GeoJSON source for handle points
    try {
      await style.addSource(
        GeoJsonSource(
          id: _handleSourceId,
          data: jsonEncode(_emptyFeatureCollection),
        ),
      );
    } catch (_) {
      // Source may already exist — ignore
    }

    // 2) Add CircleLayer for crisp red corner dots
    try {
      await style.addLayer(
        CircleLayer(
          id: _handleLayerId,
          sourceId: _handleSourceId,
          // red dot visual
          circleColor: 0xFFFF0000, // red
          circleRadius: 6.0, // size in pixels
          circleStrokeColor: 0xFFFFFFFF, // white border
          circleStrokeWidth: 1.5,
          circleOpacity: 0.0, // hidden until selected
        ),
      );
    } catch (e) {
      debugPrint("⚠️ Failed adding handle CircleLayer: $e");
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

        await setHandlesVisible(false);
        return;
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

  /// Pixel-accurate hit test for corner handles.
  /// Returns index 0–3 if inside 15px radius, else null.
  Future<int?> hitTestHandlePixel(Position tap) async {
    if (_rectangle == null || _mapboxMap == null) return null;

    final map = _mapboxMap!;
    final corners = _rectangle!.corners;

    // Convert tap to pixel coordinates
    final tapPx = await map.pixelForCoordinate(
      Point(coordinates: tap),
    );

    for (int i = 0; i < corners.length; i++) {
      final cornerPx = await map.pixelForCoordinate(
        Point(coordinates: corners[i]),
      );

      final dx = (tapPx.x - cornerPx.x);
      final dy = (tapPx.y - cornerPx.y);
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < 15) {
        return i;
      }
    }

    return null;
  }

  Map<String, dynamic> get _emptyFeatureCollection => {
        'type': 'FeatureCollection',
        'features': [],
      };
}
