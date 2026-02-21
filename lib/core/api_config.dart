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

  /// Backwards-compat field
  static const String netcupBaseUrl = apiBaseUrl;
  static String baseUrl() => apiBaseUrl;
}
