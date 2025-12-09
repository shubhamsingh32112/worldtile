import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Represents a place search result from Mapbox Geocoding API
class PlaceResult {
  final String id;
  final String name;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? context;
  final double relevance;

  PlaceResult({
    required this.id,
    required this.name,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.context,
    required this.relevance,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final properties = json['properties'] as Map<String, dynamic>?;
    final context = json['context'] as List<dynamic>?;

    // Extract location context (city, state, country)
    String? contextString;
    if (context != null && context.isNotEmpty) {
      final contextList = context
          .map((c) => (c as Map<String, dynamic>?)?['text'])
          .whereType<String>()
          .toList();
      if (contextList.isNotEmpty) {
        contextString = contextList.join(', ');
      }
    }

    return PlaceResult(
      id: json['id'] as String,
      name: properties?['name'] as String? ?? json['text'] as String,
      placeName: json['place_name'] as String,
      latitude: (geometry['coordinates'] as List<dynamic>)[1] as double,
      longitude: (geometry['coordinates'] as List<dynamic>)[0] as double,
      context: contextString,
      relevance: (json['relevance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Service for geocoding and place search using Mapbox Geocoding API
class GeocodingService {
  // Base URL for Mapbox Geocoding API
  static const String _geocodingBaseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Get Mapbox access token from .env file
  static String? get _mapboxToken {
    try {
      return dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load MAPBOX_PUBLIC_TOKEN from .env: $e');
      }
      return null;
    }
  }

  /// Search for places using Mapbox Geocoding API
  /// 
  /// [query] - The search query (e.g., "rt nagar", "New York", etc.)
  /// [limit] - Maximum number of results to return (default: 5)
  /// [proximity] - Bias results to a specific location (optional)
  /// 
  /// Returns a list of PlaceResult objects sorted by relevance
  static Future<Map<String, dynamic>> searchPlaces(
    String query, {
    int limit = 5,
    Map<String, double>? proximity,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Search query cannot be empty',
          'places': <PlaceResult>[],
        };
      }

      final token = _mapboxToken;
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Mapbox token not configured',
          'places': <PlaceResult>[],
        };
      }

      // Build query parameters
      final queryParams = <String, String>{
        'access_token': token,
        'limit': limit.toString(),
        'types': 'place,locality,neighborhood,address,poi', // Restrict to specific types
      };

      // Add proximity if provided (format: "longitude,latitude")
      if (proximity != null && proximity.containsKey('lng') && proximity.containsKey('lat')) {
        queryParams['proximity'] = '${proximity['lng']},${proximity['lat']}';
      }

      // Encode the search query
      final encodedQuery = Uri.encodeComponent(query.trim());
      final uri = Uri.parse('$_geocodingBaseUrl/$encodedQuery.json').replace(
        queryParameters: queryParams,
      );

      if (kDebugMode) {
        print('🔍 Searching for places: $query');
        print('🌐 Geocoding API URL: ${uri.toString().replaceAll(token, 'TOKEN_HIDDEN')}');
      }

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        final places = features
            .map((feature) => PlaceResult.fromJson(feature as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          print('✅ Found ${places.length} places for query: $query');
        }

        return {
          'success': true,
          'places': places,
          'query': query,
        };
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 'Failed to search places';

        if (kDebugMode) {
          print('❌ Geocoding API error: ${response.statusCode} - $errorMessage');
        }

        return {
          'success': false,
          'message': errorMessage,
          'places': <PlaceResult>[],
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Geocoding service error: $e');
      }

      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'places': <PlaceResult>[],
      };
    }
  }

  /// Geocode coordinates to a place name (reverse geocoding)
  /// 
  /// [lng] - Longitude
  /// [lat] - Latitude
  /// 
  /// Returns a PlaceResult for the given coordinates
  static Future<Map<String, dynamic>> reverseGeocode(
    double lng,
    double lat,
  ) async {
    try {
      final token = _mapboxToken;
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Mapbox token not configured',
          'place': null,
        };
      }

      final uri = Uri.parse('$_geocodingBaseUrl/$lng,$lat.json').replace(
        queryParameters: {
          'access_token': token,
          'limit': '1',
        },
      );

      if (kDebugMode) {
        print('🔍 Reverse geocoding: ($lng, $lat)');
      }

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        if (features.isNotEmpty) {
          final place = PlaceResult.fromJson(features[0] as Map<String, dynamic>);
          return {
            'success': true,
            'place': place,
          };
        } else {
          return {
            'success': false,
            'message': 'No place found for the given coordinates',
            'place': null,
          };
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 'Failed to reverse geocode';

        return {
          'success': false,
          'message': errorMessage,
          'place': null,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reverse geocoding error: $e');
      }

      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'place': null,
      };
    }
  }
}

