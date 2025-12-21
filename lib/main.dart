import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/app_entry.dart';
import 'theme/app_theme.dart';
import 'services/referral_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (must be done before runApp)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Load environment variables from .env file
  await dotenv.load(fileName: "assets/.env");
  
  // Set Mapbox access token globally
  // This must be done before any MapWidget is created
  final mapboxToken = dotenv.env["MAPBOX_PUBLIC_TOKEN"];
  if (mapboxToken != null && mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Handle deep links when app is already running
  Future<void> _handleDeepLink(String? link) async {
    if (link != null) {
      // Extract referral code from deep link
      final referralCode = ReferralService.extractReferralCodeFromUrl(link);
      if (referralCode != null) {
        await ReferralService.storePendingReferralCode(referralCode);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // TODO: Set up deep link listeners using uni_links or app_links package
    // For now, referral codes are handled via URL parameters in share links
    // and stored when user signs up/logs in
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorldTile Metaverse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // AppBackground is now handled inside AppShell
      // This ensures background only applies to content, not navbars
      home: const AppEntry(),
      // Enable deep linking
      // For full support, configure routes and use onGenerateInitialRoutes
    );
  }
}

