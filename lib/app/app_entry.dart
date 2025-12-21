import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/main/main_screen.dart';
import '../theme/app_theme.dart';
import '../layouts/app_shell.dart';

/// AppEntry decides the initial screen based on authentication and onboarding status
/// 
/// Flow:
/// - If authenticated → Homepage (skip onboarding and login)
/// - Else if onboarding not completed → Onboarding
/// - Else → Login Screen
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  String? _initialReferralCode;

  @override
  void initState() {
    super.initState();
    _checkInitialLink();
  }

  /// Check for initial deep link (app opened via URL with referral code)
  Future<void> _checkInitialLink() async {
    // Note: For full deep linking support, you may need to use packages like
    // uni_links or app_links. For now, we'll handle it via the referral service
    // which stores pending referral codes in SharedPreferences.
    
    // The referral code will be handled when user signs up/logs in
    // via the existing ReferralService.storePendingReferralCode mechanism
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NavigationTarget>(
      future: _determineNavigationTarget(),
      builder: (context, snapshot) {
        // Show splash while checking status
        if (!snapshot.hasData) {
          return const _SplashScreen();
        }

        // Navigate based on status
        final target = snapshot.data!;
        switch (target) {
          case NavigationTarget.homepage:
            // MainScreen already uses AppShell internally
            return const MainScreen(initialTabIndex: 0);
          case NavigationTarget.login:
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: AppShell(
                showBottomNav: false,
                showBackButton: false,
                child: const LoginScreen(),
              ),
            );
          case NavigationTarget.onboarding:
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: AppShell(
                showBottomNav: false,
                showBackButton: false,
                showTopNav: false,
                child: const OnboardingScreen(),
              ),
            );
        }
      },
    );
  }

  /// Determines where to navigate based on user state
  Future<NavigationTarget> _determineNavigationTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user is authenticated
      // Priority 1: If authenticated → Homepage (skip onboarding and login)
      final token = prefs.getString('auth_token');
      final authenticated = prefs.getBool('authenticated') ?? false;
      
      // User is considered authenticated if they have a valid token OR the authenticated flag is true
      final isAuthenticated = (token != null && token.isNotEmpty) || authenticated;
      
      if (isAuthenticated) {
        return NavigationTarget.homepage;
      }
      
      // Check if onboarding is completed
      final onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;

      // Priority 2: If onboarding not completed → Onboarding
      if (!onboardingCompleted) {
        return NavigationTarget.onboarding;
      }

      // Priority 3: If onboarding done → Login Screen
      return NavigationTarget.login;
    } catch (e) {
      // On error, show onboarding
      return NavigationTarget.onboarding;
    }
  }
}

/// Navigation targets for app entry
enum NavigationTarget {
  homepage,
  login,
  onboarding,
}

/// Simple splash screen shown while checking auth status
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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

