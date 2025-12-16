import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../map/map_controller.dart';
import '../map/world_map_page.dart';
import 'deed_page.dart';
import 'earn_tab.dart';
import '../../widgets/floating_bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  final List<Widget> _tabs = const [
    WorldMapPage(), // Buy Land
    DeedPage(),
    EarnPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: FloatingBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              items: const [
                NavItem(icon: Icons.public, label: 'Buy Land'),
                NavItem(icon: Icons.receipt_long, label: 'Deed'),
                NavItem(icon: Icons.trending_up, label: 'Earn'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      WorldMapController.instance.zoomToIndia();
    }
  }
}

