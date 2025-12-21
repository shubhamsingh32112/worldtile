import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating glassmorphic bottom navigation bar
/// 
/// Features:
/// - Each icon is an independent floating glass bubble
/// - Selected items expand to pill with label
/// - Unselected items stay as compact glass circles
/// - Smooth animations (250-300ms, easeOutCubic)
/// - No single container wrapping all items
class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItemData> _items = [
    _NavItemData(icon: Icons.home, label: 'Home'),
    _NavItemData(icon: Icons.public, label: 'Buy Land'),
    _NavItemData(icon: Icons.receipt_long, label: 'Deed'),
    _NavItemData(icon: Icons.trending_up, label: 'Earn'),
  ];

  @override
  Widget build(BuildContext context) {
    // Row with spaceEvenly - NO container wrapping
    // Each icon is independent
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        _items.length,
        (index) => FloatingGlassNavItem(
          item: _items[index],
          isSelected: currentIndex == index,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap(index);
          },
        ),
      ),
    );
  }
}

/// Navigation item data
class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.label,
  });
}

/// Independent floating glass navigation item
/// 
/// Each item is its own glass bubble:
/// - Unselected: Circle, ~50px, icon only
/// - Selected: Pill, expands to fit label, icon + text
class FloatingGlassNavItem extends StatefulWidget {
  final _NavItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  const FloatingGlassNavItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<FloatingGlassNavItem> createState() => _FloatingGlassNavItemState();
}

class _FloatingGlassNavItemState extends State<FloatingGlassNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Fixed width: 52px unselected, 140px selected
    // NEVER null, NEVER unbounded
    const double unselectedWidth = 52.0;
    const double selectedWidth = 140.0;
    
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: widget.item.label,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: SizedBox(
            // Fixed height and width - ALWAYS finite
            height: 52,
            width: widget.isSelected ? selectedWidth : unselectedWidth,
            child: ClipRRect(
              // Circle when unselected, pill when selected
              borderRadius: BorderRadius.circular(
                widget.isSelected ? 24 : 52,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  // Width is now controlled by parent SizedBox
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isSelected ? 16 : 12,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Colors.white.withOpacity(0.14)
                        : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(
                      widget.isSelected ? 24 : 52,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon with scale animation
                      AnimatedScale(
                        scale: widget.isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          widget.item.icon,
                          size: 22,
                          color: widget.isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                        ),
                      ),
                      // Label with fade animation (text on the RIGHT)
                      AnimatedOpacity(
                        opacity: widget.isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: widget.isSelected
                            ? Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    widget.item.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
