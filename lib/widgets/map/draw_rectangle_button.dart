import 'package:flutter/material.dart';
import 'package:worldtile_app/theme/app_theme.dart';

/// Floating action button to start rectangle placement.
class DrawRectangleButton extends StatelessWidget {
  final double currentZoom;
  final double minVisibleZoom;
  final bool isPlacementMode;
  final VoidCallback onPressed;

  const DrawRectangleButton({
    super.key,
    required this.currentZoom,
    required this.onPressed,
    this.minVisibleZoom = 12.0,
    this.isPlacementMode = false,
  });

  bool get _shouldShow => currentZoom >= minVisibleZoom;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.backgroundColor,
          onPressed: onPressed,
          icon: Icon(isPlacementMode ? Icons.touch_app : Icons.crop_square),
          label: Text(isPlacementMode ? 'Tap on map...' : 'Draw Rectangle'),
        ),
      ),
    );
  }
}

