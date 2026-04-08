import 'package:freezed_annotation/freezed_annotation.dart';

part 'meetup.freezed.dart';
part 'meetup.g.dart';

/// An external meetup / gathering (aggregated from external sources).
@freezed
abstract class Meetup with _$Meetup {
  const factory Meetup({
    required int id,
    required String title,
    String? description,
    String? imageUrl,
    String? locationText,
    double? latitude,
    double? longitude,
    required DateTime startsAt,
    DateTime? endsAt,
    String? sourceUrl,
    String? sourceName,
    @Default('bikergram') String community,
    String? region,
    @Default(false) bool isVerified,
    DateTime? createdAt,
  }) = _Meetup;

  factory Meetup.fromJson(Map<String, dynamic> json) =>
      _$MeetupFromJson(json);

  /// Create from Supabase row.
  factory Meetup.fromSupabase(Map<String, dynamic> data) {
    return Meetup(
      id: data['id'] as int,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      imageUrl: data['image_url'] as String?,
      locationText: data['location_text'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      startsAt: DateTime.parse(data['starts_at'] as String),
      endsAt: data['ends_at'] != null
          ? DateTime.parse(data['ends_at'] as String)
          : null,
      sourceUrl: data['source_url'] as String?,
      sourceName: data['source_name'] as String?,
      community: data['community'] as String? ?? 'bikergram',
      region: data['region'] as String?,
      isVerified: data['is_verified'] as bool? ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
    );
  }
}
