import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    /// Supabase uses UUID strings; legacy PHP used int.
    /// We store as String now. Legacy ints are converted via toString().
    required String id,
    required String email,
    required String username,
    String? displayName,
    String? bikername,
    String? avatarUrl,
    String? avatarUrlCargram,
    String? bio,
    String? postalCode,
    String? community,
    String? language,
    int? age,
    int? birthYear,
    int? motoStartAge,
    int? carStartAge,
    @Default(false) bool hasTrackExperience,
    @Default(0) int experienceYears,
    @Default(false) bool trackExperience,
    @Default(0) int bikeCount,
    @Default([]) List<String> diySkills,
    @Default(0) int xpTotal,
    @Default(1) int level,
    @Default(0) int followerCount,
    @Default(0) int followingCount,
    @Default(0) int postCount,
    @Default(0) int rideCount,
    @Default(false) bool isPremium,
    @Default(false) bool isBusiness,
    @Default(false) bool isVerified,
    String? stripeCustomerId,
    DateTime? lastActiveAt,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
