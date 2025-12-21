import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Service for user-related API calls
class UserService {
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

  /// Get user statistics (lands owned count, referral earnings)
  /// Returns: { success: bool, stats: { landsOwned: int, referralEarningsUSDT: String } }
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final uri = Uri.parse('$baseUrl/user/stats');

      if (kDebugMode) {
        print('📊 Fetching user stats');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout: Connection timed out after 15 seconds');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Fetched user stats: ${data['stats']}');
        }
        return {
          'success': true,
          'stats': data['stats'] ?? {
            'landsOwned': 0,
            'referralEarningsUSDT': '0',
          },
        };
      } else {
        if (kDebugMode) {
          print('❌ Failed to fetch user stats: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch user stats',
          'stats': {
            'landsOwned': 0,
            'referralEarningsUSDT': '0',
          },
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching user stats: $e');
      }
      String errorMessage = 'Connection error';
      if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
        errorMessage = 'Connection timeout: Please check your network connection and try again';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error: Unable to reach server. Please check your connection';
      } else {
        errorMessage = 'Connection error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
        'stats': {
          'landsOwned': 0,
          'referralEarningsUSDT': '0',
        },
      };
    }
  }

  /// Get all lands owned by the authenticated user
  /// Returns: { success: bool, lands: List<Map>, count: int }
  static Future<Map<String, dynamic>> getUserLands() async {
    try {
      final uri = Uri.parse('$baseUrl/user/lands');

      if (kDebugMode) {
        print('🏞️ Fetching user lands');
        print('🌐 Request URL: $uri');
        print('🌐 BASE URL: $baseUrl');
      }

      final headers = await _getHeaders();
      if (kDebugMode) {
        print('🔑 Auth token present: ${headers.containsKey('Authorization')}');
      }

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 30), // Increased timeout for slower connections
        onTimeout: () {
          if (kDebugMode) {
            print('⏱️ Request timeout after 30 seconds');
            print('🌐 Failed URL: $uri');
            print('💡 TROUBLESHOOTING:');
            print('   1. Ensure backend is running: npm run dev in backend/');
            print('   2. Verify backend URL: $baseUrl');
            print('   3. Check firewall allows connections on port 3000');
            print('   4. Ensure phone and computer are on same WiFi network');
          }
          throw Exception('Request timeout: Connection timed out after 30 seconds. Check if backend server is running.');
        },
      );

      if (kDebugMode) {
        print('📡 Response status: ${response.statusCode}');
        print('📡 Response length: ${response.body.length} bytes');
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Fetched ${data['count'] ?? 0} land(s)');
        }
        return {
          'success': true,
          'lands': data['lands'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        if (kDebugMode) {
          print('❌ Failed to fetch user lands: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch user lands',
          'lands': [],
          'count': 0,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching user lands: $e');
        print('🌐 BASE URL was: $baseUrl');
        print('🌐 Full URL was: ${baseUrl}/user/lands');
      }
      String errorMessage = 'Connection error';
      if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
        errorMessage = 'Connection timeout: Please check your network connection and server status';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error: Unable to reach server. Please check your connection and ensure the backend is running';
      } else {
        errorMessage = 'Connection error: ${e.toString()}';
      }
      return {
        'success': false,
        'message': errorMessage,
        'lands': [],
        'count': 0,
      };
    }
  }
}

