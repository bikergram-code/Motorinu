import 'package:freezed_annotation/freezed_annotation.dart';

part 'blitzer.freezed.dart';
part 'blitzer.g.dart';

@freezed
abstract class BlitzerReport with _$BlitzerReport {
  const factory BlitzerReport({
    required int id,
    required int userId,
    required String type,
    required double latitude,
    required double longitude,
    int? speedLimit,
    String? description,
    @Default(true) bool isActive,
    @Default(0) int confirmations,
    String? reporterName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BlitzerReport;

  factory BlitzerReport.fromJson(Map<String, dynamic> json) =>
      _$BlitzerReportFromJson(json);
}
