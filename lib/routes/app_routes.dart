import 'package:flutter/material.dart';
import '../presentation/user_profile/user_profile.dart';
import '../presentation/main_social_feed/main_social_feed.dart';
import '../presentation/_placeholder/placeholder_screen.dart';
import '../presentation/digital_garage/digital_garage.dart';
import '../presentation/gps_ride_tracker/gps_ride_tracker.dart';
import '../presentation/marketplace_browse/marketplace_browse.dart';

import '../presentation/comic_character_registration_wizard/comic_character_registration_wizard.dart';
import '../presentation/splash_screen/splash_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String wizard = '/wizard';
  static const String userProfile = '/user-profile';
  static const String digitalGarage = '/digital-garage';
  static const String gpsRideTracker = '/gps-ride-tracker';
  static const String marketplaceBrowse = '/marketplace-browse';
  static const String mainSocialFeed = '/main-social-feed';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),

    // IMPORTANT: no const here (works whether wizard ctor is const or not)
    wizard: (context) => ComicCharacterRegistrationWizard(),
    userProfile: (context) => const UserProfile(),
    mainSocialFeed: (context) => const MainSocialFeed(),
      digitalGarage: (context) => const DigitalGarage(),
    gpsRideTracker: (context) => const GpsRideTracker(),
    marketplaceBrowse: (context) => const MarketplaceBrowse(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    // Fallback: bekannte Feature-Routen zeigen Placeholder statt Crash
    if (name == digitalGarage) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PlaceholderScreen(
          title: 'Garage',
          subtitle: 'Digital Garage kommt als nächstes.',
        ),
      );
    }
    if (name == gpsRideTracker) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PlaceholderScreen(
          title: 'GPS Ride Tracker',
          subtitle: 'Ride Tracker kommt als nächstes.',
        ),
      );
    }
    if (name == marketplaceBrowse) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PlaceholderScreen(
          title: 'Marketplace',
          subtitle: 'Marketplace kommt als nächstes.',
        ),
      );
    }
    return null;
  }

}