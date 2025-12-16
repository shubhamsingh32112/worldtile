import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/main/main_screen.dart';
import '../theme/app_theme.dart';

/// AppEntry decides the initial screen based on authentication status
/// 
/// - If user is logged in → opens directly on World Map (MainScreen with initialTabIndex: 0)
/// - If user is not logged in → shows OnboardingScreen
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        // Show splash while checking auth status
        if (!snapshot.hasData) {
          return const _SplashScreen();
        }

        // Navigate based on login status
        return snapshot.data!
            ? const MainScreen(initialTabIndex: 0) // Logged in → World Map (Buy Land tab)
            : const OnboardingScreen(); // Not logged in → Onboarding
      },
    );
  }

  /// Checks if user is logged in by verifying auth token
  Future<bool> _isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Simple splash screen shown while checking auth status
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.public,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'WorldTile',
              style: AppTheme.darkTheme.textTheme.headlineLarge?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

