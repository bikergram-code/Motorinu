// lib/core/api_config.dart
class ApiConfig {
  // ---------------------------------------------------------------------------
  // Supabase (primary backend)
  // ---------------------------------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://trmwbkpfafigraveneva.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRybXdia3BmYWZpZ3JhdmVuZXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDYyODMsImV4cCI6MjA4NjY4MjI4M30.aUyG0Pn0dTv68jVXBXZpGgwumaiVNOQo96t-i-sL-w8',
  );

  // ---------------------------------------------------------------------------
  // Legacy PHP API (kept for migration period)
  // ---------------------------------------------------------------------------
  static const String apiBaseUrl = String.fromEnvironment(
    'BIKERGRAM_API_BASE_URL',
    defaultValue: 'https://api.bikergram.com',
  );

  /// Website base (marketing page etc.)
  static const String webBaseUrl = String.fromEnvironment(
    'BIKERGRAM_WEB_BASE_URL',
    defaultValue: 'https://www.bikergram.de',
  );

  // ---------------------------------------------------------------------------
  // Google Routes API (turn-by-turn navigation, TWO_WHEELER mode)
  // ---------------------------------------------------------------------------
  /// Pass at build time: --dart-define=GOOGLE_ROUTES_API_KEY=AIzaSy...
  /// Empty = disabled, falls back to OSRM.
  static const String googleRoutesApiKey = String.fromEnvironment(
    'GOOGLE_ROUTES_API_KEY',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // HERE API (speed limits fallback — automotive-grade accuracy)
  // ---------------------------------------------------------------------------
  /// Pass at build time: --dart-define=HERE_API_KEY=...
  /// Get free key at https://developer.here.com
  /// Free Tier: 1,000 requests/day
  static const String hereApiKey = String.fromEnvironment(
    'HERE_API_KEY',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // Mapbox (maps & navigation)
  // ---------------------------------------------------------------------------
  /// Mapbox public token — injected at runtime from env / native config.
  /// On Android: set in AndroidManifest or gradle.properties
  /// On CI: pass --dart-define=MAPBOX_PUBLIC_TOKEN=pk.eyJ1...
  /// Locally: loaded from shared_preferences on first launch.
  static String _mapboxToken = const String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
  static String get mapboxPublicToken => _mapboxToken;
  static set mapboxPublicToken(String v) => _mapboxToken = v;

  /// Backwards-compat field
  static const String netcupBaseUrl = apiBaseUrl;
  static String baseUrl() => apiBaseUrl;
}
