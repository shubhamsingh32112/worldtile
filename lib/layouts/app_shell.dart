import 'package:flutter/material.dart';
import '../widgets/glass_top_navbar.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/app_background.dart';
import '../layouts/navbar_constants.dart';

/// Global app shell that provides consistent layout across all pages
/// 
/// Architecture:
/// - Stack layout with full-screen background, content, and floating navbars
/// - Top navbar (floating glass with back, title, account)
/// - Bottom navigation bar (optional, for tabbed navigation)
/// - Content area with padding to prevent overlap
class AppShell extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showBackButton;
  final int? bottomNavIndex;
  final ValueChanged<int>? onBottomNavTap;
  final bool showBottomNav;
  final bool showTopNav;

  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.showBackButton = true,
    this.bottomNavIndex,
    this.onBottomNavTap,
    this.showBottomNav = false,
    this.showTopNav = true,
  });

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // Calculate content padding to prevent overlap with navbars
    final contentTopPadding = showTopNav
        ? safeAreaTop + 
          NavbarConstants.topPadding + 
          NavbarConstants.topNavHeight
        : safeAreaTop;
    final contentBottomPadding = showBottomNav 
        ? safeAreaBottom + NavbarConstants.bottomNavHeight
        : safeAreaBottom;
    
    return Stack(
      children: [
        // Bottom layer: Full-screen background image
        Positioned.fill(
          child: AppBackground(
            child: Container(), // Background only, content is separate
          ),
        ),
        
        // Middle layer: Page content with safe padding
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              top: contentTopPadding,
              bottom: contentBottomPadding,
            ),
            child: child,
          ),
        ),
        
        // Top layer: Floating glass top navbar
        if (showTopNav)
          GlassTopNavbar(
            title: title,
            showBackButton: showBackButton,
          ),
        
        // Top layer: Floating glass bottom navigation bubbles
        // Each icon is independent, no container wrapping
        if (showBottomNav && bottomNavIndex != null && onBottomNavTap != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: safeAreaBottom + NavbarConstants.bottomPadding,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassBottomNav(
                  currentIndex: bottomNavIndex!,
                  onTap: onBottomNavTap!,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

