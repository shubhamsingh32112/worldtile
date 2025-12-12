import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_model_new.dart';
import 'package:worldtile_app/theme/app_theme.dart';
import 'dart:math' as math;

/// Handles Mapbox rendering for rectangles (fill, line, handles)
class RectangleRenderer {
  static const String _sourceId = 'rectangle-geojson-source';
  static const String _fillLayerId = 'rectangle-fill-layer';
  static const String _lineLayerId = 'rectangle-line-layer';
  static const String _handleSourceId = 'rectangle-handle-source';
  static const String _handleLayerId = 'rectangle-handle-layer';
  static const String _rotationHandleSourceId = 'rectangle-rotation-handle-source';
  static const String _rotationHandleLayerId = 'rectangle-rotation-handle-layer';

  StyleManager? _style;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Initialize renderer - creates sources and layers ONCE
  Future<void> initialize(StyleManager style) async {
    if (_initialized) return;

    _style = style;

    try {
      // Create GeoJSON source for rectangle polygon
      await _addSourceIfMissing(_sourceId, style);

      // Create fill layer
      await _addFillLayerIfMissing(style);

      // Create line layer
      await _addLineLayerIfMissing(style);

      // Create handle source and layer
      await _addSourceIfMissing(_handleSourceId, style);
      await _addHandleLayerIfMissing(style);

      // Create rotation handle source and layer
      await _addSourceIfMissing(_rotationHandleSourceId, style);
      await _addRotationHandleLayerIfMissing(style);

      _initialized = true;
      debugPrint('✅ RectangleRenderer initialized');
    } catch (e) {
      debugPrint('❌ RectangleRenderer initialization failed: $e');
      rethrow;
    }
  }

  /// Update rectangle polygon (fill + line layers)
  Future<void> updateRectangle(RectangleModel? rectangle) async {
    if (_style == null || !_initialized) return;

    try {
      final featureCollection = rectangle == null
          ? _emptyFeatureCollection
          : {
              'type': 'FeatureCollection',
              'features': [rectangle.toGeoJsonFeature()],
            };

      await _style!.setStyleSourceProperty(
        _sourceId,
        'data',
        jsonEncode(featureCollection),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to update rectangle: $e');
    }
  }

  /// Update side handles (4 handles for scaling)
  Future<void> updateHandles(
    RectangleModel? rectangle,
    bool visible,
  ) async {
    if (_style == null || !_initialized) return;

    try {
      if (rectangle == null || !visible) {
        // Hide handles
        await _style!.setStyleSourceProperty(
          _handleSourceId,
          'data',
          jsonEncode(_emptyFeatureCollection),
        );
        await _setHandleVisibility(false);
        return;
      }

      // Compute handle positions (midpoints of each edge)
      final corners = rectangle.corners;
      final handles = [
        // Top edge midpoint
        Position(
          (corners[2].lng + corners[3].lng) / 2,
          (corners[2].lat + corners[3].lat) / 2,
        ),
        // Right edge midpoint
        Position(
          (corners[1].lng + corners[2].lng) / 2,
          (corners[1].lat + corners[2].lat) / 2,
        ),
        // Bottom edge midpoint
        Position(
          (corners[0].lng + corners[1].lng) / 2,
          (corners[0].lat + corners[1].lat) / 2,
        ),
        // Left edge midpoint
        Position(
          (corners[3].lng + corners[0].lng) / 2,
          (corners[3].lat + corners[0].lat) / 2,
        ),
      ];

      final handleFeatures = handles.asMap().entries.map((entry) {
        final index = entry.key;
        final position = entry.value;
        return {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.lng, position.lat],
          },
          'properties': {'handleIndex': index},
        };
      }).toList();

      final featureCollection = {
        'type': 'FeatureCollection',
        'features': handleFeatures,
      };

      await _style!.setStyleSourceProperty(
        _handleSourceId,
        'data',
        jsonEncode(featureCollection),
      );
      await _setHandleVisibility(true);
    } catch (e) {
      debugPrint('⚠️ Failed to update handles: $e');
    }
  }

  /// Update rotation handle (positioned above top edge)
  Future<void> updateRotationHandle(
    RectangleModel? rectangle,
    bool visible,
  ) async {
    if (_style == null || !_initialized) return;

    try {
      if (rectangle == null || !visible) {
        // Hide rotation handle
        await _style!.setStyleSourceProperty(
          _rotationHandleSourceId,
          'data',
          jsonEncode(_emptyFeatureCollection),
        );
        await _setRotationHandleVisibility(false);
        return;
      }

      // Compute rotation handle position (above top edge)
      final corners = rectangle.corners;
      final topMidpoint = Position(
        (corners[2].lng + corners[3].lng) / 2,
        (corners[2].lat + corners[3].lat) / 2,
      );

      // Offset above by ~10% of height
      final offsetMeters = rectangle.heightMeters * 0.15;
      final rotationHandlePosition = Position(
        topMidpoint.lng,
        topMidpoint.lat + (offsetMeters / 111320.0), // Approximate lat offset
      );

      final feature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [rotationHandlePosition.lng, rotationHandlePosition.lat],
        },
        'properties': {'type': 'rotation'},
      };

      final featureCollection = {
        'type': 'FeatureCollection',
        'features': [feature],
      };

      await _style!.setStyleSourceProperty(
        _rotationHandleSourceId,
        'data',
        jsonEncode(featureCollection),
      );
      await _setRotationHandleVisibility(true);
    } catch (e) {
      debugPrint('⚠️ Failed to update rotation handle: $e');
    }
  }

  /// Set selection highlight (change colors)
  Future<void> setSelected(bool selected) async {
    if (_style == null || !_initialized) return;

    try {
      final fillColor = selected ? 0xFFFFD54F : AppTheme.primaryColor.value;
      final lineColor = selected ? 0xFFFFA000 : AppTheme.primaryColor.value;
      final lineWidth = selected ? 3.0 : 2.0;
      final fillOpacity = selected ? 0.45 : 0.30;

      await _style!.setStyleLayerProperty(
        _fillLayerId,
        'fill-color',
        fillColor,
      );
      await _style!.setStyleLayerProperty(
        _fillLayerId,
        'fill-opacity',
        fillOpacity,
      );
      await _style!.setStyleLayerProperty(
        _lineLayerId,
        'line-color',
        lineColor,
      );
      await _style!.setStyleLayerProperty(
        _lineLayerId,
        'line-width',
        lineWidth,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to set selection: $e');
    }
  }

  /// Cleanup - remove layers and sources
  Future<void> dispose() async {
    if (_style == null) return;

    try {
      await _removeLayer(_handleLayerId);
      await _removeLayer(_rotationHandleLayerId);
      await _removeLayer(_lineLayerId);
      await _removeLayer(_fillLayerId);
      await _removeSource(_handleSourceId);
      await _removeSource(_rotationHandleSourceId);
      await _removeSource(_sourceId);
    } catch (e) {
      debugPrint('⚠️ Error disposing renderer: $e');
    }

    _initialized = false;
    _style = null;
  }

  // --- Private Helpers ---

  Future<void> _addSourceIfMissing(String sourceId, StyleManager style) async {
    try {
      await style.addSource(GeoJsonSource(
        id: sourceId,
        data: jsonEncode(_emptyFeatureCollection),
      ));
    } catch (e) {
      // Source might already exist - ignore
      if (kDebugMode) {
        debugPrint('Source $sourceId already exists or error: $e');
      }
    }
  }

  Future<void> _addFillLayerIfMissing(StyleManager style) async {
    try {
      await style.addLayer(
        FillLayer(
          id: _fillLayerId,
          sourceId: _sourceId,
          fillColor: AppTheme.primaryColor.value,
          fillOpacity: 0.3,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Fill layer already exists or error: $e');
    }
  }

  Future<void> _addLineLayerIfMissing(StyleManager style) async {
    try {
      await style.addLayer(
        LineLayer(
          id: _lineLayerId,
          sourceId: _sourceId,
          lineColor: AppTheme.primaryColor.value,
          lineWidth: 2.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Line layer already exists or error: $e');
    }
  }

  Future<void> _addHandleLayerIfMissing(StyleManager style) async {
    try {
      await style.addLayer(
        CircleLayer(
          id: _handleLayerId,
          sourceId: _handleSourceId,
          circleColor: 0xFFFF0000, // Red
          circleRadius: 6.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          circleStrokeWidth: 1.5,
          circleOpacity: 0.0, // Hidden by default
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Handle layer already exists or error: $e');
    }
  }

  Future<void> _addRotationHandleLayerIfMissing(StyleManager style) async {
    try {
      await style.addLayer(
        CircleLayer(
          id: _rotationHandleLayerId,
          sourceId: _rotationHandleSourceId,
          circleColor: 0xFF0000FF, // Blue
          circleRadius: 6.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          circleStrokeWidth: 1.5,
          circleOpacity: 0.0, // Hidden by default
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Rotation handle layer already exists or error: $e');
      }
    }
  }

  Future<void> _setHandleVisibility(bool visible) async {
    if (_style == null) return;
    try {
      await _style!.setStyleLayerProperty(
        _handleLayerId,
        'circle-opacity',
        visible ? 1.0 : 0.0,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to set handle visibility: $e');
    }
  }

  Future<void> _setRotationHandleVisibility(bool visible) async {
    if (_style == null) return;
    try {
      await _style!.setStyleLayerProperty(
        _rotationHandleLayerId,
        'circle-opacity',
        visible ? 1.0 : 0.0,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to set rotation handle visibility: $e');
    }
  }

  Future<void> _removeLayer(String layerId) async {
    if (_style == null) return;
    try {
      await _style!.removeStyleLayer(layerId);
    } catch (e) {
      // Ignore if not present
    }
  }

  Future<void> _removeSource(String sourceId) async {
    if (_style == null) return;
    try {
      await _style!.removeStyleSource(sourceId);
    } catch (e) {
      // Ignore if not present
    }
  }

  Map<String, dynamic> get _emptyFeatureCollection => {
        'type': 'FeatureCollection',
        'features': [],
      };
}

