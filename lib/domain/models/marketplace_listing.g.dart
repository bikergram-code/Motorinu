// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarketplaceListing _$MarketplaceListingFromJson(Map<String, dynamic> json) =>
    _MarketplaceListing(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      condition: json['condition'] as String,
      category: json['category'] as String,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sellerName: json['sellerName'] as String?,
      sellerAvatarUrl: json['sellerAvatarUrl'] as String?,
      sellerRating: (json['sellerRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      isSold: json['isSold'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      featuredUntil: json['featuredUntil'] == null
          ? null
          : DateTime.parse(json['featuredUntil'] as String),
      stripePaymentId: json['stripePaymentId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$MarketplaceListingToJson(_MarketplaceListing instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'price': instance.price,
      'currency': instance.currency,
      'condition': instance.condition,
      'category': instance.category,
      'location': instance.location,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'imageUrls': instance.imageUrls,
      'sellerName': instance.sellerName,
      'sellerAvatarUrl': instance.sellerAvatarUrl,
      'sellerRating': instance.sellerRating,
      'reviewCount': instance.reviewCount,
      'isSold': instance.isSold,
      'isFeatured': instance.isFeatured,
      'featuredUntil': instance.featuredUntil?.toIso8601String(),
      'stripePaymentId': instance.stripePaymentId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
