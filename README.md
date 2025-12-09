# WorldTile Flutter App

Flutter mobile application for the WorldTile Metaverse - a platform for buying and selling virtual land.

## Features

- 5 onboarding screens with swipe navigation
- User authentication (login/signup)
- Bottom navigation with 4 main tabs:
  - Home
  - Buy Land
  - Value (Portfolio)
  - Earn
- Account/Profile page
- Dark futuristic theme
- Clean, reusable components

## Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)

## Installation

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Update the backend URL in `lib/services/auth_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_BACKEND_URL:3000/api';
```

For Android emulator, use: `http://10.0.2.2:3000/api`
For iOS simulator, use: `http://localhost:3000/api`
For physical device, use your computer's IP address.

## Running the App

```bash
flutter run
```

## Project Structure

```
frontend_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── theme/                    # App theme configuration
│   ├── screens/
│   │   ├── onboarding/           # Onboarding screens
│   │   ├── auth/                 # Login/Signup screens
│   │   ├── main/                 # Main navigation tabs
│   │   └── account/              # Account/Profile screen
│   ├── widgets/                  # Reusable widgets
│   └── services/                 # API services
├── pubspec.yaml
└── README.md
```

## Screens

### Onboarding
- 5 pages introducing app features
- Swipe navigation
- Skip and Next buttons

### Authentication
- Login screen
- Signup screen
- Token-based authentication

### Main Navigation
- **Home**: Dashboard with portfolio overview
- **Buy Land**: Browse and purchase virtual land tiles
- **Value**: Portfolio value and performance tracking
- **Earn**: Earning opportunities and rewards

### Account
- User profile
- Settings
- Logout

## Technologies Used

- Flutter - Cross-platform mobile framework
- SharedPreferences - Local storage for tokens
- HTTP - API communication
- Google Fonts - Typography
- Smooth Page Indicator - Onboarding indicators

