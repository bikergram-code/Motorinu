import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/xp_calculator.dart';

class RideRecord {
  final int id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceKm;
  final int durationSeconds;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int xpEarned;
  final DateTime? createdAt;

  const RideRecord({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.distanceKm = 0,
    this.durationSeconds = 0,
    this.avgSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.xpEarned = 0,
    this.createdAt,
  });

  factory RideRecord.fromJson(Map<String, dynamic> json) {
    return RideRecord(
      id: json['id'] as int,
      userId: '${json['user_id']}',
      startedAt: DateTime.parse('${json['started_at']}'),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse('${json['ended_at']}')
          : null,
      distanceKm: double.tryParse('${json['distance_km']}') ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      avgSpeedKmh: double.tryParse('${json['avg_speed_kmh']}') ?? 0,
      maxSpeedKmh: double.tryParse('${json['max_speed_kmh']}') ?? 0,
      xpEarned: json['xp_earned'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    final d = startedAt;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

class RideRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<RideRecord>> getRideHistory({int page = 1, int limit = 20}) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    final offset = (page - 1) * limit;

    final data = await _supabase
        .from('rides')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data.map<RideRecord>((json) => RideRecord.fromJson(json)).toList();
  }

  Future<RideRecord> saveRide({
    required DateTime startedAt,
    required DateTime endedAt,
    required double distanceKm,
    required int durationSeconds,
    required double avgSpeedKmh,
    double maxSpeedKmh = 0,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Nicht eingeloggt');

    // XP: 1 per km + Distanz-Bonus (pro 1000km → 100 XP extra)
    final xpEarned = XpCalculator.totalXp(distanceKm);

    final data = await _supabase
        .from('rides')
        .insert({
          'user_id': userId,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'distance_km': distanceKm,
          'duration_seconds': durationSeconds,
          'avg_speed_kmh': avgSpeedKmh,
          'max_speed_kmh': maxSpeedKmh,
          'xp_earned': xpEarned,
        })
        .select()
        .single();

    // Award XP via central method (updates profile + logs transaction)
    if (xpEarned > 0) {
      XpCalculator.awardXp(userId, xpEarned, 'ride');
    }

    // Update total_km on profile (readable by everyone, unlike rides table)
    try {
      await _supabase.rpc('increment_total_km', params: {
        'uid': userId,
        'km': distanceKm,
      }).catchError((_) async {
        // Fallback: direct increment if RPC doesn't exist
        final profile = await _supabase
            .from('profiles')
            .select('total_km')
            .eq('id', userId)
            .maybeSingle();
        final current = (profile?['total_km'] as num?)?.toDouble() ?? 0;
        await _supabase
            .from('profiles')
            .update({'total_km': current + distanceKm})
            .eq('id', userId);
      });
    } catch (e) {
      debugPrint('[Ride] Update total_km error (non-fatal): $e');
    }

    return RideRecord.fromJson(data);
  }

  Future<Map<String, dynamic>> getRideStats({String? forUserId}) async {
    final userId = forUserId ?? _currentUserId;
    if (userId == null) return {'totalRides': 0, 'totalKm': 0.0, 'totalXp': 0};

    // For OTHER users: read total_km from profiles (RLS allows reading profiles).
    // The rides table itself is blocked by RLS for non-owners.
    if (forUserId != null && forUserId != _currentUserId) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('total_km')
            .eq('id', forUserId)
            .maybeSingle();
        final km = (profile?['total_km'] as num?)?.toDouble() ?? 0;
        return {
          'totalRides': 0, // Can't count — RLS blocked
          'totalKm': km,
          'totalSeconds': 0,
          'totalXp': 0,
        };
      } catch (e) {
        debugPrint('[Ride] Read profile total_km error: $e');
        return {'totalRides': 0, 'totalKm': 0.0, 'totalXp': 0};
      }
    }

    // For OWN profile: query rides directly (RLS allows own rides)
    final data = await _supabase
        .from('rides')
        .select('distance_km, duration_seconds, xp_earned')
        .eq('user_id', userId);

    double totalKm = 0;
    int totalSeconds = 0;
    int totalXp = 0;

    for (final ride in data) {
      totalKm += double.tryParse('${ride['distance_km']}') ?? 0;
      totalSeconds += ride['duration_seconds'] as int? ?? 0;
      totalXp += ride['xp_earned'] as int? ?? 0;
    }

    return {
      'totalRides': data.length,
      'totalKm': totalKm,
      'totalSeconds': totalSeconds,
      'totalXp': totalXp,
    };
  }
}
