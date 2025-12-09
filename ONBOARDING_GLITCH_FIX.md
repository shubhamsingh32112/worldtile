# Onboarding Button Glitch Fix

## Problem
When a logged-in user opened the app, the "Get Started" and "Skip" buttons from the onboarding screen would briefly flash/glitch before the app navigated to the home page. This created a poor user experience.

## Root Cause
The issue was caused by a race condition in the navigation flow:

1. **SplashScreen** always navigated to **OnboardingScreen** regardless of login status
2. **OnboardingScreen** checked login status asynchronously in `_checkLoginStatus()`
3. During initial render, `_isLoggedIn` was `false` and `_currentPage` was `0`
4. This caused the Skip and Get Started buttons to render briefly
5. Then `addPostFrameCallback` would run and jump to page 5 (home), hiding the buttons
6. This created a visible glitch/flash of the buttons

## Solution
The fix implements a **direct navigation approach** that bypasses the onboarding screen entirely for logged-in users:

### 1. **SplashScreen** (`lib/main.dart`)
- **Before**: Always navigated to `OnboardingScreen`
- **After**: Checks login status first, then:
  - If logged in → Navigate directly to `MainScreen`
  - If not logged in → Navigate to `OnboardingScreen`

### 2. **OnboardingScreen** (`lib/screens/onboarding/onboarding_screen.dart`)
- **Before**: Handled both logged-in and non-logged-in users, showing home page as page 5
- **After**: 
  - Immediately redirects logged-in users to `MainScreen` (safety check)
  - Only handles non-logged-in users
  - Simplified to show only onboarding pages (no home page in PageView)
  - Removed unused `_isLoggedIn` state variable

## Implementation Details

### Changes in `main.dart`

```dart
Future<void> _checkAuthAndNavigate() async {
  // Show splash screen for at least 2 seconds
  await Future.delayed(const Duration(seconds: 2));

  if (!mounted) return;

  // Check if user is already logged in
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final isLoggedIn = token != null && token.isNotEmpty;

  if (!mounted) return;

  // Navigate based on login status
  if (isLoggedIn) {
    // User is logged in - go directly to MainScreen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  } else {
    // User is not logged in - show onboarding
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }
}
```

### Changes in `onboarding_screen.dart`

1. **Removed home page from PageView**: Only shows onboarding pages now
2. **Added safety redirect**: If a logged-in user somehow reaches onboarding, redirect immediately
3. **Simplified navigation logic**: No more conditional logic for logged-in users
4. **Removed unused state**: Removed `_isLoggedIn` variable

## User Flow

### Logged-In User Flow
```
App Launch
  ↓
SplashScreen (2 seconds)
  ↓
Check auth_token in SharedPreferences
  ↓
Token exists? → YES
  ↓
Navigate directly to MainScreen
  ↓
Home Page (NO GLITCH!)
```

### Non-Logged-In User Flow
```
App Launch
  ↓
SplashScreen (2 seconds)
  ↓
Check auth_token in SharedPreferences
  ↓
Token exists? → NO
  ↓
Navigate to OnboardingScreen
  ↓
Show onboarding pages
  ↓
User taps "Get Started" or "Skip"
  ↓
Navigate to LoginScreen
```

## Benefits

1. **No More Glitches**: Logged-in users never see onboarding buttons
2. **Faster Navigation**: Direct route to home page for logged-in users
3. **Cleaner Code**: Simplified logic, removed unnecessary state management
4. **Better UX**: Smooth, professional app launch experience
5. **Maintainable**: Clear separation of concerns

## Testing Checklist

- [x] Logged-in user opens app → Goes directly to MainScreen (no buttons visible)
- [x] Non-logged-in user opens app → Sees onboarding normally
- [x] User logs in → Navigates to MainScreen (no glitch)
- [x] User swipes through onboarding → Works smoothly
- [x] Skip button works → Navigates to LoginScreen
- [x] Get Started button works → Navigates to LoginScreen
- [x] No linting errors
- [x] Code follows Flutter best practices

## Files Modified

1. `lib/main.dart` - Updated `_checkAuthAndNavigate()` method
2. `lib/screens/onboarding/onboarding_screen.dart` - Simplified to handle only non-logged-in users

## Technical Notes

- The fix uses `SharedPreferences` to check for `auth_token` synchronously
- Navigation uses `pushReplacement` to prevent back navigation to splash/onboarding
- The 2-second splash screen delay is maintained for branding consistency
- Safety check in `OnboardingScreen` ensures logged-in users are redirected even if they somehow reach it

## Future Considerations

If you want to add a "Logout" feature that returns to onboarding:
- You would need to clear the `auth_token` from SharedPreferences
- Then navigate to `OnboardingScreen` or `LoginScreen`
- The current implementation will handle this correctly

