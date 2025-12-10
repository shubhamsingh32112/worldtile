import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../widgets/map_search_bar.dart';
import '../../widgets/map/draw_rectangle_button.dart';
import '../../widgets/map/rectangle_controls.dart';
import '../../services/land_service.dart';
import 'rectangle_drawing/rectangle_drawing_controller.dart';
import 'rectangle_drawing/rectangle_model.dart';

/// WorldMapPage displays a full world map using Mapbox Maps SDK
/// 
/// This widget shows a world map view with:
/// - Full world view (zoom level 0)
/// - Centered at coordinates (0, 0)
/// - Uses Mapbox Streets style
/// - Loads Mapbox token from .env file
class WorldMapPage extends StatefulWidget {
  const WorldMapPage({super.key});

  @override
  State<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage> {
  MapboxMap? mapboxMap;
  bool _isMapReady = false;
  bool _isLocationEnabled = false;
  String? _errorMessage;
  Timer? _loadingTimeout;
  bool _hasAppliedCustomFog = false;
  
  // Rectangle drawing state
  RectangleDrawingController? _rectangleController;
  double _currentZoom = 0.0;
  
  // User polygons state
  List<RectangleModel> _userPolygons = [];
  bool _isLoadingPolygons = false;

  @override
  void initState() {
    super.initState();
    _validateMapboxToken();
    _requestLocationPermission();
    _verifyTokenInNativeConfig();
    // Set a timeout to show error if map doesn't load within 15 seconds
    _loadingTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && !_isMapReady && _errorMessage == null) {
        setState(() {
          _errorMessage = "Map is taking too long to load. Please check your internet connection and try again.";
        });
      }
    });
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
      debugPrint('  - Token format: ${token.startsWith("pk.") ? "Valid (public token)" : "Invalid"}');
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
        _errorMessage = "Invalid Mapbox token. Must start with 'pk.' (public token)";
      });
      return;
    }
  }

  /// Request location permission
  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _isLocationEnabled = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLocationEnabled = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationEnabled = false;
        });
      }
    }
  }

  /// Called when the map is successfully created
  void _onMapCreated(MapboxMap mapboxMapController) async {
    if (!mounted) return;
    
    debugPrint('🗺️ Map created successfully');
    
    setState(() {
      mapboxMap = mapboxMapController;
    });

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

    // Enable location component if permission is granted
    if (_isLocationEnabled) {
      try {
        await mapboxMapController.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            locationPuck: LocationPuck(
              locationPuck2D: LocationPuck2D(
                topImage: null,
                bearingImage: null,
                shadowImage: null,
                scaleExpression: null,
              ),
            ),
          ),
        );
        debugPrint('✅ Location component enabled');
      } catch (e) {
        // Location component may not be available on all platforms
        if (mounted) {
          debugPrint('⚠️ Location component error: $e');
        }
      }
    }
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
    
    // Initialize rectangle drawing controller after style is ready
    if (_rectangleController == null && currentMap != null) {
      try {
        _rectangleController = RectangleDrawingController();
        await _rectangleController!.init(currentMap);
        
        // Get initial camera state
        final cameraState = await currentMap.getCameraState();
        if (mounted) {
          setState(() {
            _currentZoom = cameraState.zoom;
          });
        }
        
        debugPrint('✅ Rectangle drawing controller initialized');
      } catch (e) {
        debugPrint('⚠️ Error initializing rectangle controller: $e');
      }
    }
    
    // Load user polygons when map is ready
    await _loadUserPolygons();
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
        'range': [0.8, 8.0], // Keep distant fading but remove near-camera haze
        'color': 'rgba(0, 0, 0, 0)', // No low-atmosphere tint
        'high-color': 'rgba(0, 0, 0, 0)', // No upper-atmosphere glow
        'horizon-blend': 0.0, // Sharp horizon to remove halo
        'space-color': 'rgb(5, 5, 15)', // Darker space backdrop
        'star-intensity': 0.25, // Dimmer stars (default is 0.35, reduced from 0.85)
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
      for (final layer in layers) {
        try {
          // Get layer type - check if it's a symbol layer by checking for text properties
          final layerId = layer.id;
          
          // Try to get layer type property to determine if it's a symbol layer
          try {
            final layerType = await style.getStyleLayerProperty(layerId, 'type');
            
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
              debugPrint('  ✅ Removed halo from layer: $layerId (type unknown)');
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

  /// Zoom to a specific location on the map
  /// 
  /// [latitude] - Target latitude
  /// [longitude] - Target longitude
  /// [zoom] - Target zoom level (default: 12.0 for city level)
  /// [duration] - Animation duration in milliseconds (default: 1500)
  Future<void> _zoomToLocation(
    double latitude,
    double longitude, {
    double zoom = 12.0,
    int duration = 1500,
  }) async {
    final currentMap = mapboxMap;
    if (currentMap == null) {
      debugPrint('⚠️ Cannot zoom: Map not ready');
      return;
    }

    try {
      debugPrint('📍 Zooming to location: ($latitude, $longitude) at zoom level $zoom');

      // Create camera options for the target location
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(longitude, latitude),
        ),
        zoom: zoom,
      );

      // Animate camera to the location
      await currentMap.flyTo(
        cameraOptions,
        MapAnimationOptions(
          duration: duration,
          startDelay: 0,
        ),
      );

      debugPrint('✅ Successfully zoomed to location');
    } catch (e) {
      debugPrint('❌ Error zooming to location: $e');
    }
  }

  /// Handles place selection from search bar
  /// Zooms to the selected place location
  void _onPlaceSelected(double latitude, double longitude) {
    debugPrint('🎯 Place selected: ($latitude, $longitude)');
    _zoomToLocation(latitude, longitude);
  }

  /// Handles map tap events for rectangle placement
  void _onMapTap(MapContentGestureContext context) async {
    if (_rectangleController == null || !_rectangleController!.isInitialized) {
      return;
    }

    // Only handle taps if in placement mode
    if (_rectangleController!.isPlacementMode) {
      final position = Position(
        context.point.coordinates.lng,
        context.point.coordinates.lat,
      );

      debugPrint('📍 Placing rectangle at: (${position.lng}, ${position.lat})');
      
      try {
        await _rectangleController!.placeAt(position);
        
        if (mounted) {
          setState(() {
            // Trigger UI rebuild to show rectangle controls
          });
        }
      } catch (e) {
        debugPrint('❌ Error placing rectangle: $e');
      }
    }
  }

  /// Handles camera change events to track zoom level
  void _onCameraChange(CameraChangedEventData data) async {
    if (mapboxMap == null) return;

    try {
      final cameraState = await mapboxMap!.getCameraState();
      if (mounted) {
        setState(() {
          _currentZoom = cameraState.zoom;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error getting camera state: $e');
    }
  }

  /// Handles draw button press to enter placement mode
  void _onDrawButtonPressed() {
    if (_rectangleController == null || !_rectangleController!.isInitialized) {
      debugPrint('⚠️ Rectangle controller not initialized');
      return;
    }

    _rectangleController!.enterPlacementMode();

    if (mounted) {
      setState(() {
        // Trigger UI rebuild
      });
    }
    
    debugPrint('🎨 Entered rectangle placement mode');
  }

  /// Handles rectangle delete action
  Future<void> _onDeleteRectangle() async {
    if (_rectangleController == null) return;

    try {
      await _rectangleController!.clear();
      
      if (mounted) {
        setState(() {
          // Trigger UI rebuild
        });
      }
      
      debugPrint('🗑️ Rectangle deleted');
    } catch (e) {
      debugPrint('❌ Error deleting rectangle: $e');
    }
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
            .map((data) => RectangleModel.fromMongoData(data))
            .toList();
        
        setState(() {
          _userPolygons = polygons;
        });
        
        // Display polygons on map
        await _displayUserPolygons();
        
        debugPrint('✅ Loaded ${polygons.length} user polygons');
      } else {
        debugPrint('⚠️ Failed to load polygons: ${result['message']}');
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

  /// Display all user polygons on the map
  Future<void> _displayUserPolygons() async {
    if (mapboxMap == null || _userPolygons.isEmpty) return;
    
    try {
      // Create a FeatureCollection from all polygons
      final features = _userPolygons
          .map((polygon) => polygon.toGeoJsonFeature())
          .toList();
      
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

  /// Save the current rectangle as a polygon
  Future<void> _saveCurrentRectangle() async {
    if (_rectangleController?.rectangle == null) {
      debugPrint('⚠️ No rectangle to save');
      return;
    }
    
    final rectangle = _rectangleController!.rectangle!;
    final geoJson = rectangle.toGeoJsonFeature()['geometry'] as Map<String, dynamic>;
    
    try {
      final result = await LandService.savePolygon(
        geometry: geoJson,
        areaInAcres: rectangle.areaInAcres,
        name: 'My Polygon ${DateTime.now().toString().substring(0, 10)}',
      );
      
      if (result['success'] == true) {
        // Reload polygons to get the updated list
        await _loadUserPolygons();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Polygon saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        debugPrint('✅ Polygon saved successfully');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save polygon: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving polygon: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving polygon: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handles map creation errors
  /// Extracts detailed error message from MapLoadingErrorEventData
  void _onMapError(Object error) {
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
        final messageMatch = RegExp(r'message:\s*([^\n,}]+)').firstMatch(errorString);
        if (messageMatch != null) {
          errorMessage = "Failed to initialize map: ${messageMatch.group(1)?.trim()}";
        } else {
          errorMessage = "Failed to initialize map. Check your internet connection and Mapbox token configuration.";
        }
      } else {
        // Try to get more details using reflection-like approach
        // MapLoadingErrorEventData typically has: type, message, source
        errorMessage = "Failed to initialize map: $errorString";
      }
    } catch (e) {
      debugPrint('❌ Error extracting error message: $e');
      errorMessage = "Failed to initialize map. Please check your internet connection and try again.";
    }
    
    // Additional debugging
    final token = dotenv.env["MAPBOX_PUBLIC_TOKEN"];
    debugPrint('🔍 Debug info:');
    debugPrint('  - Token exists: ${token != null && token.isNotEmpty}');
    debugPrint('  - Token starts with pk.: ${token?.startsWith("pk.") ?? false}');
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
                        _errorMessage = "Map is taking too long to load. Please check your internet connection and try again.";
                      });
                    }
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      _buildTroubleshootingTip('1. Check your internet connection'),
                      _buildTroubleshootingTip('2. Verify Mapbox token in assets/.env'),
                      _buildTroubleshootingTip('3. Ensure token is in android/gradle.properties'),
                      _buildTroubleshootingTip('4. Try restarting the app'),
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
    return Stack(
      children: [
        // Mapbox Map Widget
        MapWidget(
          key: const ValueKey('worldMapWidget'),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          onMapLoadErrorListener: _onMapError,
          onTapListener: _onMapTap,
          onCameraChangeListener: _onCameraChange,
          cameraOptions: CameraOptions(
            center: Point(
              coordinates: Position(0.0, 0.0), // Center of the world
            ),
            zoom: 0.0, // Full world view
          ),
          styleUri: "mapbox://styles/arhaan21/cmiz2ed9a003301sacraodhpo",
        ),
        // Search bar overlay
        if (_isMapReady)
          MapSearchBar(
            onPlaceSelected: _onPlaceSelected,
            hintText: 'Search for a place (e.g., rt nagar, Bangalore)',
          ),
        // Rectangle drawing button (only visible when zoomed in enough)
        if (_isMapReady && _currentZoom >= 12.0)
          DrawRectangleButton(
            currentZoom: _currentZoom,
            isPlacementMode: _rectangleController?.isPlacementMode ?? false,
            onPressed: _onDrawButtonPressed,
          ),
        // Rectangle controls (only visible when rectangle exists)
        if (_isMapReady && _rectangleController?.rectangle != null)
          RectangleControls(
            rectangle: _rectangleController!.rectangle,
            onDelete: _onDeleteRectangle,
            onSave: _saveCurrentRectangle,
          ),
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
      ],
    );
  }

  /// Builds a troubleshooting tip widget
  Widget _buildTroubleshootingTip(String text) {
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

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _rectangleController?.dispose();
    mapboxMap?.dispose();
    super.dispose();
  }
}

