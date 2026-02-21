import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_config.dart';
import 'core/dev_http_overrides_stub.dart'
    if (dart.library.io) 'core/dev_http_overrides_io.dart';

import 'providers/core/providers.dart';
import 'routes/app_router.dart';
import 'services/android_auto_service.dart';
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

  if (kDebugMode) {
    installDevHttpOverrides();
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: ApiConfig.supabaseUrl,
    anonKey: ApiConfig.supabaseAnonKey,
    debug: kDebugMode,
  );

  // ── Android Auto: Register MethodChannel handler early ──
  // This ensures fetchPoiData works even before MainShell loads.
  AndroidAutoService.initChannel();

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
