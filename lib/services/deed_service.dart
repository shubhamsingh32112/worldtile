import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../models/deed_model.dart';

/// Service for interacting with the deeds API
class DeedService {
  static String get baseUrl => AuthService.baseUrl;

  /// Get authentication headers
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get deed by property ID (landSlotId)
  /// [propertyId] - The landSlotId of the property
  /// Returns: { success: bool, deed: DeedModel? }
  static Future<Map<String, dynamic>> getDeedByPropertyId({
    required String propertyId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/deeds/$propertyId');

      if (kDebugMode) {
        print('📜 Fetching deed for property: $propertyId');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Fetched deed successfully');
        }
        // Backend now returns { success: true, deed: {...} }
        // Handle both old format (direct deed) and new format (wrapped)
        final deedData = data['deed'] ?? data;
        return {
          'success': true,
          'deed': DeedModel.fromJson(deedData),
        };
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          print('❌ Deed not found: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Deed not found',
          'deed': null,
        };
      } else if (response.statusCode == 403) {
        if (kDebugMode) {
          print('❌ Access denied: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'You do not own this property',
          'deed': null,
        };
      } else {
        if (kDebugMode) {
          print('❌ Failed to fetch deed: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch deed',
          'deed': null,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching deed: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'deed': null,
      };
    }
  }
}

