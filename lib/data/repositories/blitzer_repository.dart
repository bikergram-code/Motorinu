import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/osm_blitzer_service.dart';
import '../../providers/map/country_policy_provider.dart';

/// Source of a blitzer report.
enum BlitzerSource { community, osm }

class BlitzerReport {
  final int id;
  final String userId;
  final double latitude;
  final double longitude;
  final String type;
  final String? description;
  final int confirmations;
  final int dismissals;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  // Joined profile
  final String? reporterUsername;
  // Data source: community (user-reported) or osm (OpenStreetMap)
  final BlitzerSource source;
  // OSM-specific: speed limit
  final int? speedLimit;
  // OSM road reference (e.g. "B229", "A3", "L288")
  final String? roadRef;

  const BlitzerReport({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.type = 'fixed',
    this.description,
    this.confirmations = 1,
    this.dismissals = 0,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
    this.reporterUsername,
    this.source = BlitzerSource.community,
    this.speedLimit,
    this.roadRef,
  });

  factory BlitzerReport.fromJson(Map<String, dynamic> json) {
    return BlitzerReport(
      id: json['id'] as int,
      userId: '${json['user_id']}',
      latitude: double.tryParse('${json['latitude']}') ?? 0,
      longitude: double.tryParse('${json['longitude']}') ?? 0,
      type: json['type'] ?? 'fixed',
      description: json['description'] as String?,
      confirmations: json['confirmations'] as int? ?? 1,
      dismissals: json['dismissals'] as int? ?? 0,
      isActive: json['is_active'] != false, // Default to true if null/missing
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse('${json['expires_at']}')
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }

  /// Create from OSM speed camera data.
  factory BlitzerReport.fromOsm(OsmSpeedCamera camera) {
    final desc = camera.maxspeed != null
        ? 'Tempolimit: ${camera.maxspeed} km/h'
        : 'Stationärer Blitzer (OSM)';
    return BlitzerReport(
      id: -camera.osmId, // Negative ID to avoid collision with Supabase IDs
      userId: 'osm',
      latitude: camera.latitude,
      longitude: camera.longitude,
      type: 'fixed',
      description: desc,
      confirmations: 100, // High trust — verified by OSM community
      dismissals: 0,
      isActive: true,
      createdAt: DateTime.now(),
      source: BlitzerSource.osm,
      speedLimit: camera.maxspeed,
      roadRef: camera.ref,
    );
  }

  /// Whether this report comes from OpenStreetMap.
  bool get isOsm => source == BlitzerSource.osm;

  /// Whether this report comes from community (user-reported).
  bool get isCommunity => source == BlitzerSource.community;

  String get typeLabel => switch (type) {
    'fixed' => isOsm ? 'Fester Blitzer (OSM)' : 'Fester Blitzer',
    'mobile' => 'Mobiler Blitzer',
    'construction' => 'Baustelle',
    'accident' => 'Unfall',
    'police' => 'Polizeikontrolle',
    'workshop' => 'Werkstatt',
    'gas_station' => 'Tankstelle',
    'biker_meetup' => 'Biker-Treff',
    'scenic_route' => 'Schoene Strecke',
    _ => type,
  };

  /// Trust score: ratio of confirmations vs dismissals.
  /// Higher = more trusted. Range: 0.0 - 1.0
  double get trustScore {
    final total = confirmations + dismissals;
    if (total == 0) return 0.5; // Neutral for new reports
    return confirmations / total;
  }

  /// Whether this report is still considered trustworthy (not voted away).
  /// Marker verschwindet nach 5x "Ist weg" klicken.
  bool get isTrusted => dismissals < 5;

  /// Whether this report has expired based on time.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// TTL for this report type.
  static Duration ttlFor(String type) => switch (type) {
    'mobile' => const Duration(hours: 2),
    'accident' => const Duration(hours: 4),
    'police' => const Duration(hours: 3),
    'construction' => const Duration(hours: 12),
    'biker_meetup' => const Duration(hours: 8),
    'fixed' => const Duration(days: 365), // Permanent
    'gas_station' => const Duration(days: 365),
    'workshop' => const Duration(days: 365),
    'scenic_route' => const Duration(days: 365),
    _ => const Duration(hours: 4),
  };
}

class BlitzerRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ─── Local blacklist for deleted reports ────────────────────────────────
  // Static so it survives Riverpod provider re-creation.
  // Persisted in SharedPreferences so deleted reports never come back.
  static const _deletedReportsKey = 'blitzer_deleted_report_ids';
  static Set<int> _deletedReportIds = {};
  static bool _deletedIdsLoaded = false;

  Future<void> _loadDeletedIds() async {
    if (_deletedIdsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_deletedReportsKey) ?? [];
    _deletedReportIds = ids.map((s) => int.tryParse(s)).whereType<int>().toSet();
    _deletedIdsLoaded = true;
  }

  Future<void> _addDeletedId(int reportId) async {
    _deletedReportIds.add(reportId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _deletedReportsKey,
      _deletedReportIds.map((id) => '$id').toList(),
    );
  }

  /// Check if a report was locally deleted/hidden.
  bool isDeletedLocally(int reportId) => _deletedReportIds.contains(reportId);

  // ─── Rate limiting (client-side) ───────────────────────────────────────
  // Prevents spamming reports from the same user.
  final Map<String, DateTime> _lastReportTime = {};
  static const _minReportInterval = Duration(minutes: 2);
  static const _maxReportsPerHour = 10;
  final List<DateTime> _recentReportTimestamps = [];

  /// Check if user can create a new report (rate limit check).
  String? canCreateReport() {
    final userId = _currentUserId;
    if (userId == null) return 'Nicht eingeloggt';

    // Check per-user interval
    final lastTime = _lastReportTime[userId];
    if (lastTime != null) {
      final elapsed = DateTime.now().difference(lastTime);
      if (elapsed < _minReportInterval) {
        final remaining = _minReportInterval - elapsed;
        return 'Bitte warte noch ${remaining.inSeconds} Sekunden';
      }
    }

    // Check hourly limit
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    _recentReportTimestamps.removeWhere((t) => t.isBefore(oneHourAgo));
    if (_recentReportTimestamps.length >= _maxReportsPerHour) {
      return 'Maximale Meldungen pro Stunde erreicht ($_maxReportsPerHour)';
    }

    return null; // OK to create
  }

  // ─── Queries ────────────────────────────────────────────────────────────

  Future<List<BlitzerReport>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    await _loadDeletedIds();

    // Simple bounding box filter (approximation: 1 degree ≈ 111 km)
    final latRange = radiusKm / 111.0;
    final lonRange = radiusKm / (111.0 * _cosApprox(latitude));

    final data = await _supabase
        .from('blitzer_reports')
        .select()
        .eq('is_active', true)
        .gte('latitude', latitude - latRange)
        .lte('latitude', latitude + latRange)
        .gte('longitude', longitude - lonRange)
        .lte('longitude', longitude + lonRange)
        .order('created_at', ascending: false)
        .limit(200);

    final reports = data.map<BlitzerReport>((json) =>
        BlitzerReport.fromJson(json)).toList();

    // Client-side filtering: remove expired, untrusted, deactivated & locally deleted reports
    return reports.where((r) =>
        r.isActive && !r.isExpired && r.isTrusted && !_deletedReportIds.contains(r.id)
    ).toList();
  }

  Future<List<BlitzerReport>> getAllActiveReports() async {
    await _loadDeletedIds();

    final data = await _supabase
        .from('blitzer_reports')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(200);

    final reports = data.map<BlitzerReport>((json) =>
        BlitzerReport.fromJson(json)).toList();

    // Client-side filtering + local blacklist
    return reports.where((r) =>
        r.isActive && !r.isExpired && r.isTrusted && !_deletedReportIds.contains(r.id)
    ).toList();
  }

  // ─── Mutations ──────────────────────────────────────────────────────────

  Future<BlitzerReport> createReport({
    required double latitude,
    required double longitude,
    String type = 'mobile',
    String? description,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    // Rate limit check
    final rateLimitError = canCreateReport();
    if (rateLimitError != null) throw Exception(rateLimitError);

    // TTL-based expiration
    final ttl = BlitzerReport.ttlFor(type);
    final expiresAt = ttl.inDays < 365
        ? DateTime.now().add(ttl).toIso8601String()
        : null;

    final data = await _supabase
        .from('blitzer_reports')
        .insert({
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'type': type,
          if (description != null) 'description': description,
          if (expiresAt != null) 'expires_at': expiresAt,
        })
        .select()
        .single();

    // Track rate limiting
    _lastReportTime[userId] = DateTime.now();
    _recentReportTimestamps.add(DateTime.now());

    // ── Award 10 XP for creating a report ──
    try {
      final profile = await _supabase
          .from('profiles')
          .select('xp_total, level')
          .eq('id', userId)
          .single();

      final newXp = (profile['xp_total'] as int? ?? 0) + 10;
      final newLevel = (newXp ~/ 100) + 1;

      await _supabase.from('profiles').update({
        'xp_total': newXp,
        'level': newLevel,
      }).eq('id', userId);

      debugPrint('[Blitzer] +10 XP awarded for report (total: $newXp, level: $newLevel)');
    } catch (e) {
      debugPrint('[Blitzer] XP award failed: $e');
    }

    debugPrint('[Blitzer] Report created: type=$type, expires=$expiresAt');

    return BlitzerReport.fromJson(data);
  }

  Future<void> confirmReport(int reportId) async {
    await _supabase.rpc('increment_field', params: {
      'table_name': 'blitzer_reports',
      'field_name': 'confirmations',
      'row_id': reportId,
    }).catchError((_) async {
      // Fallback: direct update
      final current = await _supabase
          .from('blitzer_reports')
          .select('confirmations')
          .eq('id', reportId)
          .single();
      await _supabase
          .from('blitzer_reports')
          .update({'confirmations': (current['confirmations'] as int) + 1})
          .eq('id', reportId);
    });
  }

  Future<void> dismissReport(int reportId) async {
    await _supabase.rpc('increment_field', params: {
      'table_name': 'blitzer_reports',
      'field_name': 'dismissals',
      'row_id': reportId,
    }).catchError((_) async {
      final current = await _supabase
          .from('blitzer_reports')
          .select('dismissals')
          .eq('id', reportId)
          .single();
      await _supabase
          .from('blitzer_reports')
          .update({'dismissals': (current['dismissals'] as int) + 1})
          .eq('id', reportId);
    });
  }

  /// Delete a report (any type, own reports).
  /// Uses local blacklist (persistent) + server-side strategies.
  /// The local blacklist ensures the marker NEVER comes back, even if
  /// Supabase RLS blocks all server-side mutations.
  Future<void> deleteReport(int reportId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    debugPrint('[Blitzer] Deleting report $reportId for user $userId');

    // ── Always add to local blacklist first (instant, persistent) ──
    await _addDeletedId(reportId);
    debugPrint('[Blitzer] Report $reportId added to local blacklist');

    // ── Then try server-side cleanup (best-effort, multiple strategies) ──

    // Strategy 1: RPC deactivate_blitzer (SECURITY DEFINER, bypasses RLS)
    try {
      await _supabase.rpc('deactivate_blitzer', params: {
        'report_id': reportId,
      });
      debugPrint('[Blitzer] Report $reportId deactivated via RPC (global)');
      return; // Success — no need for fallback strategies
    } catch (e) {
      debugPrint('[Blitzer] RPC deactivate failed: $e');
    }

    // Strategy 2: Direct update (requires permissive UPDATE RLS policy)
    try {
      await _supabase
          .from('blitzer_reports')
          .update({'is_active': false, 'dismissals': 99})
          .eq('id', reportId);
      debugPrint('[Blitzer] Report $reportId deactivated via direct update');
      return;
    } catch (e) {
      debugPrint('[Blitzer] Direct update failed: $e');
    }

    // Strategy 3: Owner-only update + delete (RLS restricted)
    try {
      await _supabase
          .from('blitzer_reports')
          .update({'is_active': false, 'dismissals': 99})
          .eq('id', reportId)
          .eq('user_id', userId);
      debugPrint('[Blitzer] Report $reportId deactivated (owner)');
    } catch (e) {
      debugPrint('[Blitzer] Owner update failed: $e');
    }
    try {
      await _supabase
          .from('blitzer_reports')
          .delete()
          .eq('id', reportId)
          .eq('user_id', userId);
      debugPrint('[Blitzer] Report $reportId deleted from DB');
    } catch (e) {
      debugPrint('[Blitzer] Direct delete failed: $e');
    }

    // Strategy 4: Increment dismissals via RPC (if available)
    try {
      for (int i = 0; i < 10; i++) {
        await _supabase.rpc('increment_field', params: {
          'table_name': 'blitzer_reports',
          'field_name': 'dismissals',
          'row_id': reportId,
        });
      }
      debugPrint('[Blitzer] Report $reportId dismissals set high via RPC');
    } catch (e) {
      debugPrint('[Blitzer] RPC increment failed: $e');
    }

    // Even if all server strategies fail, the local blacklist ensures
    // this report never shows up again on this device.
  }

  // ─── Realtime: Neue Blitzer-Meldungen live empfangen ───────────────

  /// Subscribe to new blitzer reports in real-time.
  /// Fires [onNewReport] whenever any user inserts a new report.
  /// Also fires [onUpdate] for confirm/dismiss updates.
  RealtimeChannel subscribeToBlitzerReports({
    required void Function(BlitzerReport report) onNewReport,
    void Function(BlitzerReport report)? onUpdate,
  }) {
    return _supabase
        .channel('blitzer_reports:realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'blitzer_reports',
          callback: (payload) {
            try {
              final report = BlitzerReport.fromJson(payload.newRecord);
              debugPrint('[Blitzer RT] New report: ${report.typeLabel} (id=${report.id})');
              onNewReport(report);
            } catch (e) {
              debugPrint('[Blitzer RT] Parse error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'blitzer_reports',
          callback: (payload) {
            if (onUpdate == null) return;
            try {
              final report = BlitzerReport.fromJson(payload.newRecord);
              debugPrint('[Blitzer RT] Updated report: id=${report.id} (c=${report.confirmations}, d=${report.dismissals})');
              onUpdate(report);
            } catch (e) {
              debugPrint('[Blitzer RT] Update parse error: $e');
            }
          },
        )
        .subscribe();
  }

  double _cosApprox(double degrees) {
    final rad = degrees * 3.14159265 / 180.0;
    return 1.0 - (rad * rad / 2.0) + (rad * rad * rad * rad / 24.0);
  }

  // ═══════════════════════════════════════════════════
  //  COUNTRY POLICY COMPLIANCE
  // ═══════════════════════════════════════════════════

  /// Get nearby reports with country policy enforcement.
  /// Returns empty list if policy mode is 'off'.
  /// Returns danger zones (expanded radius) if mode is 'danger_zone'.
  Future<List<BlitzerReport>> getNearbyReportsWithPolicy({
    required double latitude,
    required double longitude,
    required BlitzerCountryPolicy? policy,
    double radiusKm = 50,
  }) async {
    // If policy is off, return nothing
    if (policy != null && policy.isOff) {
      debugPrint('[Blitzer] Country ${policy.countryCode}: mode=off → no reports');
      return [];
    }

    final reports = await getNearbyReports(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );

    // In danger_zone mode, we return reports but the UI should
    // display them as zones (circles) instead of exact points.
    // The actual UI transformation happens in the map screen.
    return reports;
  }

  /// Check if creating a report is allowed by country policy.
  String? canCreateReportWithPolicy(BlitzerCountryPolicy? policy) {
    // Standard rate limit check
    final rateError = canCreateReport();
    if (rateError != null) return rateError;

    // Country policy check
    if (policy != null && policy.isOff) {
      return 'Blitzer-Meldungen sind in ${policy.countryCode} nicht erlaubt';
    }
    if (policy != null && !policy.allowReporting) {
      return 'Meldungen sind in ${policy.countryCode} nicht erlaubt';
    }

    return null;
  }

  /// Check if a new account can report (anti-abuse: 24h minimum age).
  Future<bool> isAccountOldEnough() async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final data = await _supabase
          .from('profiles')
          .select('created_at')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return false;

      final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '');
      if (createdAt == null) return true; // Can't verify, allow

      final age = DateTime.now().difference(createdAt);
      return age.inHours >= 24;
    } catch (_) {
      return true; // On error, allow
    }
  }

  /// Duplicate detection: prevent same type within 200m and 10 minutes.
  Future<bool> isDuplicateReport({
    required double latitude,
    required double longitude,
    required String type,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final tenMinutesAgo = DateTime.now()
        .subtract(const Duration(minutes: 10))
        .toIso8601String();

    // 200m ≈ 0.0018 degrees
    const threshold = 0.0018;

    try {
      final data = await _supabase
          .from('blitzer_reports')
          .select('id')
          .eq('user_id', userId)
          .eq('type', type)
          .gte('created_at', tenMinutesAgo)
          .gte('latitude', latitude - threshold)
          .lte('latitude', latitude + threshold)
          .gte('longitude', longitude - threshold)
          .lte('longitude', longitude + threshold)
          .limit(1);

      return data.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Create report with full policy + anti-abuse checks.
  Future<BlitzerReport> createReportWithPolicy({
    required double latitude,
    required double longitude,
    required BlitzerCountryPolicy? policy,
    String type = 'mobile',
    String? description,
  }) async {
    // Policy check
    final policyError = canCreateReportWithPolicy(policy);
    if (policyError != null) throw Exception(policyError);

    // Account age check (anti-abuse)
    final oldEnough = await isAccountOldEnough();
    if (!oldEnough) {
      throw Exception('Dein Account muss mindestens 24 Stunden alt sein');
    }

    // Duplicate check
    final isDuplicate = await isDuplicateReport(
      latitude: latitude,
      longitude: longitude,
      type: type,
    );
    if (isDuplicate) {
      throw Exception('Du hast bereits eine ähnliche Meldung in der Nähe');
    }

    return createReport(
      latitude: latitude,
      longitude: longitude,
      type: type,
      description: description,
    );
  }
}
