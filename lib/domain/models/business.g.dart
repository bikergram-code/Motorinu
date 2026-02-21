// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Business _$BusinessFromJson(Map<String, dynamic> json) => _Business(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String?,
  category: json['category'] as String,
  address: json['address'] as String?,
  phone: json['phone'] as String?,
  website: json['website'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  priceRange: json['priceRange'] as String?,
  specializations:
      (json['specializations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  services:
      (json['services'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  imageUrl: json['imageUrl'] as String?,
  openingHours: json['openingHours'] as String?,
  isVerified: json['isVerified'] as bool? ?? false,
  isFeatured: json['isFeatured'] as bool? ?? false,
  featuredUntil: json['featuredUntil'] == null
      ? null
      : DateTime.parse(json['featuredUntil'] as String),
  avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BusinessToJson(_Business instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'name': instance.name,
  'description': instance.description,
  'category': instance.category,
  'address': instance.address,
  'phone': instance.phone,
  'website': instance.website,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'priceRange': instance.priceRange,
  'specializations': instance.specializations,
  'services': instance.services,
  'imageUrl': instance.imageUrl,
  'openingHours': instance.openingHours,
  'isVerified': instance.isVerified,
  'isFeatured': instance.isFeatured,
  'featuredUntil': instance.featuredUntil?.toIso8601String(),
  'avgRating': instance.avgRating,
  'reviewCount': instance.reviewCount,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

_BusinessReview _$BusinessReviewFromJson(Map<String, dynamic> json) =>
    _BusinessReview(
      id: (json['id'] as num).toInt(),
      businessId: (json['businessId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      rating: (json['rating'] as num).toInt(),
      body: json['body'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$BusinessReviewToJson(_BusinessReview instance) =>
    <String, dynamic>{
      'id': instance.id,
      'businessId': instance.businessId,
      'userId': instance.userId,
      'rating': instance.rating,
      'body': instance.body,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
