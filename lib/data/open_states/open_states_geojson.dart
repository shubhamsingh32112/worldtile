import 'dart:convert';
import 'package:flutter/services.dart';

/// Cached GeoJSON data (loaded once, reused)
Map<String, dynamic>? _cachedOpenStatesGeoJson;

/// Loads and returns the open states GeoJSON FeatureCollection
/// 
/// This method reads the static JSON file and returns it as a Map.
/// The file contains multiple state polygons that represent open regions.
/// 
/// Returns a Map<String, dynamic> representing a GeoJSON FeatureCollection
/// with multiple features, each representing a state boundary.
Future<Map<String, dynamic>> loadOpenStatesGeoJson() async {
  // Return cached data if available
  if (_cachedOpenStatesGeoJson != null) {
    return _cachedOpenStatesGeoJson!;
  }

  try {
    // Load the static JSON file (configured in pubspec.yaml)
    final String jsonString = await rootBundle.loadString(
      'lib/data/open_states/open_states_level1.json',
    );
    final Map<String, dynamic> geojson = jsonDecode(jsonString) as Map<String, dynamic>;
    
    // Validate structure
    if (geojson['type'] != 'FeatureCollection') {
      throw Exception('Invalid GeoJSON: expected FeatureCollection');
    }
    if (geojson['features'] == null) {
      throw Exception('Invalid GeoJSON: missing features array');
    }
    
    // Cache the result
    _cachedOpenStatesGeoJson = geojson;
    return geojson;
  } catch (e) {
    throw Exception('Failed to load open states GeoJSON: $e');
  }
}
