import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride.freezed.dart';
part 'ride.g.dart';

@freezed
abstract class Ride with _$Ride {
  const factory Ride({
    required int id,
    required int userId,
    int? motorcycleId,
    required DateTime startedAt,
    DateTime? endedAt,
    @Default(0.0) double distanceKm,
    @Default(0) int durationSeconds,
    @Default(0.0) double avgSpeedKmh,
    @Default(0.0) double maxSpeedKmh,
    @Default(0) int xpEarned,
    @Default(false) bool isLiveGo,
    @Default([]) List<RidePoint> points,
    DateTime? createdAt,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);
}

@freezed
abstract class RidePoint with _$RidePoint {
  const factory RidePoint({
    required int id,
    required int rideId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    required DateTime timestamp,
  }) = _RidePoint;

  factory RidePoint.fromJson(Map<String, dynamic> json) =>
      _$RidePointFromJson(json);
}
