// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  email: json['email'] as String,
  username: json['username'] as String,
  displayName: json['displayName'] as String?,
  bikername: json['bikername'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  avatarUrlCargram: json['avatarUrlCargram'] as String?,
  bio: json['bio'] as String?,
  postalCode: json['postalCode'] as String?,
  country: json['country'] as String?,
  community: json['community'] as String?,
  language: json['language'] as String?,
  age: (json['age'] as num?)?.toInt(),
  birthYear: (json['birthYear'] as num?)?.toInt(),
  motoStartAge: (json['motoStartAge'] as num?)?.toInt(),
  carStartAge: (json['carStartAge'] as num?)?.toInt(),
  gender: json['gender'] as String?,
  showGender: json['showGender'] as String? ?? 'all',
  hasTrackExperience: json['hasTrackExperience'] as bool? ?? false,
  experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
  trackExperience: json['trackExperience'] as bool? ?? false,
  bikeCount: (json['bikeCount'] as num?)?.toInt() ?? 0,
  diySkills:
      (json['diySkills'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  xpTotal: (json['xpTotal'] as num?)?.toInt() ?? 0,
  level: (json['level'] as num?)?.toInt() ?? 1,
  followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
  followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
  postCount: (json['postCount'] as num?)?.toInt() ?? 0,
  rideCount: (json['rideCount'] as num?)?.toInt() ?? 0,
  isPremium: json['isPremium'] as bool? ?? false,
  isBusiness: json['isBusiness'] as bool? ?? false,
  isVerified: json['isVerified'] as bool? ?? false,
  homeLat: (json['homeLat'] as num?)?.toDouble(),
  homeLng: (json['homeLng'] as num?)?.toDouble(),
  stripeCustomerId: json['stripeCustomerId'] as String?,
  lastActiveAt: json['lastActiveAt'] == null
      ? null
      : DateTime.parse(json['lastActiveAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'username': instance.username,
  'displayName': instance.displayName,
  'bikername': instance.bikername,
  'avatarUrl': instance.avatarUrl,
  'avatarUrlCargram': instance.avatarUrlCargram,
  'bio': instance.bio,
  'postalCode': instance.postalCode,
  'country': instance.country,
  'community': instance.community,
  'language': instance.language,
  'age': instance.age,
  'birthYear': instance.birthYear,
  'motoStartAge': instance.motoStartAge,
  'carStartAge': instance.carStartAge,
  'gender': instance.gender,
  'showGender': instance.showGender,
  'hasTrackExperience': instance.hasTrackExperience,
  'experienceYears': instance.experienceYears,
  'trackExperience': instance.trackExperience,
  'bikeCount': instance.bikeCount,
  'diySkills': instance.diySkills,
  'xpTotal': instance.xpTotal,
  'level': instance.level,
  'followerCount': instance.followerCount,
  'followingCount': instance.followingCount,
  'postCount': instance.postCount,
  'rideCount': instance.rideCount,
  'isPremium': instance.isPremium,
  'isBusiness': instance.isBusiness,
  'isVerified': instance.isVerified,
  'homeLat': instance.homeLat,
  'homeLng': instance.homeLng,
  'stripeCustomerId': instance.stripeCustomerId,
  'lastActiveAt': instance.lastActiveAt?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
};
