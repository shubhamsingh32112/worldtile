import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../map/map_controller.dart';
import '../map/world_map_page.dart';
import 'home_page.dart';
import 'deed_page.dart';
import 'earn_tab.dart';
import '../../layouts/app_shell.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late final List<Widget> _tabs;
  final GlobalKey<WorldMapPageState> _worldMapKey = GlobalKey<WorldMapPageState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    // Initialize tabs with HomePage that has callback
    _tabs = [
      HomePage(onNavigateToTab: _navigateToTab),
      WorldMapPage(
        key: _worldMapKey,
        showViewOpenStatesButton: true,
      ), // Buy Land
      const DeedPage(),
      const EarnPage(),
    ];
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // If navigating to Buy Land tab (index 1), reset button state
    if (index == 1) {
      _worldMapKey.currentState?.resetButtonState();
    }
    
    // No auto-zoom - user must tap "View Open States" button
  }

  /// Get title for current tab
  String? _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Buy Land';
      case 2:
        return 'Deed';
      case 3:
        return 'Earn';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppShell(
        title: _getTitleForIndex(_currentIndex),
        showBackButton: false, // Main tabs don't need back button
        showBottomNav: true,
        bottomNavIndex: _currentIndex,
        onBottomNavTap: _onTabTapped,
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // If switching to Buy Land tab (index 1), reset button state
    if (index == 1) {
      _worldMapKey.currentState?.resetButtonState();
    }

    // No auto-zoom - user must tap "View Open States" button
  }
}

