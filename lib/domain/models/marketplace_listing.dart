import 'package:freezed_annotation/freezed_annotation.dart';

part 'marketplace_listing.freezed.dart';
part 'marketplace_listing.g.dart';

@freezed
abstract class MarketplaceListing with _$MarketplaceListing {
  const factory MarketplaceListing({
    required int id,
    required int userId,
    required String title,
    String? description,
    required double price,
    @Default('EUR') String currency,
    required String condition,
    required String category,
    String? location,
    double? latitude,
    double? longitude,
    @Default([]) List<String> imageUrls,
    String? sellerName,
    String? sellerAvatarUrl,
    double? sellerRating,
    int? reviewCount,
    @Default(false) bool isSold,
    @Default(false) bool isFeatured,
    DateTime? featuredUntil,
    String? stripePaymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MarketplaceListing;

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceListingFromJson(json);
}
