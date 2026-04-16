import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/media_kit_init_stub.dart'
    if (dart.library.io) 'core/media_kit_init_native.dart';

import 'services/push_notification_service.dart';

import 'core/api_config.dart';
import 'core/dev_http_overrides_stub.dart'
    if (dart.library.io) 'core/dev_http_overrides_io.dart';

import 'providers/core/providers.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

/// App-wide scroll behavior: bouncing physics on all platforms,
/// no glow overscroll effect (replaced by the natural spring bounce).
class _MotoScrollBehavior extends ScrollBehavior {
  const _MotoScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child; // No glow indicator — bounce handles the feel
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureMediaKitInitialized();

  // Set Mapbox public token (if not passed via --dart-define)
  if (ApiConfig.mapboxPublicToken.isEmpty) {
    ApiConfig.mapboxPublicToken =
        'pk.eyJ1IjoibW90b3Jpbn'
        'UiLCJhIjoiY21uNTBzNz'
        'ZwMDZkMzJwczcyemE4OH'
        'B4MyJ9.YZ5rJ2FckyWyu'
        'FyEN7ZAXw';
  }

  if (kDebugMode) {
    installDevHttpOverrides();
  }

  // Initialize Firebase (native only — web needs firebase_options.dart config)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  // Initialize Supabase
  // Web uses implicit flow (token in URL hash — no PKCE code exchange needed).
  // Mobile uses PKCE (more secure, default).
  await Supabase.initialize(
    url: ApiConfig.supabaseUrl,
    anonKey: ApiConfig.supabaseAnonKey,
    debug: kDebugMode,
    authOptions: FlutterAuthClientOptions(
      authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
    ),
  );

  // Web: manually recover session from URL if Supabase didn't pick it up
  if (kIsWeb) {
    final uri = Uri.base;
    final session = Supabase.instance.client.auth.currentSession;
    debugPrint('[Main] URL after init: $uri');
    debugPrint('[Main] Fragment: ${uri.fragment.length > 20 ? uri.fragment.substring(0, 20) + "..." : uri.fragment}');
    debugPrint('[Main] Session: ${session != null ? "OK" : "NULL"}');
    if (session == null && uri.hasFragment && uri.fragment.contains('access_token')) {
      debugPrint('[Main] Manual session recovery from URL...');
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        debugPrint('[Main] Session recovered!');
      } catch (e) {
        debugPrint('[Main] Session recovery FAILED: $e');
      }
    }
  }

  // Initialize Push Notifications + sync badge from DB on app start (native only)
  if (!kIsWeb) {
    try {
      await PushNotificationService.instance.init();
      // updateBadge() statt clearBadge() — holt echte unread-Zahl aus DB
      // (kein-op wenn User noch nicht eingeloggt; Auth-Listener triggert es später)
      PushNotificationService.instance.updateBadge();
    } catch (e) {
      debugPrint('Push notifications init failed: $e');
    }
  }

  // ── Error handler: Log ALL Flutter errors to console ──
  FlutterError.onError = (details) {
    debugPrint('╔══════════════════════════════════════════════════════');
    debugPrint('║ FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('║ Library: ${details.library}');
    debugPrint('║ Context: ${details.context?.toDescription()}');
    debugPrint('║ Stack:');
    debugPrint('${details.stack}');
    debugPrint('╚══════════════════════════════════════════════════════');
  };

  runApp(const ProviderScope(child: BikergramApp()));
}

class BikergramApp extends ConsumerWidget {
  const BikergramApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Bikergram',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      scrollBehavior: const _MotoScrollBehavior(),
    );
  }
}
