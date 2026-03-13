import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/event.dart';

/// Repository for motorsport & community events.
class EventsRepository {
  EventsRepository();

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  static const _profileSelect =
      '*, profiles!events_user_id_fkey(username, display_name, avatar_url)';

  /// Whether the `category` column has been confirmed in the DB.
  bool _hasCategoryColumn = true; // optimistic, switches on first error

  /// Map app community names to DB event community names.
  /// App uses 'cargram', but events use 'motorgram' for car motorsport.
  static String _mapCommunity(String community) {
    if (community == 'cargram') return 'motorgram';
    return community;
  }

  /// Get the OTHER community name for cross-promotion.
  static String _otherCommunity(String current) {
    if (current == 'bikergram') return 'motorgram';
    return 'bikergram';
  }

  // ═══════════════════════════════════════════════════
  //  BROWSE / DISCOVERY
  // ═══════════════════════════════════════════════════

  /// Get upcoming events, optionally filtered by category.
  Future<List<BikerEvent>> getUpcomingEvents({
    String? category,
    String? community,
    int limit = 50,
    int offset = 0,
  }) async {
    final communityFilter = _mapCommunity(community ?? 'bikergram');

    try {
      var query = _supabase
          .from('events')
          .select(_profileSelect)
          .eq('community', communityFilter)
          .gte('starts_at', DateTime.now().toUtc().toIso8601String());

      if (category != null && _hasCategoryColumn) {
        query = query.eq('category', category);
      }

      final data = await query
          .order('starts_at', ascending: true)
          .range(offset, offset + limit - 1);

      return _enrichWithParticipants(data);
    } catch (e) {
      // If error mentions 'category' column, retry without it
      if (e.toString().contains('category')) {
        _hasCategoryColumn = false;
        debugPrint('[EventsRepo] category column missing, falling back');
        return getUpcomingEvents(
          community: community,
          limit: limit,
          offset: offset,
        );
      }
      rethrow;
    }
  }

  /// Get events happening today.
  Future<List<BikerEvent>> getEventsForToday({
    String? community,
  }) async {
    final communityFilter = _mapCommunity(community ?? 'bikergram');
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toUtc();
    final todayEnd = todayStart.add(const Duration(days: 1));

    final data = await _supabase
        .from('events')
        .select(_profileSelect)
        .eq('community', communityFilter)
        .gte('starts_at', todayStart.toIso8601String())
        .lt('starts_at', todayEnd.toIso8601String())
        .order('starts_at', ascending: true);

    return _enrichWithParticipants(data);
  }

  /// Get a single event by ID.
  Future<BikerEvent?> getEventById(int eventId) async {
    final data = await _supabase
        .from('events')
        .select(_profileSelect)
        .eq('id', eventId)
        .maybeSingle();

    if (data == null) return null;

    final enriched = await _enrichWithParticipants([data]);
    return enriched.isNotEmpty ? enriched.first : null;
  }

  /// Get events created by the current user.
  Future<List<BikerEvent>> getMyEvents({int limit = 50}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final data = await _supabase
        .from('events')
        .select(_profileSelect)
        .eq('user_id', userId)
        .order('starts_at', ascending: false)
        .limit(limit);

    return _enrichWithParticipants(data);
  }

  // ═══════════════════════════════════════════════════
  //  CROSS-PROMOTION (andere Community)
  // ═══════════════════════════════════════════════════

  /// Get upcoming events from the OTHER community for cross-promotion.
  /// If current = bikergram, returns motorgram events (and vice versa).
  Future<List<BikerEvent>> getCrossPromoEvents({
    required String currentCommunity,
    int limit = 3,
  }) async {
    final otherCommunity = _otherCommunity(currentCommunity);

    try {
      final data = await _supabase
          .from('events')
          .select(_profileSelect)
          .eq('community', otherCommunity)
          .gte('starts_at', DateTime.now().toUtc().toIso8601String())
          .order('starts_at', ascending: true)
          .limit(limit);

      return _enrichWithParticipants(data);
    } catch (e) {
      debugPrint('[EventsRepo] Cross-promo query error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  //  CREATE / UPDATE / DELETE
  // ═══════════════════════════════════════════════════

  /// Create a new event.
  Future<BikerEvent> createEvent({
    required String title,
    String? description,
    String? imageUrl,
    String? location,
    double? latitude,
    double? longitude,
    required DateTime startsAt,
    DateTime? endsAt,
    String? category,
    String? community,
    int? maxParticipants,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final insertData = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'community': _mapCommunity(community ?? 'bikergram'),
    };

    if (description != null && description.isNotEmpty) {
      insertData['description'] = description;
    }
    if (imageUrl != null) insertData['image_url'] = imageUrl;
    if (location != null && location.isNotEmpty) {
      insertData['location_text'] = location;
    }
    if (latitude != null) insertData['latitude'] = latitude;
    if (longitude != null) insertData['longitude'] = longitude;
    if (endsAt != null) {
      insertData['ends_at'] = endsAt.toUtc().toIso8601String();
    }
    if (maxParticipants != null) {
      insertData['max_participants'] = maxParticipants;
    }

    // Only include category if column exists
    if (_hasCategoryColumn) {
      insertData['category'] = category ?? 'meetup';
    }

    try {
      final data = await _supabase
          .from('events')
          .insert(insertData)
          .select(_profileSelect)
          .single();

      return BikerEvent.fromSupabase(data);
    } catch (e) {
      // If category column doesn't exist, retry without it
      if (e.toString().contains('category') && _hasCategoryColumn) {
        _hasCategoryColumn = false;
        insertData.remove('category');
        debugPrint('[EventsRepo] category column missing, retrying insert');

        final data = await _supabase
            .from('events')
            .insert(insertData)
            .select(_profileSelect)
            .single();

        return BikerEvent.fromSupabase(data);
      }
      rethrow;
    }
  }

  /// Update an existing event (only by creator).
  Future<BikerEvent> updateEvent(
    int eventId, {
    String? title,
    String? description,
    String? imageUrl,
    String? location,
    DateTime? startsAt,
    DateTime? endsAt,
    String? category,
    int? maxParticipants,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (imageUrl != null) updates['image_url'] = imageUrl;
    if (location != null) updates['location_text'] = location;
    if (startsAt != null) {
      updates['starts_at'] = startsAt.toUtc().toIso8601String();
    }
    if (endsAt != null) {
      updates['ends_at'] = endsAt.toUtc().toIso8601String();
    }
    if (category != null && _hasCategoryColumn) {
      updates['category'] = category;
    }
    if (maxParticipants != null) updates['max_participants'] = maxParticipants;

    final data = await _supabase
        .from('events')
        .update(updates)
        .eq('id', eventId)
        .select(_profileSelect)
        .single();

    return BikerEvent.fromSupabase(data);
  }

  /// Delete an event (only by creator).
  Future<void> deleteEvent(int eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
  }

  // ═══════════════════════════════════════════════════
  //  PARTICIPATION
  // ═══════════════════════════════════════════════════

  /// Join an event (upsert into event_participants).
  Future<void> joinEvent(int eventId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase.from('event_participants').upsert({
      'event_id': eventId,
      'user_id': userId,
      'status': 'going',
    });
  }

  /// Leave an event.
  Future<void> leaveEvent(int eventId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase
        .from('event_participants')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  // ═══════════════════════════════════════════════════
  //  IMAGE UPLOAD
  // ═══════════════════════════════════════════════════

  /// Upload an event header image. Returns the public URL.
  Future<String> uploadEventImage(Uint8List bytes, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'events/$userId/$timestamp.jpg';

    await _supabase.storage.from('events').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _supabase.storage.from('events').getPublicUrl(path);
  }

  // ═══════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════

  /// Enrich events with participant count + current user status.
  Future<List<BikerEvent>> _enrichWithParticipants(
    List<dynamic> rawEvents,
  ) async {
    final userId = _currentUserId;
    final events = <BikerEvent>[];

    for (final raw in rawEvents) {
      final data = raw as Map<String, dynamic>;
      final eventId = (data['id'] as num).toInt();

      // Get participant count (going)
      int count = 0;
      String? myStatus;

      try {
        final participants = await _supabase
            .from('event_participants')
            .select('user_id, status')
            .eq('event_id', eventId)
            .eq('status', 'going');

        count = participants.length;

        // Check current user's status
        if (userId != null) {
          for (final p in participants) {
            if (p['user_id'] == userId) {
              myStatus = p['status'] as String?;
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('[EventsRepo] Participant query error: $e');
      }

      events.add(BikerEvent.fromSupabase(
        data,
        currentUserId: userId,
        myStatus: myStatus,
        participantCount: count,
      ));
    }

    return events;
  }
}
