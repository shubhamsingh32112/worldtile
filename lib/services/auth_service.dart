import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  // Get the appropriate base URL based on the platform
  // Priority: .env file > platform detection
  // For physical devices, you MUST set API_BASE_URL in assets/.env
  // Example: API_BASE_URL=http://192.168.1.100:3000/api
  static String get baseUrl {
    // First, try to get from .env file (recommended for physical devices)
    try {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty && envUrl.trim().isNotEmpty) {
        // Debug: print the URL being used (remove in production)
        if (kDebugMode) {
          print('🌐 Using API_BASE_URL from .env: $envUrl');
        }
        return envUrl.trim();
      }
    } catch (e) {
      // .env not loaded or variable not set, fall back to platform detection
      if (kDebugMode) {
        print('⚠️ Could not load API_BASE_URL from .env: $e');
      }
    }
    
    // Debug: show which default is being used
    if (kDebugMode) {
      print('⚠️ API_BASE_URL not set in .env, using platform default');
    }

    // Fallback to platform-specific defaults
    if (kIsWeb) {
      // Web platform
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      // Android emulator - use 10.0.2.2 to access host machine
      // For physical Android device, you MUST set API_BASE_URL in .env
      // Example: API_BASE_URL=http://192.168.1.100:3000/api
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      // iOS simulator - localhost works
      // For physical iOS device, you MUST set API_BASE_URL in .env
      return 'http://localhost:3000/api';
    } else {
      // Desktop platforms
      return 'http://localhost:3000/api';
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': data['token'],
          'userId': data['user']['id'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'token': data['token'],
          'userId': data['user']['id'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Signup failed',
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

