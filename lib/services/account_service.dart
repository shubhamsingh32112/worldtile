import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';
import 'auth_service.dart';

/// Service for account-related API calls
class AccountService {
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

  /// Get current user's full account data
  /// Returns UserAccount model with profile, agent info, and referral stats
  static Future<UserAccount> getMyAccount() async {
    try {
      final uri = Uri.parse('$baseUrl/users/me');

      if (kDebugMode) {
        print('👤 Fetching account data');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (kDebugMode) {
          print('✅ Account data fetched successfully');
        }

        return UserAccount.fromJson(data);
      } else if (response.statusCode == 401) {
        // Unauthorized - token expired or invalid
        if (kDebugMode) {
          print('❌ Unauthorized - token expired');
        }
        throw AccountException('Unauthorized. Please login again.', 401);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'Failed to fetch account data';
        
        if (kDebugMode) {
          print('❌ Failed to fetch account: $message');
        }
        throw AccountException(message, response.statusCode);
      }
    } catch (e) {
      if (e is AccountException) {
        rethrow;
      }
      
      if (kDebugMode) {
        print('❌ Error fetching account: $e');
      }
      throw AccountException('Connection error: ${e.toString()}', 0);
    }
  }

  /// Add referral code (ONE TIME ONLY)
  /// Throws AccountException with specific error codes:
  /// - 403: Referral already set
  /// - 400: Invalid referral code or validation failed
  static Future<UserAccount> addReferralCode(String code) async {
    try {
      if (code.trim().isEmpty) {
        throw AccountException('Referral code cannot be empty', 400);
      }

      final uri = Uri.parse('$baseUrl/users/add-referral');
      final normalizedCode = code.trim().toUpperCase();

      if (kDebugMode) {
        print('🔗 Adding referral code: $normalizedCode');
      }

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'referralCode': normalizedCode,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Referral code added successfully');
        }

        // Return updated user account
        return UserAccount.fromJson(data['user'] as Map<String, dynamic>);
      } else if (response.statusCode == 403) {
        // Referral already set
        final message = data['message'] as String? ?? 'Referral code already set';
        if (kDebugMode) {
          print('🔒 $message');
        }
        throw AccountException(message, 403);
      } else if (response.statusCode == 400) {
        // Invalid referral code or validation failed
        final message = data['message'] as String? ?? 'Invalid referral code';
        if (kDebugMode) {
          print('❌ $message');
        }
        throw AccountException(message, 400);
      } else if (response.statusCode == 401) {
        // Unauthorized
        throw AccountException('Unauthorized. Please login again.', 401);
      } else {
        final message = data['message'] as String? ?? 'Failed to add referral code';
        if (kDebugMode) {
          print('❌ $message');
        }
        throw AccountException(message, response.statusCode);
      }
    } catch (e) {
      if (e is AccountException) {
        rethrow;
      }
      
      if (kDebugMode) {
        print('❌ Error adding referral code: $e');
      }
      throw AccountException('Connection error: ${e.toString()}', 0);
    }
  }
}

/// Exception class for account service errors
class AccountException implements Exception {
  final String message;
  final int statusCode;

  AccountException(this.message, this.statusCode);

  @override
  String toString() => message;

  /// Check if error is due to referral already being set
  bool get isReferralLocked => statusCode == 403;

  /// Check if error is due to invalid referral code
  bool get isInvalidReferral => statusCode == 400;

  /// Check if error is due to unauthorized access
  bool get isUnauthorized => statusCode == 401;
}

