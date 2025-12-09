import 'package:flutter/material.dart';
import '../map/world_map_page.dart';

/// BuyLandTab directly displays the world map for land purchasing
/// 
/// This tab replaces the previous hardcoded UI and shows the interactive
/// world map directly when the "Buy Land" tab is selected.
class BuyLandTab extends StatelessWidget {
  const BuyLandTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Directly return the world map page without any wrapper UI
    return const WorldMapPage();
  }
}

