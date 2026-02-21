import 'package:freezed_annotation/freezed_annotation.dart';

part 'motorcycle.freezed.dart';
part 'motorcycle.g.dart';

@freezed
abstract class Motorcycle with _$Motorcycle {
  const factory Motorcycle({
    required int id,
    required int userId,
    required String make,
    required String model,
    required int year,
    String? imageUrl,
    String? category,
    @Default(false) bool isPrimary,
    @Default({}) Map<String, String> specifications,
    @Default([]) List<Modification> modifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Motorcycle;

  factory Motorcycle.fromJson(Map<String, dynamic> json) =>
      _$MotorcycleFromJson(json);
}

@freezed
abstract class Modification with _$Modification {
  const factory Modification({
    required int id,
    required int motorcycleId,
    required String title,
    String? description,
    double? cost,
    DateTime? date,
    String? beforeImageUrl,
    String? afterImageUrl,
    DateTime? createdAt,
  }) = _Modification;

  factory Modification.fromJson(Map<String, dynamic> json) =>
      _$ModificationFromJson(json);
}
