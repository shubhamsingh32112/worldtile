import 'package:flutter/material.dart';

/// Background widget that covers the entire screen
/// 
/// This widget provides a consistent background image for the entire app.
/// Navbars float above this background.
/// 
/// Architecture:
/// - Uses Stack to layer background image behind content
/// - Background image uses BoxFit.cover for full coverage
/// - Child widget (the actual page content) is placed on top
class AppBackground extends StatelessWidget {
  final Widget child;
  
  /// Path to the background image asset
  static const String backgroundImagePath = 'assets/backgrounds/app_bg.jpeg';

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom layer: Background image (covers entire screen)
        // The image is static and does not scroll with content
        Image.asset(
          backgroundImagePath,
          fit: BoxFit.cover,
          // Error handling: fallback to a solid color if image is missing
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF0A0E27), // Fallback to theme background color
            );
          },
        ),
        // Top layer: Actual page content
        child,
      ],
    );
  }
}

