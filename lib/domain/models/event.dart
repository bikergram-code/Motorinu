import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

/// A motorsport / community event.
@freezed
abstract class BikerEvent with _$BikerEvent {
  const factory BikerEvent({
    required int id,
    required String userId, // UUID from auth.users
    required String title,
    String? description,
    String? imageUrl,
    String? location, // location_text in DB
    double? latitude,
    double? longitude,
    required DateTime startsAt,
    DateTime? endsAt,
    int? maxParticipants,
    @Default(0) int participantCount,
    @Default(false) bool isFeatured,
    @Default('meetup') String category, // meetup, trackday, ride, fair, race
    @Default('bikergram') String community,
    String? creatorName,
    String? creatorAvatarUrl,
    String? myStatus, // going, interested, null
    String? ticketUrl, // Affiliate ticket link
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BikerEvent;

  factory BikerEvent.fromJson(Map<String, dynamic> json) =>
      _$BikerEventFromJson(json);

  /// Create from Supabase row with joined profiles + participant info.
  factory BikerEvent.fromSupabase(
    Map<String, dynamic> data, {
    String? currentUserId,
    String? myStatus,
    int? participantCount,
  }) {
    final profiles = data['profiles'] as Map<String, dynamic>?;
    return BikerEvent(
      id: (data['id'] as num).toInt(),
      userId: data['user_id'] as String,
      title: data['title'] as String? ?? 'Event',
      description: data['description'] as String?,
      imageUrl: data['image_url'] as String?,
      location: data['location_text'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      startsAt: DateTime.tryParse(data['starts_at'] as String? ?? '') ??
          DateTime.now(),
      endsAt: data['ends_at'] != null
          ? DateTime.tryParse(data['ends_at'] as String)
          : null,
      maxParticipants: (data['max_participants'] as num?)?.toInt(),
      participantCount: participantCount ?? 0,
      isFeatured: data['is_featured'] as bool? ?? false,
      category: data['category'] as String? ?? 'meetup',
      community: data['community'] as String? ?? 'bikergram',
      creatorName:
          profiles?['display_name'] as String? ??
          profiles?['username'] as String?,
      creatorAvatarUrl: profiles?['avatar_url'] as String?,
      myStatus: myStatus,
      ticketUrl: data['ticket_url'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
    );
  }
}

/// Event category constants with German labels.
class EventCategory {
  static const String meetup = 'meetup';
  static const String trackday = 'trackday';
  static const String ride = 'ride';
  static const String fair = 'fair';
  static const String race = 'race';

  static const List<String> all = [meetup, trackday, ride, fair, race];

  static String label(String category) {
    switch (category) {
      case meetup:
        return 'Treffen';
      case trackday:
        return 'Trackday';
      case ride:
        return 'Ausfahrt';
      case fair:
        return 'Messe';
      case race:
        return 'Rennen';
      default:
        return 'Event';
    }
  }

  static String icon(String category) {
    // Returns emoji for category
    switch (category) {
      case meetup:
        return '\u{1F91D}'; // handshake
      case trackday:
        return '\u{1F3CE}'; // racing car
      case ride:
        return '\u{1F3CD}'; // motorcycle
      case fair:
        return '\u{1F3AA}'; // circus tent
      case race:
        return '\u{1F3C1}'; // checkered flag
      default:
        return '\u{1F4C5}'; // calendar
    }
  }
}
