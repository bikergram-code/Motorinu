import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/meetup.dart';

/// Repository for external meetups / gatherings.
class MeetupsRepository {
  MeetupsRepository();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Map app community names to DB names.
  static String _mapCommunity(String community) {
    if (community == 'cargram') return 'motorgram';
    return community;
  }

  /// Get upcoming meetups for a community, sorted by date.
  Future<List<Meetup>> getUpcomingMeetups({
    required String community,
    String? region,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('meetups')
          .select()
          .eq('community', _mapCommunity(community))
          .gte('starts_at', DateTime.now().toUtc().toIso8601String());

      if (region != null && region.isNotEmpty) {
        query = query.eq('region', region);
      }

      final data = await query
          .order('starts_at', ascending: true)
          .range(offset, offset + limit - 1);

      return data.map<Meetup>((row) => Meetup.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('[MeetupsRepo] Error loading meetups: $e');
      return [];
    }
  }

  /// Get a single meetup by ID.
  Future<Meetup?> getMeetupById(int id) async {
    try {
      final data = await _supabase
          .from('meetups')
          .select()
          .eq('id', id)
          .single();
      return Meetup.fromSupabase(data);
    } catch (e) {
      debugPrint('[MeetupsRepo] Error loading meetup $id: $e');
      return null;
    }
  }
}
