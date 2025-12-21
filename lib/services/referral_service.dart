import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Service for referral-related API calls
class ReferralService {
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

  /// Get referral earnings with "real estate agent" feel
  /// Returns: { success: bool, summary: {...}, propertiesSold: [...] }
  static Future<Map<String, dynamic>> getReferralEarnings() async {
    try {
      final uri = Uri.parse('$baseUrl/referrals/earnings');

      if (kDebugMode) {
        print('💰 Fetching referral earnings');
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Fetched referral earnings');
        }
        return {
          'success': true,
          'summary': data['summary'] ?? {},
          'propertiesSold': data['propertiesSold'] ?? [],
        };
      } else {
        if (kDebugMode) {
          print('❌ Failed to fetch referral earnings: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch referral earnings',
          'summary': {},
          'propertiesSold': [],
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching referral earnings: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
        'summary': {},
        'propertiesSold': [],
      };
    }
  }

  /// Store pending referral code before Google sign-in
  /// This is needed because Google OAuth doesn't allow query params reliably
  static Future<void> storePendingReferralCode(String referralCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_referral_code', referralCode.trim().toUpperCase());
      if (kDebugMode) {
        print('📝 Stored pending referral code: $referralCode');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error storing referral code: $e');
      }
    }
  }

  /// Clear pending referral code
  static Future<void> clearPendingReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');
      if (kDebugMode) {
        print('🗑️ Cleared pending referral code');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing referral code: $e');
      }
    }
  }

  /// Extract referral code from URL
  /// Supports formats: ?ref=CODE, ?referral=CODE, ?referralCode=CODE
  static String? extractReferralCodeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Check multiple possible parameter names
      return uri.queryParameters['ref'] ?? 
             uri.queryParameters['referral'] ?? 
             uri.queryParameters['referralCode'];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error extracting referral code from URL: $e');
      }
      return null;
    }
  }

  /// Request withdrawal of earnings
  /// TODO: Implement when backend endpoint is available
  static Future<Map<String, dynamic>> requestWithdrawal({
    required String amount,
    required String walletAddress,
  }) async {
    try {
      // TODO: Replace with actual endpoint when available
      final uri = Uri.parse('$baseUrl/referrals/withdraw');
      
      if (kDebugMode) {
        print('💸 Requesting withdrawal: $amount USDT to $walletAddress');
      }

      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'amount': amount,
          'walletAddress': walletAddress,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Withdrawal requested successfully');
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Withdrawal request submitted',
          'transactionId': data['transactionId'],
        };
      } else {
        if (kDebugMode) {
          print('❌ Withdrawal failed: ${data['message']}');
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to process withdrawal',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting withdrawal: $e');
      }
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}

