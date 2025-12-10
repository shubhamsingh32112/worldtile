import 'package:flutter/material.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/area_calculator.dart';
import 'package:worldtile_app/screens/map/rectangle_drawing/rectangle_model.dart';
import 'package:worldtile_app/theme/app_theme.dart';

/// Overlay controls showing rectangle area with delete and save actions.
class RectangleControls extends StatelessWidget {
  final RectangleModel? rectangle;
  final VoidCallback onDelete;
  final VoidCallback? onSave;

  const RectangleControls({
    super.key,
    required this.rectangle,
    required this.onDelete,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (rectangle == null) return const SizedBox.shrink();
    final areaText = AreaCalculator.formatArea(rectangle!.areaInAcres);
    
    // Use MediaQuery to get screen dimensions for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;
    
    // Calculate bottom padding: extra space to avoid FAB overlap on small screens
    // FAB.extended is typically ~56px height + 16px padding = ~72px minimum
    // Add extra buffer for very small screens
    final bottomPadding = isVerySmallScreen 
        ? 100.0  // Extra space for very small screens
        : isSmallScreen 
            ? 85.0  // Space for small screens
            : 16.0; // Normal padding

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: bottomPadding,
          top: 16.0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth - 32, // Ensure it doesn't exceed screen width
            maxHeight: screenHeight * 0.25, // Prevent it from taking too much vertical space
          ),
          child: Card(
            color: AppTheme.surfaceColor.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 6,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmallScreen ? 10 : 12,
                vertical: isVerySmallScreen ? 6 : 8,
              ),
              child: isSmallScreen
                  ? _buildVerticalLayout(context, areaText)
                  : _buildHorizontalLayout(context, areaText),
            ),
          ),
        ),
      ),
    );
  }

  /// Horizontal layout for larger screens
  Widget _buildHorizontalLayout(BuildContext context, String areaText) {
    return IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.square_foot, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              areaText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (onSave != null) ...[
            _buildCompactButton(
              context: context,
              onPressed: onSave!,
              icon: Icons.save_outlined,
              label: 'Save',
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
          ],
          _buildCompactButton(
            context: context,
            onPressed: onDelete,
            icon: Icons.delete_outline,
            label: 'Delete',
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  /// Vertical layout for smaller screens
  Widget _buildVerticalLayout(BuildContext context, String areaText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.square_foot, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                areaText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (onSave != null)
              _buildCompactButton(
                context: context,
                onPressed: onSave!,
                icon: Icons.save_outlined,
                label: 'Save',
                color: AppTheme.primaryColor,
              ),
            _buildCompactButton(
              context: context,
              onPressed: onDelete,
              icon: Icons.delete_outline,
              label: 'Delete',
              color: AppTheme.accentColor,
            ),
          ],
        ),
      ],
    );
  }

  /// Build a compact button that fits well in limited space
  Widget _buildCompactButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 350;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 8 : 12,
          vertical: 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isVerySmallScreen ? 12 : 14,
        ),
      ),
    );
  }
}

