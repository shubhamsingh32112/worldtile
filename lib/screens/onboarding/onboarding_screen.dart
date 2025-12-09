import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/onboarding_page.dart';
import '../auth/login_screen.dart';
import '../main/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Onboarding pages (0-4) - shown to everyone
  final List<OnboardingData> _onboardingPages = [
    OnboardingData(
      title: 'Buy Virtual Land',
      description:
          'Purchase and own virtual land parcels in our futuristic metaverse. Each tile is unique and can be customized to your vision.',
      icon: Icons.map,
      color: AppTheme.primaryColor,
    ),
    OnboardingData(
      title: 'Crypto Payments',
      description:
          'Secure transactions using cryptocurrency. Fast, transparent, and decentralized payments for all your virtual land purchases.',
      icon: Icons.account_balance_wallet,
      color: AppTheme.secondaryColor,
    ),
    OnboardingData(
      title: 'Custom Avatars',
      description:
          'Create and customize your unique avatar. Express yourself in the metaverse with personalized digital identities.',
      icon: Icons.person,
      color: AppTheme.accentColor,
    ),
    OnboardingData(
      title: 'Region Locking',
      description:
          'Lock regions to create exclusive communities. Build your virtual empire with controlled access and special privileges.',
      icon: Icons.lock,
      color: AppTheme.primaryColor,
    ),
    OnboardingData(
      title: 'Start Your Journey',
      description:
          'Join thousands of users building the future of virtual real estate. Your metaverse adventure begins now!',
      icon: Icons.rocket_launch,
      color: AppTheme.secondaryColor,
    ),
  ];

  // Total pages: Only show onboarding pages (logged-in users are redirected)
  int get _totalPages => _onboardingPages.length;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Checks login status - if user is logged in, navigate directly to MainScreen
  /// This prevents the onboarding UI from showing briefly for logged-in users
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final isLoggedIn = token != null && token.isNotEmpty;

    if (!mounted) return;

    // If user is logged in, they shouldn't be on onboarding screen
    // Navigate directly to MainScreen to prevent any UI glitches
    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
      return;
    }

    // User is not logged in - onboarding will display normally
  }

  void _nextPage() {
    // If on last onboarding page, navigate to login
    if (_currentPage == _onboardingPages.length - 1) {
      _navigateToLogin();
      return;
    }

    // Otherwise, go to next page
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    // Skip to login screen
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Page view for onboarding pages
            PageView.builder(
              controller: _pageController,
              physics: const AlwaysScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                // Mark onboarding as seen when user reaches any page
                _completeOnboarding();
              },
              itemCount: _totalPages,
              itemBuilder: (context, index) {
                // Show onboarding page
                return OnboardingPage(data: _onboardingPages[index]);
              },
            ),
            // Onboarding UI elements (Skip, indicator, Next button)
            Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Page indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: _onboardingPages.length,
                    effect: const WormEffect(
                      activeDotColor: AppTheme.primaryColor,
                      dotColor: AppTheme.surfaceColor,
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 8,
                    ),
                  ),
                ),
                // Next/Get Started button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentPage == _onboardingPages.length - 1
                            ? 'Get Started'
                            : 'Next',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

