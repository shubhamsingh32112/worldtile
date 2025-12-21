import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/account/account_screen.dart';
import '../layouts/navbar_constants.dart';

/// Floating glassmorphic top navbar
/// 
/// Features:
/// - Back button (auto-hides if no back route)
/// - Centered title (optional)
/// - Account icon (circular glass bubble)
/// - All elements are individual glass bubbles
class GlassTopNavbar extends StatelessWidget {
  final String? title;
  final bool showBackButton;

  const GlassTopNavbar({
    super.key,
    this.title,
    this.showBackButton = true,
  });

  /// Check if there's a back route available
  static bool _canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final canPop = showBackButton && _canPop(context);

    return Positioned(
      top: safeAreaTop + NavbarConstants.topPadding,
      left: NavbarConstants.horizontalPadding,
      right: NavbarConstants.horizontalPadding,
      child: SizedBox(
        height: NavbarConstants.topNavHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Back button (glass bubble)
            if (canPop)
              _GlassIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              )
            else
              const SizedBox(width: 48), // Spacer to maintain layout

            // Center: Title (optional glass pill or just text)
            Expanded(
              child: title != null
                  ? Center(
                      child: _GlassTitle(text: title!),
                    )
                  : const SizedBox.shrink(),
            ),

            // Right: Account icon (glass bubble)
            _GlassIconButton(
              icon: Icons.person,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Glassmorphic icon button (circular)
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic title (optional pill background)
class _GlassTitle extends StatelessWidget {
  final String text;

  const _GlassTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    // Option: Just text floating, or with subtle glass pill
    // Using subtle glass pill for better visibility
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

