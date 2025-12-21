  import 'dart:async';
  import 'dart:convert';
  import 'dart:ui';
  import 'package:flutter/material.dart';
  import 'package:flutter_dotenv/flutter_dotenv.dart';
  import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import '../../theme/app_theme.dart';
  import '../../services/land_service.dart';
  import '../../data/open_states/open_states_geojson.dart';
  import '../../data/open_states/state_key_mapper.dart';
  import '../../data/world_bounds_helper.dart';
import '../../widgets/state_areas_bottom_sheet.dart';
import 'map_controller.dart';

  /// WorldMapPage displays a full world map using Mapbox Maps SDK
  ///
  /// This widget shows a world map view with:
  /// - Full world view (zoom level 0)
  /// - Centered at coordinates (0, 0)
  /// - Uses Mapbox Streets style
  /// - Loads Mapbox token from .env file
  class WorldMapPage extends StatefulWidget {
    final bool showViewOpenStatesButton;
    
    const WorldMapPage({
      super.key,
      this.showViewOpenStatesButton = false,
    });

    @override
    State<WorldMapPage> createState() => WorldMapPageState();
  }

  class WorldMapPageState extends State<WorldMapPage> {
    MapboxMap? mapboxMap;
    bool _isMapReady = false;
    String? _errorMessage;
    Timer? _loadingTimeout;
    bool _hasAppliedCustomFog = false;

    // User polygons state (raw GeoJSON data)
    List<Map<String, dynamic>> _userPolygons = [];
    bool _isLoadingPolygons = false;

    // Button state for "View Open States"
    bool _showViewOpenStates = false;
    bool _hasClickedViewOpenStates = false;

    @override
    void initState() {
      super.initState();
      _validateMapboxToken();
      _verifyTokenInNativeConfig();
      
      // Initialize button state based on widget parameter
      _showViewOpenStates = widget.showViewOpenStatesButton;
      
      // Set a timeout to show error if map doesn't load within 15 seconds
      _loadingTimeout = Timer(const Duration(seconds: 15), () {
        if (mounted && !_isMapReady && _errorMessage == null) {
          setState(() {
            _errorMessage =
                "Map is taking too long to load. Please check your internet connection and try again.";
          });
        }
      });
    }

    @override
    void dispose() {
      // Cancel timers
      _loadingTimeout?.cancel();

      // Unbind map controller (safe no-op if already null)
      WorldMapController.instance.unbind();

      // Dispose mapbox instance
      mapboxMap?.dispose();

      super.dispose();
    }

    /// Verifies that the Mapbox token is properly configured
    /// Checks both Flutter-level and native-level token configuration
    void _verifyTokenInNativeConfig() {
      final token = dotenv.env["MAPBOX_PUBLIC_TOKEN"];

      if (token == null || token.isEmpty) {
        return; // Already handled by _validateMapboxToken
      }

      // Verify token is set globally in Flutter
      try {
        // This should have been set in main.dart, but verify it's accessible
        debugPrint('🔍 Verifying Mapbox token configuration...');
        debugPrint('  - Token from .env: ${token.substring(0, 10)}...');
        debugPrint('  - Token length: ${token.length}');
        debugPrint(
            '  - Token format: ${token.startsWith("pk.") ? "Valid (public token)" : "Invalid"}');
      } catch (e) {
        debugPrint('⚠️ Error verifying token: $e');
      }
    }

    /// Validates that the Mapbox token is properly configured
    void _validateMapboxToken() {
      final token = dotenv.env["MAPBOX_PUBLIC_TOKEN"];

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = "MAPBOX_PUBLIC_TOKEN not found in .env file";
        });
        return;
      }

      if (!token.startsWith("pk.")) {
        setState(() {
          _errorMessage =
              "Invalid Mapbox token. Must start with 'pk.' (public token)";
        });
        return;
      }
    }

    /// Called when the map is successfully created
    void _onMapCreated(MapboxMap mapboxMapController) async {
      if (!mounted) return;

      debugPrint('🗺️ Map created successfully');

      setState(() {
        mapboxMap = mapboxMapController;
      });

      // Bind the map controller for camera commands
      WorldMapController.instance.bind(mapboxMapController);

      // Disable scale bar and compass after map is initialized
      try {
        // Wait a bit for the map to fully initialize
        await Future.delayed(const Duration(milliseconds: 100));

        // Access scale bar and compass managers to disable them
        await mapboxMapController.scaleBar.updateSettings(
          ScaleBarSettings(enabled: false),
        );
        await mapboxMapController.compass.updateSettings(
          CompassSettings(enabled: false),
        );

        debugPrint('✅ Disabled scale bar and compass');
      } catch (e) {
        debugPrint('⚠️ Error disabling scale bar/compass: $e');
      }

      // Set maximum zoom level to 4
      try {
        // Wait for map to be fully ready
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Set bounds with max zoom constraint (infinite bounds to allow panning anywhere)
        final bounds = CoordinateBounds(
          southwest: Point(
            coordinates: Position(-180.0, -90.0),
          ),
          northeast: Point(
            coordinates: Position(180.0, 90.0),
          ),
          infiniteBounds: true,
        );

        await mapboxMapController.setBounds(
          CameraBoundsOptions(
            bounds: bounds,
            maxZoom: 4.0,
            minZoom: 0.0,
          ),
        );

        debugPrint('✅ Set maximum zoom level to 4');
      } catch (e) {
        debugPrint('⚠️ Error setting max zoom constraint: $e');
      }

      // Wait a short moment for the map to initialize, then mark as ready
      // The map widget is ready when onMapCreated fires, style loads asynchronously
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadingTimeout?.cancel();
          setState(() {
            _isMapReady = true;
          });
          debugPrint('✅ Map marked as ready');
        }
      });
    }

    /// Runs once the style is fully loaded. Applies fog overrides and removes halos.
    Future<void> _onStyleLoaded(StyleLoadedEventData eventData) async {
      final currentMap = mapboxMap;
      if (currentMap == null) return;

      final style = currentMap.style;

      // First style load: rewrite fog settings, which reloads the style.
      if (!_hasAppliedCustomFog) {
        final applied = await _applyCustomFog(style);
        _hasAppliedCustomFog = applied;

        // When fog is applied successfully the style reloads; wait for next event
        // to avoid touching layers that may be replaced by the reload.
        if (applied) return;
      }

      // Subsequent loads: clean up halo/shadow artifacts.
      await _removeHaloEffects(style);

      // Add world-lock layer (gray fill for locked areas)
      // This must run after fog is applied and halo removal is complete
      // Only add when _hasAppliedCustomFog == true to avoid layer disappearing bug
      if (_hasAppliedCustomFog) {
        await _addWorldLockLayer(style);
      }

      // Add open states outline layer after style is stable
      // This must run after fog is applied and halo removal is complete
      // Only add when _hasAppliedCustomFog == true to avoid layer disappearing bug
      if (_hasAppliedCustomFog) {
        await _addOpenStatesOutlineLayer(style);
      }

      // Intro animation disabled - static world globe on startup
      // No rotation, no animation, camera stays at (0,0) zoom 0

      // Load user polygons when map is ready (only if user is authenticated)
      // User polygons will be added after open states outline, so they appear on top
      await _loadUserPolygonsIfAuthenticated();
    }

    /// Replace default fog/atmosphere with a darker, no-haze setup and dimmer stars.
    Future<bool> _applyCustomFog(StyleManager style) async {
      try {
        final rawStyle = await style.getStyleJSON();
        final decoded = jsonDecode(rawStyle);
        if (decoded is! Map<String, dynamic>) {
          debugPrint('⚠️ Unexpected style format; skipping fog customization');
          return false;
        }

        decoded['fog'] = {
          'range': [0.8, 8.0],
          'color': 'rgba(0, 0, 0, 0)',
          'high-color': 'rgba(0, 0, 0, 0)',
          'horizon-blend': 0.0,
          // IMPORTANT: Make space fully transparent so AppShell background shows through
          'space-color': 'rgba(0, 0, 0, 0)', // fully transparent
          'star-intensity': 0.0, // no stars at all
        };

        await style.setStyleJSON(jsonEncode(decoded));
        debugPrint('✨ Applied custom fog and star settings');
        return true;
      } catch (e) {
        debugPrint('⚠️ Failed to apply custom fog: $e');
        return false;
      }
    }

    /// Removes halo effects from all text and symbol layers in the map style
    Future<void> _removeHaloEffects(dynamic style) async {
      try {
        debugPrint('🎨 Starting halo effect removal...');

        // Get all layers from the style
        final layers = await style.getStyleLayers();
        debugPrint('📋 Found ${layers.length} layers to process');

        int modifiedCount = 0;

        // Iterate through all layers
        // Note: getStyleLayers() returns List<StyleObjectInfo?> - some entries can be null
        for (final layer in layers) {
          // Skip null layers (Mapbox injects placeholder objects during reloads)
          if (layer == null) continue;
          
          try {
            // Get layer type - check if it's a symbol layer by checking for text properties
            final layerId = layer.id;

            // Try to get layer type property to determine if it's a symbol layer
            try {
              final layerType =
                  await style.getStyleLayerProperty(layerId, 'type');

              // Only process symbol layers (which include text layers)
              if (layerType == 'symbol') {
                // Remove text halo width (set to 0)
                try {
                  await style.setStyleLayerProperty(
                    layerId,
                    'text-halo-width',
                    0.0,
                  );
                  modifiedCount++;
                  debugPrint('  ✅ Removed halo from layer: $layerId');
                } catch (e) {
                  // Layer might not have text-halo-width property, skip
                  debugPrint('  ⚠️ Could not remove halo from $layerId: $e');
                }

                // Also set text-halo-color to transparent (optional, for extra safety)
                try {
                  await style.setStyleLayerProperty(
                    layerId,
                    'text-halo-color',
                    'rgba(0, 0, 0, 0)',
                  );
                } catch (e) {
                  // Ignore if property doesn't exist
                }
              }
            } catch (e) {
              // If we can't get layer type, try to remove halo anyway (some layers might still have it)
              try {
                await style.setStyleLayerProperty(
                  layerId,
                  'text-halo-width',
                  0.0,
                );
                modifiedCount++;
                debugPrint(
                    '  ✅ Removed halo from layer: $layerId (type unknown)');
              } catch (e2) {
                // Layer doesn't have text-halo-width, skip
              }
            }
          } catch (e) {
            debugPrint('  ⚠️ Error processing layer: $e');
            // Continue with next layer
          }
        }

        debugPrint('✅ Halo removal complete. Modified $modifiedCount layers');
      } catch (e) {
        debugPrint('❌ Error in _removeHaloEffects: $e');
        // Don't rethrow - this is a non-critical enhancement
      }
    }

    /// Adds world-lock layer to the map
    /// 
    /// This method creates an inverse polygon that shows gray fill everywhere
    /// except the open states. The open states appear as transparent holes.
    /// 
    /// Layer ordering:
    /// - Above satellite imagery
    /// - Below open state outlines
    /// - Below user polygons
    /// 
    /// This method is idempotent and safe to call multiple times.
    /// 
    /// [style] - The Mapbox style manager
    Future<void> _addWorldLockLayer(StyleManager style) async {
      const sourceId = 'world-lock-source';
      const layerId = 'world-lock-fill-layer';

      try {
        // Load open states GeoJSON
        final openStatesGeoJson = await loadOpenStatesGeoJson();

        // Build inverse GeoJSON (world bounds with open states as holes)
        final inverseGeoJson = buildInverseGeoJson(openStatesGeoJson);

        // Add or update GeoJSON source
        try {
          await style.addSource(GeoJsonSource(
            id: sourceId,
            data: jsonEncode(inverseGeoJson),
          ));
          debugPrint('✅ Added world-lock source');
        } catch (e) {
          // Source might already exist, update it instead
          try {
            await style.setStyleSourceProperty(
              sourceId,
              'data',
              jsonEncode(inverseGeoJson),
            );
            debugPrint('✅ Updated world-lock source');
          } catch (updateError) {
            debugPrint('⚠️ Could not add/update world-lock source: $updateError');
            return;
          }
        }

        // Add fill layer for the locked areas
        // Color: light gray rgba(160,160,160,0.55) - opacity baked into color
        // No outline, no pattern - just a simple fill
        // Layer ordering: This layer is added before open-states-outline-layer,
        // so it will appear below it (correct ordering)
        try {
          // Convert rgba(160,160,160,0.55) to ARGB int
          // ARGB format: 0xAARRGGBB
          // rgba(160,160,160,0.55) = 0x8CA0A0A0 (alpha = 0.55 * 255 = 140 = 0x8C)
          const fillColor = 0x8CA0A0A0; // rgba(160,160,160,0.55) in ARGB

          await style.addLayer(
            FillLayer(
              id: layerId,
              sourceId: sourceId,
              fillColor: fillColor,
              // No fillOpacity - opacity is baked into color
            ),
          );
          debugPrint('✅ Added world-lock fill layer');
        } catch (e) {
          // Layer might already exist - this is fine, method is idempotent
          debugPrint('ℹ️ World-lock fill layer already exists or error: $e');
        }
      } catch (e) {
        debugPrint('❌ Error adding world-lock layer: $e');
        // Don't rethrow - this is a non-critical feature
      }
    }

    /// Adds open states outline layer to the map
    /// 
    /// This method is idempotent and safe to call multiple times.
    /// It creates a GeoJSON source and a LineLayer for all open state boundaries.
    /// The layer is positioned below user polygons but above satellite imagery.
    /// 
    /// This method supports multiple states (Level-1 GADM polygons) and renders
    /// blue outlines for all open states. The GeoJSON structure allows for future
    /// expansion to use these polygons as holes in a locked world mask.
    /// 
    /// [style] - The Mapbox style manager
    Future<void> _addOpenStatesOutlineLayer(StyleManager style) async {
      const sourceId = 'open-states-source';
      const layerId = 'open-states-outline-layer';

      try {
        // Load open states GeoJSON
        final openStatesGeoJson = await loadOpenStatesGeoJson();

        // Add or update GeoJSON source
        try {
          await style.addSource(GeoJsonSource(
            id: sourceId,
            data: jsonEncode(openStatesGeoJson),
          ));
          debugPrint('✅ Added open states outline source');
        } catch (e) {
          // Source might already exist, update it instead
          try {
            await style.setStyleSourceProperty(
              sourceId,
              'data',
              jsonEncode(openStatesGeoJson),
            );
            debugPrint('✅ Updated open states outline source');
          } catch (updateError) {
            debugPrint('⚠️ Could not add/update open states source: $updateError');
            return;
          }
        }

        // Add fill layer for open states (for tap detection)
        // This layer must be added before the outline layer
        const fillLayerId = 'open-states-fill-layer';
        try {
          await style.addLayer(
            FillLayer(
              id: fillLayerId,
              sourceId: sourceId,
              fillColor: 0x00000000, // Transparent fill (invisible but tappable)
              fillOpacity: 0.0, // Fully transparent
            ),
          );
          debugPrint('✅ Added open states fill layer');
        } catch (e) {
          // Layer might already exist - this is fine, method is idempotent
          debugPrint('ℹ️ Open states fill layer already exists or error: $e');
        }

        // Add line layer for the outline
        // Use solid blue color with ARGB format (0xFF0000FF = blue)
        // This visually communicates "These regions are open"
        try {
          await style.addLayer(
            LineLayer(
              id: layerId,
              sourceId: sourceId,
              lineColor: 0xFF000000, // Solid black (ARGB format)
              lineWidth: 1,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
              // No dash pattern, no fill - outline only
            ),
          );
          debugPrint('✅ Added open states outline layer');
        } catch (e) {
          // Layer might already exist - this is fine, method is idempotent
          debugPrint('ℹ️ Open states outline layer already exists or error: $e');
        }
      } catch (e) {
        debugPrint('❌ Error adding open states outline: $e');
        // Don't rethrow - this is a non-critical feature
      }
    }

    /// Handles map tap events
    void _onMapTap(MapContentGestureContext ctx) async {
      final lng = ctx.point.coordinates.lng.toDouble();
      final lat = ctx.point.coordinates.lat.toDouble();

      // --- Check for open state polygon tap ---
      // Since Mapbox Flutter SDK doesn't have queryRenderedFeatures,
      // we'll check if the tap point is inside any state polygon by loading the GeoJSON
      try {
        final openStatesGeoJson = await loadOpenStatesGeoJson();
        final features = openStatesGeoJson['features'] as List<dynamic>?;
        
        if (features != null) {
          // Check if tap point is inside any state polygon
          for (final feature in features) {
            final geometry = feature['geometry'] as Map<String, dynamic>?;
            final properties = feature['properties'] as Map<String, dynamic>?;
            
            if (geometry != null && properties != null) {
              final geometryType = geometry['type'] as String?;
              
              if (geometryType == 'Polygon' || geometryType == 'MultiPolygon') {
                // Check if point is inside polygon
                if (_isPointInPolygon(lng, lat, geometry)) {
                  // Extract stateKey from feature properties
                  final stateKey = StateKeyMapper.extractStateKeyFromFeature(properties);
                  
                  if (stateKey != null) {
                    debugPrint('🗺️ State polygon tapped: $stateKey');
                    // Open bottom sheet with areas for this state
                    _showStateAreasBottomSheet(stateKey);
                    return;
                  } else {
                    debugPrint('⚠️ Could not extract stateKey from feature properties');
                  }
                  break; // Found a match, no need to check other features
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error checking state polygon tap: $e');
      }
    }


    /// Handles camera change events
    /// Enforces maximum zoom level of 4
    void onCameraChange(CameraChangedEventData data) async {
      if (mapboxMap == null) return;

      try {
        final cameraState = await mapboxMap!.getCameraState();
        final currentZoom = cameraState.zoom;

        // Enforce maximum zoom of 4
        if (currentZoom > 4.0) {
          debugPrint('⚠️ Zoom exceeded maximum (${currentZoom} > 4.0), correcting...');
          
          // Set camera back to max zoom of 4
          await mapboxMap!.setCamera(
            CameraOptions(
              center: cameraState.center,
              zoom: 4.0,
              bearing: cameraState.bearing,
              pitch: cameraState.pitch,
            ),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error getting camera state: $e');
      }
    }


    /// Check if user is authenticated
    Future<bool> _isAuthenticated() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        return token != null && token.isNotEmpty;
      } catch (e) {
        return false;
      }
    }

    /// Load user polygons only if user is authenticated
    Future<void> _loadUserPolygonsIfAuthenticated() async {
      final isAuthenticated = await _isAuthenticated();
      if (!isAuthenticated) {
        debugPrint('ℹ️ User not authenticated, skipping polygon load');
        return;
      }
      await _loadUserPolygons();
    }

    /// Load user polygons from backend
    Future<void> _loadUserPolygons() async {
      if (_isLoadingPolygons) return;

      setState(() {
        _isLoadingPolygons = true;
      });

      try {
        final result = await LandService.getUserPolygons();

        if (result['success'] == true) {
          final polygonsData = result['polygons'] as List;
          final polygons = polygonsData
              .map((data) => data as Map<String, dynamic>)
              .toList();

          setState(() {
            _userPolygons = polygons;
          });

          // Display polygons on map
          await _displayUserPolygons();

          debugPrint('✅ Loaded ${polygons.length} user polygons');
        } else {
          final message = result['message'] ?? 'Unknown error';
          // Only log error, don't show to user if it's an auth error
          if (message.contains('token') || message.contains('authentication') || message.contains('Access denied')) {
            debugPrint('ℹ️ Authentication required to load polygons');
            // Clear potentially invalid token
            await _clearInvalidToken();
          } else {
            debugPrint('⚠️ Failed to load polygons: $message');
          }
        }
      } catch (e) {
        debugPrint('❌ Error loading polygons: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingPolygons = false;
          });
        }
      }
    }

    /// Clear invalid token from storage
    Future<void> _clearInvalidToken() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        // Check if token looks like a Firebase token (long JWT) vs our JWT (shorter)
        // Firebase tokens are typically longer, but we can't reliably detect
        // So we'll only clear on 401 errors
        await prefs.remove('auth_token');
        debugPrint('🧹 Cleared potentially invalid auth token');
      } catch (e) {
        debugPrint('⚠️ Error clearing token: $e');
      }
    }

    /// Display all user polygons on the map
    Future<void> _displayUserPolygons() async {
      if (mapboxMap == null || _userPolygons.isEmpty) return;

      try {
        // Create a FeatureCollection from all polygons
        // Each polygon is already a GeoJSON feature from the API
        final features = _userPolygons.map((polygon) => {
          'type': 'Feature',
          'geometry': polygon['geometry'],
          'properties': {
            'id': polygon['id'],
            'name': polygon['name'],
            'areaInAcres': polygon['areaInAcres'],
          },
        }).toList();

        final featureCollection = {
          'type': 'FeatureCollection',
          'features': features,
        };

        // Use a separate source for user polygons
        const sourceId = 'user-polygons-source';
        const fillLayerId = 'user-polygons-fill-layer';
        const lineLayerId = 'user-polygons-line-layer';

        final style = mapboxMap!.style;

        // Add source
        try {
          await style.addSource(GeoJsonSource(
            id: sourceId,
            data: jsonEncode(featureCollection),
          ));
        } catch (e) {
          // Source might already exist, update it
          await style.setStyleSourceProperty(
            sourceId,
            'data',
            jsonEncode(featureCollection),
          );
        }

        // Add fill layer
        try {
          await style.addLayer(
            FillLayer(
              id: fillLayerId,
              sourceId: sourceId,
              fillColor: Colors.blue.value,
              fillOpacity: 0.2,
            ),
          );
        } catch (e) {
          // Layer might already exist
        }

        // Add line layer
        try {
          await style.addLayer(
            LineLayer(
              id: lineLayerId,
              sourceId: sourceId,
              lineColor: Colors.blue.value,
              lineWidth: 2.0,
            ),
          );
        } catch (e) {
          // Layer might already exist
        }

        debugPrint('✅ Displayed ${_userPolygons.length} user polygons on map');
      } catch (e) {
        debugPrint('❌ Error displaying polygons: $e');
      }
    }


    /// Checks if a point is inside a polygon (Point-in-Polygon algorithm)
    /// Supports both Polygon and MultiPolygon geometries
    bool _isPointInPolygon(double lng, double lat, Map<String, dynamic> geometry) {
      final geometryType = geometry['type'] as String?;
      final coordinates = geometry['coordinates'] as dynamic;

      if (geometryType == 'Polygon') {
        // Polygon coordinates: [[[lng, lat], ...]]
        if (coordinates is List && coordinates.isNotEmpty) {
          final exteriorRing = coordinates[0] as List;
          return _pointInRing(lng, lat, exteriorRing);
        }
      } else if (geometryType == 'MultiPolygon') {
        // MultiPolygon coordinates: [[[[lng, lat], ...]]]
        if (coordinates is List) {
          for (final polygon in coordinates) {
            if (polygon is List && polygon.isNotEmpty) {
              final exteriorRing = polygon[0] as List;
              if (_pointInRing(lng, lat, exteriorRing)) {
                return true;
              }
            }
          }
        }
      }

      return false;
    }

    /// Ray casting algorithm to check if point is inside a ring
    bool _pointInRing(double lng, double lat, List ring) {
      bool inside = false;
      int j = ring.length - 1;

      for (int i = 0; i < ring.length; i++) {
        final pointI = ring[i] as List;
        final pointJ = ring[j] as List;
        
        final xi = (pointI[0] as num).toDouble();
        final yi = (pointI[1] as num).toDouble();
        final xj = (pointJ[0] as num).toDouble();
        final yj = (pointJ[1] as num).toDouble();

        final intersect = ((yi > lat) != (yj > lat)) &&
            (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
        
        if (intersect) {
          inside = !inside;
        }
        j = i;
      }

      return inside;
    }

    /// Shows bottom sheet with areas for a selected state
    void _showStateAreasBottomSheet(String stateKey) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => StateAreasBottomSheet(stateKey: stateKey),
      );
    }

    /// Handles "View Open States" button tap
    /// Animates camera to India and hides the button
    Future<void> _onViewOpenStatesTap() async {
      if (_hasClickedViewOpenStates) return; // Prevent double-tap
      
      setState(() {
        _hasClickedViewOpenStates = true;
      });

      // Animate button exit (fade + scale)
      setState(() {
        _showViewOpenStates = false;
      });

      // Wait for button animation to start, then zoom to India
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Zoom to India using the controller
      await WorldMapController.instance.zoomToIndia();
    }

    /// Resets the button state and camera when tab is switched back
    /// Called from MainScreen when Buy Land tab is selected
    void resetButtonState() {
      if (mounted) {
        setState(() {
          _hasClickedViewOpenStates = false;
          // Only show button if it was originally enabled
          _showViewOpenStates = widget.showViewOpenStatesButton;
        });
        
        // Reset camera to world view (0,0) zoom 0 - no animation
        if (mapboxMap != null) {
          mapboxMap!.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(0.0, 0.0),
              ),
              zoom: 0.0,
              bearing: 0,
              pitch: 0,
            ),
          );
        }
      }
    }

    /// Handles map creation errors
    /// Extracts detailed error message from MapLoadingErrorEventData
    void onMapError(Object error) {
      _loadingTimeout?.cancel();

      String errorMessage = "Failed to initialize map";

      // Try to extract detailed error message from MapLoadingErrorEventData
      try {
        // MapLoadingErrorEventData has a 'message' property
        // Use reflection or toString to get more details
        final errorString = error.toString();
        debugPrint('❌ Map creation error (full): $errorString');
        debugPrint('❌ Map creation error (type): ${error.runtimeType}');

        // Try to extract message if it's MapLoadingErrorEventData
        if (errorString.contains('message:')) {
          // Extract message from the error object
          final messageMatch =
              RegExp(r'message:\s*([^\n,}]+)').firstMatch(errorString);
          if (messageMatch != null) {
            errorMessage =
                "Failed to initialize map: ${messageMatch.group(1)?.trim()}";
          } else {
            errorMessage =
                "Failed to initialize map. Check your internet connection and Mapbox token configuration.";
          }
        } else {
          // Try to get more details using reflection-like approach
          // MapLoadingErrorEventData typically has: type, message, source
          errorMessage = "Failed to initialize map: $errorString";
        }
      } catch (e) {
        debugPrint('❌ Error extracting error message: $e');
        errorMessage =
            "Failed to initialize map. Please check your internet connection and try again.";
      }

      // Additional debugging
      final token = dotenv.env["MAPBOX_PUBLIC_TOKEN"];
      debugPrint('🔍 Debug info:');
      debugPrint('  - Token exists: ${token != null && token.isNotEmpty}');
      debugPrint(
          '  - Token starts with pk.: ${token?.startsWith("pk.") ?? false}');
      debugPrint('  - Token length: ${token?.length ?? 0}');

      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
          _isMapReady = false;
        });
      }
    }

    @override
    Widget build(BuildContext context) {
      final token = dotenv.env["MAPBOX_PUBLIC_TOKEN"];

      // Show error if token is invalid or map failed to load
      if (_errorMessage != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Map Configuration Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Retry button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isMapReady = false;
                    });
                    // Re-validate token
                    _validateMapboxToken();
                    _verifyTokenInNativeConfig();
                    // Reset timeout
                    _loadingTimeout?.cancel();
                    _loadingTimeout = Timer(const Duration(seconds: 15), () {
                      if (mounted && !_isMapReady && _errorMessage == null) {
                        setState(() {
                          _errorMessage =
                              "Map is taking too long to load. Please check your internet connection and try again.";
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                // Troubleshooting tips
                Card(
                  color: AppTheme.surfaceColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Troubleshooting Tips:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        buildTroubleshootingTip(
                            '1. Check your internet connection'),
                        buildTroubleshootingTip(
                            '2. Verify Mapbox token in assets/.env'),
                        buildTroubleshootingTip(
                            '3. Ensure token is in android/gradle.properties'),
                        buildTroubleshootingTip('4. Try restarting the app'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Show loading state while map initializes
      if (token == null || token.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      // Return the map widget directly without Scaffold/AppBar
      // The AppBar is provided by MainScreen parent
      // Note: Access token must be set globally via MapboxOptions.setAccessToken() in main.dart
      // AND configured natively in AndroidManifest.xml and Info.plist
      final mapWidget = MapWidget(
        key: const ValueKey('worldMapWidget'),
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: _onStyleLoaded,
        onMapLoadErrorListener: onMapError,
        onTapListener: _onMapTap,
        onCameraChangeListener: onCameraChange,
        cameraOptions: CameraOptions(
          center: Point(
            coordinates: Position(0.0, 0.0), // Center of the world
          ),
          zoom: 0.0, // Full world view
        ),
        styleUri: "mapbox://styles/arhaan21/cmj4vqiqa002901s6eb5bd9k0",
      );

      return Stack(
        children: [
          // Mapbox Map Widget
          mapWidget,
          // Loading indicator overlay
          if (!_isMapReady)
            Container(
              color: AppTheme.backgroundColor.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading world map...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          // "View Open States" floating button
          if (_showViewOpenStates && _isMapReady)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 96, // Above bottom nav (80 nav + 16 spacing)
              right: 16,
              child: _ViewOpenStatesButton(
                onTap: _onViewOpenStatesTap,
              ),
            ),
        ],
      );
    }

    /// Builds a troubleshooting tip widget
    Widget buildTroubleshootingTip(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• ',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

  }

  /// Glassmorphic floating button for "View Open States"
  class _ViewOpenStatesButton extends StatefulWidget {
    final VoidCallback onTap;

    const _ViewOpenStatesButton({
      required this.onTap,
    });

    @override
    State<_ViewOpenStatesButton> createState() => _ViewOpenStatesButtonState();
  }

  class _ViewOpenStatesButtonState extends State<_ViewOpenStatesButton>
      with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _opacityAnimation;
    late Animation<double> _scaleAnimation;
    bool _isExiting = false;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );

      _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );

      _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    void _handleTap() {
      if (_isExiting) return;
      _isExiting = true;
      _controller.forward().then((_) {
        widget.onTap();
      });
    }

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: _handleTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26), // ~24-28 radius
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.public,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View Open States',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }
