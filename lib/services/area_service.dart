import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for interacting with the states and areas API
class AreaService {
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

  /// Get all areas for a specific state
  /// Returns list of areas with remaining slots, total slots, and price
  static Future<Map<String, dynamic>> getAreasForState(String stateKey) async {
    try {
      final normalizedStateKey = stateKey.toLowerCase().trim();
      final uri = Uri.parse('$baseUrl/states/$normalizedStateKey/areas');

      if (kDebugMode) {
        print('🔍 Fetching areas for state: $normalizedStateKey');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> areasList = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('✅ Found ${areasList.length} areas for state: $normalizedStateKey');
        }

        return {
          'success': true,
          'areas': areasList,
          'count': areasList.length,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch areas',
          'areas': [],
          'count': 0,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching areas: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'areas': [],
        'count': 0,
      };
    }
  }

  /// Get area details by areaKey
  /// Returns full area object including highlights
  static Future<Map<String, dynamic>> getAreaDetails(String areaKey) async {
    try {
      final normalizedAreaKey = areaKey.toLowerCase().trim();
      final uri = Uri.parse('$baseUrl/areas/$normalizedAreaKey');

      if (kDebugMode) {
        print('🔍 Fetching area details: $normalizedAreaKey');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('✅ Area details fetched: ${data['areaName']}');
        }

        return {
          'success': true,
          'area': data,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Area not found',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching area details: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Get an available land slot for an area (requires authentication)
  /// [areaKey] - The area key
  static Future<Map<String, dynamic>> getAvailableSlot({
    required String areaKey,
  }) async {
    try {
      final normalizedAreaKey = areaKey.toLowerCase().trim();
      final uri = Uri.parse('$baseUrl/areas/$normalizedAreaKey/available-slot');

      if (kDebugMode) {
        print('🔍 Getting available slot for area: $normalizedAreaKey');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Available slot found: ${data['landSlot']['landSlotId']}');
        }
        return {
          'success': true,
          'landSlot': data['landSlot'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'No available slot found',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting available slot: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Get multiple available land slots for an area (requires authentication)
  /// [areaKey] - The area key
  /// [quantity] - Number of slots to get (default: 1)
  static Future<Map<String, dynamic>> getAvailableSlots({
    required String areaKey,
    required int quantity,
  }) async {
    try {
      final normalizedAreaKey = areaKey.toLowerCase().trim();
      final uri = Uri.parse('$baseUrl/areas/$normalizedAreaKey/available-slots')
          .replace(queryParameters: {'quantity': quantity.toString()});

      if (kDebugMode) {
        print('🔍 Getting $quantity available slot(s) for area: $normalizedAreaKey');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Available slots found: ${data['count']}');
        }
        return {
          'success': true,
          'landSlots': data['landSlots'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'No available slots found',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting available slots: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Buy a tile for an area (requires authentication)
  /// [areaKey] - The area key
  /// [quantity] - Number of tiles to buy (default: 1)
  static Future<Map<String, dynamic>> buyTile({
    required String areaKey,
    int quantity = 1,
  }) async {
    try {
      final normalizedAreaKey = areaKey.toLowerCase().trim();
      final uri = Uri.parse('$baseUrl/areas/$normalizedAreaKey/buy');

      if (kDebugMode) {
        print('💰 Purchasing $quantity tile(s) for area: $normalizedAreaKey');
      }

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'quantity': quantity,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Tile purchase successful');
        }
        return {
          'success': true,
          'area': data['area'],
          'purchase': data['purchase'],
          'message': data['message'] ?? 'Tile purchased successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Purchase failed',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error purchasing tile: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}

