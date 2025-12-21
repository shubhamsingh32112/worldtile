import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/onboarding/onboarding_screen.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final int pageIndex;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;
        final bool hasImage = data.imagePath != null;
        final bool hasIcon = data.icon != null && data.color != null;

        // First page (index 0): show only background image
        if (pageIndex == 0 && hasImage) {
          return Stack(
            children: [
              // Full-screen background image
              Positioned.fill(
                child: Image.asset(
                  data.imagePath!,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          );
        }

        // Other pages: show content with background
        return Stack(
          children: [
            // Background image if available
            if (hasImage)
              Positioned.fill(
                child: Image.asset(
                  data.imagePath!,
                  fit: BoxFit.cover,
                ),
              ),
            // Foreground content
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: screenHeight * 0.02,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Spacer to position hero image at ~12-18% from top
                        SizedBox(height: screenHeight * 0.12),
                        // Hero image or icon
                        if (hasImage)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: screenHeight * 0.38,
                              maxWidth: screenWidth * 0.85,
                            ),
                            child: Image.asset(
                              data.imagePath!,
                              fit: BoxFit.contain,
                            ),
                          )
                        else if (hasIcon)
                          Container(
                            width: screenWidth * 0.3,
                            height: screenWidth * 0.3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  data.color!.withOpacity(0.2),
                                  data.color!.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              data.icon,
                              size: screenWidth * 0.15,
                              color: data.color,
                            ),
                          ),
                        // Spacer between image and text
                        SizedBox(height: screenHeight * 0.04),
                        // Title
                        Text(
                          data.title,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        // Description
                        Text(
                          data.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                height: 1.6,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Spacer to push content up if needed
                        SizedBox(height: screenHeight * 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

