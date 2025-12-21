import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for interacting with the land tiles API
class LandService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    // First, try to get from .env file (recommended for physical devices)
    try {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty && envUrl.trim().isNotEmpty) {
        if (kDebugMode) {
          print('🌐 Using API_BASE_URL from .env: $envUrl');
        }
        return envUrl.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load API_BASE_URL from .env: $e');
      }
    }
    
    if (kDebugMode) {
      print('⚠️ API_BASE_URL not set in .env, using platform default');
    }

    // Fallback to platform-specific defaults
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  /// Get authentication token from shared preferences
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting auth token: $e');
      }
      return null;
    }
  }

  /// Get headers with authentication if available
  static Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Get all land tiles
  /// Optional filters: region, status, minPrice, maxPrice
  static Future<Map<String, dynamic>> getTiles({
    String? region,
    String? status,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (region != null) queryParams['region'] = region;
      if (status != null) queryParams['status'] = status;
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();

      final uri = Uri.parse('$baseUrl/land/tiles').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'tiles': data['tiles'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch tiles',
          'tiles': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'tiles': [],
        'count': 0,
      };
    }
  }

  /// Get a specific land tile by tileId
  static Future<Map<String, dynamic>> getTile(String tileId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/land/tiles/$tileId'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'tile': data['tile'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Tile not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Get nearby land tiles using PostGIS
  /// Requires latitude, longitude, and optional radius in meters (default: 1000)
  static Future<Map<String, dynamic>> getNearbyTiles({
    required double lat,
    required double lng,
    int radius = 1000,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/land/nearby').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radius': radius.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'tiles': data['tiles'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch nearby tiles',
          'tiles': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'tiles': [],
        'count': 0,
      };
    }
  }

  /// Get user's owned land tiles (requires authentication)
  static Future<Map<String, dynamic>> getMyTiles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/land/my-tiles'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'tiles': data['tiles'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch your tiles',
          'tiles': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'tiles': [],
        'count': 0,
      };
    }
  }

  /// Purchase a land tile (requires authentication)
  static Future<Map<String, dynamic>> purchaseTile(String tileId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/land/tiles/$tileId/purchase'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'tile': data['tile'],
          'message': data['message'] ?? 'Tile purchased successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Purchase failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Save a polygon to the backend (requires authentication)
  static Future<Map<String, dynamic>> savePolygon({
    required Map<String, dynamic> geometry, // GeoJSON Polygon
    required double areaInAcres,
    String? name,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'geometry': geometry,
        'areaInAcres': areaInAcres,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/polygons'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'polygon': data['polygon'],
          'message': data['message'] ?? 'Polygon saved successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to save polygon',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Get all polygons for the authenticated user
  static Future<Map<String, dynamic>> getUserPolygons() async {
    try {
      final headers = await _getHeaders();
      final token = await _getToken();
      
      // Don't make request if no token
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required',
          'polygons': [],
          'count': 0,
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/polygons'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'polygons': data['polygons'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        // Authentication error - token is invalid
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid token. Access denied.',
          'polygons': [],
          'count': 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch polygons',
          'polygons': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'polygons': [],
        'count': 0,
      };
    }
  }

  /// Delete a polygon by ID
  static Future<Map<String, dynamic>> deletePolygon(String polygonId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/polygons/$polygonId'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Polygon deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete polygon',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}



