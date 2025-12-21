import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glassmorphic card widget with blur effect
/// 
/// Provides a consistent glassmorphic design across the app
/// with backdrop blur and semi-transparent background
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.blurSigma = 22.5, // Default to 20-25 range (22.5)
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(26), // Default to 24-28 range (26)
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor ?? 
                   Colors.white.withOpacity(0.1), // Default to 0.08-0.12 range (0.1)
            borderRadius: borderRadius ?? BorderRadius.circular(26),
            // No borders - premium glassmorphic design
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

