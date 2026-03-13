import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

/// A biker group (Fahrgruppe / Chat-Gruppe / Club).
@freezed
abstract class BikerGroup with _$BikerGroup {
  const factory BikerGroup({
    required int id,
    required String creatorId,
    required String name,
    String? description,
    String? avatarUrl,
    @Default('chat') String groupType, // ride, chat, club
    @Default('bikergram') String community,
    @Default(false) bool isRideActive,
    @Default('#4CAF50') String rideColor,
    @Default(true) bool isPublic,
    @Default(1) int memberCount,
    int? maxMembers,
    // Enriched fields (joined from profiles / group_members)
    String? creatorName,
    String? creatorAvatarUrl,
    @Default(false) bool isMember,
    @Default(false) bool isAdmin,
    int? conversationId,
    // Ride navigation fields
    double? destinationLat,
    double? destinationLng,
    String? destinationName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BikerGroup;

  factory BikerGroup.fromJson(Map<String, dynamic> json) =>
      _$BikerGroupFromJson(json);

  /// Create from Supabase row with joined profiles.
  factory BikerGroup.fromSupabase(
    Map<String, dynamic> data, {
    String? currentUserId,
    bool? isMember,
    bool? isAdmin,
    int? conversationId,
  }) {
    final profiles = data['profiles'] as Map<String, dynamic>?;
    return BikerGroup(
      id: (data['id'] as num).toInt(),
      creatorId: data['creator_id'] as String,
      name: data['name'] as String? ?? 'Gruppe',
      description: data['description'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      groupType: data['group_type'] as String? ?? 'chat',
      community: data['community'] as String? ?? 'bikergram',
      isRideActive: data['is_ride_active'] as bool? ?? false,
      rideColor: data['ride_color'] as String? ?? '#4CAF50',
      isPublic: data['is_public'] as bool? ?? true,
      memberCount: (data['member_count'] as num?)?.toInt() ?? 1,
      maxMembers: (data['max_members'] as num?)?.toInt(),
      creatorName: profiles?['display_name'] as String? ??
          profiles?['username'] as String?,
      creatorAvatarUrl: profiles?['avatar_url'] as String?,
      isMember: isMember ?? false,
      isAdmin: isAdmin ?? false,
      conversationId: conversationId,
      destinationLat: (data['destination_lat'] as num?)?.toDouble(),
      destinationLng: (data['destination_lng'] as num?)?.toDouble(),
      destinationName: data['destination_name'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
    );
  }
}

/// Group type constants with German labels.
class GroupType {
  static const String ride = 'ride';
  static const String chat = 'chat';
  static const String club = 'club';

  static const List<String> all = [ride, chat, club];

  static String label(String type) {
    switch (type) {
      case ride:
        return 'Fahrgruppe';
      case chat:
        return 'Chat-Gruppe';
      case club:
        return 'Club';
      default:
        return 'Gruppe';
    }
  }

  static String icon(String type) {
    switch (type) {
      case ride:
        return '\u{1F3CD}'; // motorcycle
      case chat:
        return '\u{1F4AC}'; // speech bubble
      case club:
        return '\u{1F6E1}'; // shield
      default:
        return '\u{1F465}'; // people
    }
  }
}
