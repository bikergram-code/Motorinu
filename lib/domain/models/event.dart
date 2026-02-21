import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

@freezed
abstract class BikerEvent with _$BikerEvent {
  const factory BikerEvent({
    required int id,
    required int creatorId,
    required String title,
    String? description,
    String? imageUrl,
    String? location,
    double? latitude,
    double? longitude,
    required DateTime startsAt,
    DateTime? endsAt,
    int? maxParticipants,
    @Default(0) int participantCount,
    @Default(false) bool isFeatured,
    String? creatorName,
    String? creatorAvatarUrl,
    String? myStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BikerEvent;

  factory BikerEvent.fromJson(Map<String, dynamic> json) =>
      _$BikerEventFromJson(json);
}
