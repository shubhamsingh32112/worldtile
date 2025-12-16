import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for interacting with the orders API
class OrderService {
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

  /// Create a new order for buying virtual land
  /// [state] - State key (e.g., "karnataka")
  /// [place] - Area key (e.g., "whitefield")
  /// [landSlotId] - Land slot ID
  static Future<Map<String, dynamic>> createOrder({
    required String state,
    required String place,
    required String landSlotId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/orders/create');

      if (kDebugMode) {
        print('💰 Creating order for land slot: $landSlotId');
      }

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'state': state,
          'place': place,
          'landSlotId': landSlotId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (kDebugMode) {
          print('✅ Order created successfully: ${data['orderId']}');
        }
        return {
          'success': true,
          'orderId': data['orderId'],
          'amount': data['amount'],
          'address': data['address'],
          'network': data['network'],
        };
      } else {
        if (kDebugMode) {
          print('❌ Order creation failed: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create order',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating order: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Submit transaction hash for an order
  /// [orderId] - Order ID
  /// [txHash] - Transaction hash
  static Future<Map<String, dynamic>> submitTransactionHash({
    required String orderId,
    required String txHash,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/orders/submit-tx');

      if (kDebugMode) {
        print('📝 Submitting transaction hash for order: $orderId');
      }

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'orderId': orderId,
          'txHash': txHash,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Transaction hash submitted successfully');
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Transaction submitted successfully',
        };
      } else {
        if (kDebugMode) {
          print('❌ Transaction hash submission failed: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to submit transaction hash',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error submitting transaction hash: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}

