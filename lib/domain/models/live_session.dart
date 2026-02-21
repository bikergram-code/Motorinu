import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_session.freezed.dart';
part 'live_session.g.dart';

@freezed
abstract class LiveSession with _$LiveSession {
  const factory LiveSession({
    required int id,
    required int userId,
    int? rideId,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    @Default(true) bool isActive,
    String? username,
    String? avatarUrl,
    String? bikeName,
    DateTime? startedAt,
    DateTime? endedAt,
  }) = _LiveSession;

  factory LiveSession.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionFromJson(json);
}
