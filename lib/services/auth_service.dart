import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        final trimmedUrl = envUrl.trim();
        // Debug: print the URL being used
        if (kDebugMode) {
          print('🌐 BASE URL = $trimmedUrl');
          print('🌐 Using API_BASE_URL from .env: $trimmedUrl');
        }
        // Verify URL format
        if (!trimmedUrl.endsWith('/api')) {
          if (kDebugMode) {
            print('⚠️ WARNING: API_BASE_URL should end with /api');
            print('⚠️ Expected format: http://192.168.1.XXX:3000/api');
          }
        }
        return trimmedUrl;
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

  /// Google Sign-In authentication using Firebase Auth
  /// Returns user data including token, userId, email, and name
  /// [referralCode] - Optional referral code to apply during signup
  static Future<Map<String, dynamic>> signInWithGoogle({String? referralCode}) async {
    try {
      // Get pending referral code from SharedPreferences if not provided
      final prefs = await SharedPreferences.getInstance();
      final pendingReferralCode = referralCode ?? prefs.getString('pending_referral_code');

      // Initialize Google Sign-In (no clientId needed - Firebase handles it)
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return {
          'success': false,
          'message': 'Google Sign-In was cancelled',
        };
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential from Google auth
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return {
          'success': false,
          'message': 'Firebase authentication failed',
        };
      }

      // Get Firebase ID token for backend authentication
      final String? idToken = await firebaseUser.getIdToken();

      // Prepare request body with referral code if available
      final requestBody = {
        'firebaseUid': firebaseUser.uid,
        'email': firebaseUser.email,
        'name': firebaseUser.displayName ?? '',
        'photoUrl': firebaseUser.photoURL ?? '',
      };

      // Add referral code only if it exists (for new users)
      if (pendingReferralCode != null && pendingReferralCode.isNotEmpty) {
        requestBody['referralCode'] = pendingReferralCode.trim().toUpperCase();
        // Clear pending referral code after use
        await prefs.remove('pending_referral_code');
      }

      // Send to backend for user profile creation/update
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/google'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          // Use JWT token from backend instead of Firebase token
          final backendToken = data['token'] ?? idToken ?? '';
          return {
            'success': true,
            'token': backendToken,
            'userId': data['user']?['id'] ?? data['userId'] ?? firebaseUser.uid,
            'email': firebaseUser.email ?? '',
            'name': firebaseUser.displayName ?? '',
            'photoUrl': firebaseUser.photoURL ?? '',
            'firebaseUid': firebaseUser.uid,
          };
        }
      } catch (e) {
        // Backend call failed, but Firebase auth succeeded
        // Continue with Firebase user data
        if (kDebugMode) {
          print('⚠️ Backend auth call failed: $e');
          print('📱 Using Firebase user data');
        }
      }

      // Return Firebase user data (backend optional)
      return {
        'success': true,
        'token': idToken ?? '',
        'userId': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'name': firebaseUser.displayName ?? '',
        'photoUrl': firebaseUser.photoURL ?? '',
        'firebaseUid': firebaseUser.uid,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Google Sign-In error: ${e.toString()}',
      };
    }
  }

  /// Email/Password Login
  /// Returns user data including token, userId, email, and name
  static Future<Map<String, dynamic>> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'] ?? '',
          'userId': data['user']?['id'] ?? '',
          'email': data['user']?['email'] ?? email,
          'name': data['user']?['name'] ?? '',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Login error: ${e.toString()}',
      };
    }
  }

  /// Email/Password Signup
  /// Returns user data including token, userId, email, and name
  /// [referralCode] - Optional referral code to apply during signup
  static Future<Map<String, dynamic>> signupWithEmailPassword(
    String name,
    String email,
    String password, {
    String? referralCode,
  }) async {
    try {
      final requestBody = {
        'name': name,
        'email': email,
        'password': password,
      };

      // Add referral code if provided
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        requestBody['referralCode'] = referralCode.trim().toUpperCase();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'] ?? '',
          'userId': data['user']?['id'] ?? '',
          'email': data['user']?['email'] ?? email,
          'name': data['user']?['name'] ?? name,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Signup error: ${e.toString()}',
      };
    }
  }
}

