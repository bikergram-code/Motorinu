import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Country policy for blitzer/speed camera alerts.
class BlitzerCountryPolicy {
  const BlitzerCountryPolicy({
    required this.countryCode,
    required this.mode,
    this.allowReporting = false,
    this.allowAudioAlerts = false,
    this.notes,
  });

  final String countryCode;

  /// 'off' = no alerts at all
  /// 'danger_zone' = coarse zones only (no exact locations)
  /// 'exact' = full precision alerts
  final String mode;
  final bool allowReporting;
  final bool allowAudioAlerts;
  final String? notes;

  bool get isOff => mode == 'off';
  bool get isDangerZone => mode == 'danger_zone';
  bool get isExact => mode == 'exact';

  /// Whether any form of blitzer display is allowed.
  bool get isActive => !isOff;

  factory BlitzerCountryPolicy.fromJson(Map<String, dynamic> json) {
    return BlitzerCountryPolicy(
      countryCode: json['country_code'] as String? ?? '??',
      mode: json['mode'] as String? ?? 'exact',
      allowReporting: json['allow_reporting'] as bool? ?? false,
      allowAudioAlerts: json['allow_audio_alerts'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  /// Default policy for unknown countries (conservative: exact + reporting allowed).
  factory BlitzerCountryPolicy.defaultFor(String countryCode) {
    return BlitzerCountryPolicy(
      countryCode: countryCode,
      mode: 'exact',
      allowReporting: true,
      allowAudioAlerts: true,
    );
  }

  /// Blocked policy (for countries where it's fully off).
  factory BlitzerCountryPolicy.blocked(String countryCode) {
    return BlitzerCountryPolicy(
      countryCode: countryCode,
      mode: 'off',
      allowReporting: false,
      allowAudioAlerts: false,
    );
  }

  @override
  String toString() =>
      'BlitzerCountryPolicy($countryCode, mode=$mode, reporting=$allowReporting)';
}

/// State for the country policy.
class CountryPolicyState {
  const CountryPolicyState({
    this.policy,
    this.isLoading = false,
    this.countryCode,
    this.error,
  });

  final BlitzerCountryPolicy? policy;
  final bool isLoading;
  final String? countryCode;
  final String? error;

  CountryPolicyState copyWith({
    BlitzerCountryPolicy? policy,
    bool? isLoading,
    String? countryCode,
    String? error,
  }) {
    return CountryPolicyState(
      policy: policy ?? this.policy,
      isLoading: isLoading ?? this.isLoading,
      countryCode: countryCode ?? this.countryCode,
      error: error,
    );
  }
}

class CountryPolicyNotifier extends Notifier<CountryPolicyState> {
  /// Cache policies in memory to avoid repeated DB queries.
  static final Map<String, BlitzerCountryPolicy> _cache = {};

  @override
  CountryPolicyState build() {
    return const CountryPolicyState();
  }

  /// Client-side policy overrides.
  /// Use this for countries where the DB has a conservative default
  /// but we want a different policy in the app.
  /// Remove entries here once the DB is updated via Supabase Dashboard.
  static const Map<String, BlitzerCountryPolicy> _clientOverrides = {
    'DE': BlitzerCountryPolicy(
      countryCode: 'DE',
      mode: 'exact',
      allowReporting: true,
      allowAudioAlerts: true,
      notes: 'Germany - client override (allowed)',
    ),
  };

  /// Load policy for a specific country code.
  /// Called when the user's location changes to a new country.
  Future<void> loadPolicy(String countryCode) async {
    final code = countryCode.toUpperCase();

    // Already have this policy
    if (state.policy?.countryCode == code && !state.isLoading) return;

    // Check client-side overrides first (takes priority over DB)
    if (_clientOverrides.containsKey(code)) {
      final override = _clientOverrides[code]!;
      _cache[code] = override;
      state = CountryPolicyState(policy: override, countryCode: code);
      debugPrint('[CountryPolicy] Using client override: $override');
      return;
    }

    // Check cache
    if (_cache.containsKey(code)) {
      state = CountryPolicyState(
        policy: _cache[code],
        countryCode: code,
      );
      return;
    }

    state = state.copyWith(isLoading: true, countryCode: code);

    try {
      final data = await Supabase.instance.client
          .from('blitzer_country_policy')
          .select()
          .eq('country_code', code)
          .maybeSingle();

      final policy = data != null
          ? BlitzerCountryPolicy.fromJson(data)
          : BlitzerCountryPolicy.defaultFor(code);

      _cache[code] = policy;

      state = CountryPolicyState(
        policy: policy,
        countryCode: code,
      );

      debugPrint('[CountryPolicy] Loaded: $policy');
    } catch (e) {
      debugPrint('[CountryPolicy] Error loading policy for $code: $e');
      // On error, use default (allow everything)
      final fallback = BlitzerCountryPolicy.defaultFor(code);
      state = CountryPolicyState(
        policy: fallback,
        countryCode: code,
        error: e.toString(),
      );
    }
  }

  /// Get the current policy (may be null if not loaded yet).
  BlitzerCountryPolicy? get currentPolicy => state.policy;

  /// Check if blitzer alerts are allowed in the current country.
  bool get isBlitzerAllowed => state.policy?.isActive ?? true;

  /// Check if reporting is allowed in the current country.
  bool get isReportingAllowed => state.policy?.allowReporting ?? true;

  /// Check if audio alerts are allowed in the current country.
  bool get isAudioAllowed => state.policy?.allowAudioAlerts ?? true;
}

final countryPolicyProvider =
    NotifierProvider<CountryPolicyNotifier, CountryPolicyState>(
        CountryPolicyNotifier.new);
