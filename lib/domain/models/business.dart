import 'package:freezed_annotation/freezed_annotation.dart';

part 'business.freezed.dart';
part 'business.g.dart';

@freezed
abstract class Business with _$Business {
  const factory Business({
    required int id,
    required int userId,
    required String name,
    String? description,
    required String category,
    String? address,
    String? phone,
    String? website,
    double? latitude,
    double? longitude,
    String? priceRange,
    @Default([]) List<String> specializations,
    @Default([]) List<String> services,
    String? imageUrl,
    String? openingHours,
    @Default(false) bool isVerified,
    @Default(false) bool isFeatured,
    DateTime? featuredUntil,
    @Default(0.0) double avgRating,
    @Default(0) int reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Business;

  factory Business.fromJson(Map<String, dynamic> json) =>
      _$BusinessFromJson(json);
}

@freezed
abstract class BusinessReview with _$BusinessReview {
  const factory BusinessReview({
    required int id,
    required int businessId,
    required int userId,
    required int rating,
    String? body,
    String? username,
    String? avatarUrl,
    DateTime? createdAt,
  }) = _BusinessReview;

  factory BusinessReview.fromJson(Map<String, dynamic> json) =>
      _$BusinessReviewFromJson(json);
}
