import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_model_new.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_renderer.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_gestures.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/area_increase_event.dart';
import 'package:worldtile_app/utils/coordinate_converter.dart';

/// Debounce delay for smooth updates (target 60fps = ~16ms)
const Duration _updateDebounceDelay = Duration(milliseconds: 16);

/// Minimum area required: 1 acre
const double MINIMUM_AREA_METERS_SQUARED = 4046.86;

/// Controller for rectangle creation, manipulation, and validation
class RectangleController {
  MapboxMap? _mapboxMap;
  RectangleModel? _currentRectangle;
  RectangleModel? _lastValidRectangle;
  double _previousArea = 0.0;
  bool _initialized = false;
  bool _placementMode = false;
  bool _isDragging = false;
  HandleType? _activeHandleType;
  Position? _dragStartPosition;

  final RectangleRenderer _renderer = RectangleRenderer();

  // Callbacks
  Function()? _onValidationFailed;
  Function(AreaIncreaseEvent)? _onAreaIncreased;

  // Area tracking
  final List<AreaIncreaseEvent> _areaHistory = [];

  // Performance: Debounce updates during drag
  Timer? _updateDebounceTimer;
  Position? _pendingDragPosition;

  RectangleModel? get rectangle => _currentRectangle;
  bool get isInitialized => _initialized;
  bool get isPlacementMode => _placementMode;

  /// Initialize controller with Mapbox map instance
  Future<void> init(MapboxMap mapboxMap) async {
    if (_initialized) return;

    _mapboxMap = mapboxMap;
    await _renderer.initialize(mapboxMap.style);
    _initialized = true;
    debugPrint('✅ RectangleController initialized');
  }

  /// Set callback for validation failures
  void setValidationFailedCallback(Function() callback) {
    _onValidationFailed = callback;
  }

  /// Set callback for area increases
  void setAreaIncreasedCallback(Function(AreaIncreaseEvent) callback) {
    _onAreaIncreased = callback;
  }

  /// Enter placement mode - next tap will create rectangle
  void enterPlacementMode() {
    _placementMode = true;
    debugPrint('🎨 Entered placement mode');
  }

  /// Create rectangle at center position
  Future<void> createAtCenter(Position center) async {
    if (!_initialized) {
      throw StateError('Controller not initialized. Call init() first.');
    }

    _currentRectangle = RectangleModel.defaultAt(center);
    _lastValidRectangle = _currentRectangle;
    _previousArea = _currentRectangle!.area;
    _placementMode = false;

    await _renderer.updateRectangle(_currentRectangle);
    await _renderer.updateHandles(_currentRectangle, true);
    await _renderer.updateRotationHandle(_currentRectangle, true);

    debugPrint('📍 Rectangle created at center: ${center.lng}, ${center.lat}');
  }

  /// Handle map tap - creation, selection, or handle interaction
  Future<bool> handleMapTap(Position tapPosition) async {
    if (!_initialized || _mapboxMap == null) return false;

    // Placement mode: create rectangle
    if (_placementMode) {
      await createAtCenter(tapPosition);
      return true;
    }

    // Check if tapping a handle
    if (_currentRectangle != null) {
      final handleType = await RectangleGestures.hitTestHandle(
        tapPosition,
        _currentRectangle!,
        _mapboxMap!,
      );

      if (handleType != null) {
        // Handle tapped - start drag (actual drag handled separately)
        _activeHandleType = handleType;
        _dragStartPosition = tapPosition;
        return true;
      }

      // Check if tapping inside rectangle
      if (_currentRectangle!.containsPoint(tapPosition.lng, tapPosition.lat)) {
        // Rectangle selected - handled by UI layer
        return true;
      }
    }

    return false;
  }

  /// Start dragging a handle
  Future<void> startDrag(HandleType handleType, Position startPosition) async {
    if (_currentRectangle == null || _mapboxMap == null) return;

    _isDragging = true;
    _activeHandleType = handleType;
    _dragStartPosition = startPosition;

    // Save current state for rollback if needed
    _lastValidRectangle = _currentRectangle;

    // Disable map gestures
    await RectangleGestures.disableMapGestures(_mapboxMap!);

    debugPrint('🔵 Drag started: $handleType');
  }

  /// Update drag position (debounced for performance)
  Future<void> updateDrag(Position dragPosition) async {
    if (!_isDragging ||
        _currentRectangle == null ||
        _activeHandleType == null) return;

    // Store pending position
    _pendingDragPosition = dragPosition;

    // Cancel existing timer
    _updateDebounceTimer?.cancel();

    // Schedule debounced update
    _updateDebounceTimer = Timer(_updateDebounceDelay, () async {
      if (_pendingDragPosition == null) return;

      await _performDragUpdate(_pendingDragPosition!);
      _pendingDragPosition = null;
    });
  }

  /// Perform actual drag update (called after debounce)
  Future<void> _performDragUpdate(Position dragPosition) async {
    if (!_isDragging ||
        _currentRectangle == null ||
        _activeHandleType == null) return;

    try {
      RectangleModel? updated;

      switch (_activeHandleType!) {
        case HandleType.sideTop:
        case HandleType.sideRight:
        case HandleType.sideBottom:
        case HandleType.sideLeft:
          // Uniform scaling
          updated = await _updateUniformScale(dragPosition);
          break;
        case HandleType.rotation:
          // Rotation
          updated = await _updateRotation(dragPosition);
          break;
      }

      if (updated != null) {
        // Validate area
        if (!updated.isValidArea) {
          // Revert to last valid
          _currentRectangle = _lastValidRectangle;
          _onValidationFailed?.call();
          await _renderer.updateRectangle(_currentRectangle);
          return;
        }

        // Track area increase
        _trackAreaChange(_currentRectangle!.area, updated.area);

        // Update
        _currentRectangle = updated;
        await _renderer.updateRectangle(_currentRectangle);
        await _renderer.updateHandles(_currentRectangle, true);
        await _renderer.updateRotationHandle(_currentRectangle, true);
      }
    } catch (e) {
      debugPrint('⚠️ Drag update error: $e');
    }
  }

  /// End drag
  Future<void> endDrag() async {
    if (!_isDragging) return;

    // Cancel pending updates
    _updateDebounceTimer?.cancel();

    // Perform final update if pending
    if (_pendingDragPosition != null) {
      await _performDragUpdate(_pendingDragPosition!);
      _pendingDragPosition = null;
    }

    _isDragging = false;
    _activeHandleType = null;
    _dragStartPosition = null;

    // Restore map gestures
    if (_mapboxMap != null) {
      await RectangleGestures.restoreMapGestures(_mapboxMap!);
    }

    debugPrint('🟢 Drag ended');
  }

  /// Set rectangle selection state
  Future<void> setSelected(bool selected) async {
    await _renderer.setSelected(selected);
    await _renderer.updateHandles(_currentRectangle, selected);
    await _renderer.updateRotationHandle(_currentRectangle, selected);
  }

  /// Clear rectangle
  Future<void> clear() async {
    _currentRectangle = null;
    _lastValidRectangle = null;
    _previousArea = 0.0;
    _placementMode = false;

    await _renderer.updateRectangle(null);
    await _renderer.updateHandles(null, false);
    await _renderer.updateRotationHandle(null, false);
  }

  /// Dispose resources
  Future<void> dispose() async {
    _updateDebounceTimer?.cancel();
    await _renderer.dispose();
    _mapboxMap = null;
    _initialized = false;
  }

  // --- Private Methods ---

  /// Update uniform scaling
  Future<RectangleModel?> _updateUniformScale(Position dragPosition) async {
    if (_currentRectangle == null || _dragStartPosition == null) return null;

    final center = _currentRectangle!.center;

    // Calculate drag distance in meters
    final dragDistanceMeters = CoordinateConverter.distanceInMeters(
      center,
      dragPosition,
    );

    // Original distance from center to corner (half diagonal)
    final originalWidth = _currentRectangle!.widthMeters;
    final originalHeight = _currentRectangle!.heightMeters;
    final originalDiagonal = math.sqrt(
      math.pow(originalWidth / 2, 2) + math.pow(originalHeight / 2, 2),
    );

    if (originalDiagonal == 0) return null;

    // Compute scale factor (preserve ratio)
    final scaleFactor = math.max(0.01, dragDistanceMeters / originalDiagonal);

    // Apply uniform scale
    final newWidth = originalWidth * scaleFactor;
    final newHeight = originalHeight * scaleFactor;

    return _currentRectangle!.copyWith(
      widthMeters: newWidth,
      heightMeters: newHeight,
    );
  }

  /// Update rotation
  Future<RectangleModel?> _updateRotation(Position dragPosition) async {
    if (_currentRectangle == null) return null;

    final center = _currentRectangle!.center;

    // Calculate angle from center to drag position
    final dx = dragPosition.lng - center.lng;
    final dy = dragPosition.lat - center.lat;

    // Compute angle in radians
    final angleRadians = math.atan2(dy, dx);

    // Convert to degrees
    var angleDegrees = angleRadians * 180 / math.pi;

    // Normalize to 0-360
    angleDegrees = angleDegrees % 360.0;
    if (angleDegrees < 0) angleDegrees += 360;

    return _currentRectangle!.copyWith(rotationDegrees: angleDegrees);
  }

  /// Track area changes (only increases)
  void _trackAreaChange(double oldArea, double newArea) {
    if (newArea > oldArea) {
      final delta = newArea - oldArea;
      final event = AreaIncreaseEvent(
        timestamp: DateTime.now(),
        deltaMetersSquared: delta,
        previousArea: oldArea,
        newArea: newArea,
      );

      _currentRectangle = _currentRectangle!.recordAreaIncrease(event);
      _onAreaIncreased?.call(event);

      debugPrint(
          '📈 Area increased: ${delta.toStringAsFixed(2)} m² (${oldArea.toStringAsFixed(2)} → ${newArea.toStringAsFixed(2)})');
    }

    _previousArea = newArea;
  }

  /// Load rectangle from MongoDB data
  Future<void> loadFromMongoData(Map<String, dynamic> data) async {
    if (!_initialized) return;

    final rect = RectangleModel.fromMongoData(data);

    _currentRectangle = rect;
    _lastValidRectangle = rect;
    _previousArea = rect.area;

    await _renderer.updateRectangle(rect);
    await _renderer.updateHandles(rect, false); // Hide until selected
    await _renderer.updateRotationHandle(rect, false);
  }
}

