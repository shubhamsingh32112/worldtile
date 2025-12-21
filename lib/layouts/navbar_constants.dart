/// Constants for navbar heights
/// 
/// Single source of truth for all navbar dimensions
/// Used throughout the app to ensure consistent spacing
class NavbarConstants {
  /// Height of the top navbar content
  /// The actual navbar widget height
  static const double topNavHeight = 56.0;
  
  /// Height of the bottom navigation bar
  /// Matches GlassBottomNav height (64) + bottom padding (16)
  static const double bottomNavHeight = 80.0;
  
  /// Horizontal padding for floating navbars
  static const double horizontalPadding = 16.0;
  
  /// Bottom padding for bottom navbar (from safe area)
  static const double bottomPadding = 16.0;
  
  /// Top padding for top navbar (from safe area)
  static const double topPadding = 8.0;
}

