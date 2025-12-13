import 'dart:convert';

/// Creates a world bounds polygon with coordinates:
/// - Longitude: -180 → 180
/// - Latitude: -85 → 85 (NOT ±90 — globe math breaks there)
/// 
/// The polygon is counter-clockwise and closed.
/// This represents the outer shell of the world.
/// 
/// Returns a list of coordinates in GeoJSON format: [[lng, lat], ...]
List<List<double>> createWorldBoundsPolygon() {
  // Counter-clockwise polygon starting from bottom-left
  // Format: [longitude, latitude]
  return [
    [-180.0, -85.0],  // Bottom-left
    [180.0, -85.0],   // Bottom-right
    [180.0, 85.0],    // Top-right
    [-180.0, 85.0],   // Top-left
    [-180.0, -85.0],  // Close polygon (back to start)
  ];
}

/// Extracts outer rings from open states GeoJSON.
/// 
/// Supports both Polygon and MultiPolygon geometries.
/// Ignores inner rings (we don't want holes inside holes).
/// 
/// [openStatesGeoJson] - The FeatureCollection from loadOpenStatesGeoJson()
/// 
/// Returns a list of coordinate rings, each representing an outer boundary.
List<List<List<double>>> extractOuterRings(Map<String, dynamic> openStatesGeoJson) {
  final List<List<List<double>>> outerRings = [];
  
  if (openStatesGeoJson['type'] != 'FeatureCollection') {
    return outerRings;
  }
  
  final features = openStatesGeoJson['features'] as List<dynamic>?;
  if (features == null) {
    return outerRings;
  }
  
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;
    
    final geometryType = geometry['type'] as String?;
    if (geometryType == null) continue;
    
    final coordinates = geometry['coordinates'] as dynamic;
    if (coordinates == null) continue;
    
    if (geometryType == 'Polygon') {
      // Polygon: coordinates is [[[lng, lat], ...]] (array of rings)
      // First ring is outer, rest are inner (holes) - we only want outer
      if (coordinates is List && coordinates.isNotEmpty) {
        final outerRing = coordinates[0] as List<dynamic>?;
        if (outerRing != null) {
          // Convert to List<List<double>>
          final ring = outerRing
              .map((coord) {
                final coordList = coord as List;
                return [
                  (coordList[0] as num).toDouble(),
                  (coordList[1] as num).toDouble(),
                ];
              })
              .toList()
              .cast<List<double>>();
          outerRings.add(ring);
        }
      }
    } else if (geometryType == 'MultiPolygon') {
      // MultiPolygon: coordinates is [[[[lng, lat], ...], ...], ...]
      // Each polygon has rings, first ring is outer
      if (coordinates is List) {
        for (final polygon in coordinates) {
          if (polygon is List && polygon.isNotEmpty) {
            final outerRing = polygon[0] as List<dynamic>?;
            if (outerRing != null) {
              // Convert to List<List<double>>
              final ring = outerRing
                  .map((coord) {
                    final coordList = coord as List;
                    return [
                      (coordList[0] as num).toDouble(),
                      (coordList[1] as num).toDouble(),
                    ];
                  })
                  .toList()
                  .cast<List<double>>();
              outerRings.add(ring);
            }
          }
        }
      }
    }
  }
  
  return outerRings;
}

/// Builds the inverse (locked) GeoJSON FeatureCollection.
/// 
/// Creates a single Polygon feature where:
/// - First ring → world bounds (outer shell)
/// - All following rings → open state rings (holes)
/// 
/// This represents "Everything except the open states".
/// 
/// [openStatesGeoJson] - The FeatureCollection from loadOpenStatesGeoJson()
/// 
/// Returns a Map<String, dynamic> representing a GeoJSON FeatureCollection
/// with ONE feature containing the inverse polygon.
Map<String, dynamic> buildInverseGeoJson(Map<String, dynamic> openStatesGeoJson) {
  // Create world bounds polygon (outer shell)
  final worldBounds = createWorldBoundsPolygon();
  
  // Extract outer rings from open states (these become holes)
  final openStateRings = extractOuterRings(openStatesGeoJson);
  
  // Build polygon coordinates: [worldBounds, ...openStateRings]
  final polygonCoordinates = [worldBounds, ...openStateRings];
  
  // Create the feature
  final feature = {
    'type': 'Feature',
    'geometry': {
      'type': 'Polygon',
      'coordinates': polygonCoordinates,
    },
    'properties': {
      'locked': true,
    },
  };
  
  // Create FeatureCollection
  return {
    'type': 'FeatureCollection',
    'features': [feature],
  };
}

