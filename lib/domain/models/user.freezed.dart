// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$User {

/// Supabase uses UUID strings; legacy PHP used int.
/// We store as String now. Legacy ints are converted via toString().
 String get id; String get email; String get username; String? get displayName; String? get bikername; String? get avatarUrl; String? get avatarUrlCargram; String? get bio; String? get postalCode; String? get country; String? get community; String? get language; int? get age; int? get birthYear; int? get motoStartAge; int? get carStartAge; String? get gender; String get showGender; bool get hasTrackExperience; int get experienceYears; bool get trackExperience; int get bikeCount; List<String> get diySkills; int get xpTotal; int get level; int get followerCount; int get followingCount; int get postCount; int get rideCount; bool get isPremium; bool get isBusiness; bool get isVerified; double? get homeLat; double? get homeLng; String? get stripeCustomerId; DateTime? get lastActiveAt; DateTime? get createdAt;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.bikername, bikername) || other.bikername == bikername)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.avatarUrlCargram, avatarUrlCargram) || other.avatarUrlCargram == avatarUrlCargram)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.country, country) || other.country == country)&&(identical(other.community, community) || other.community == community)&&(identical(other.language, language) || other.language == language)&&(identical(other.age, age) || other.age == age)&&(identical(other.birthYear, birthYear) || other.birthYear == birthYear)&&(identical(other.motoStartAge, motoStartAge) || other.motoStartAge == motoStartAge)&&(identical(other.carStartAge, carStartAge) || other.carStartAge == carStartAge)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.showGender, showGender) || other.showGender == showGender)&&(identical(other.hasTrackExperience, hasTrackExperience) || other.hasTrackExperience == hasTrackExperience)&&(identical(other.experienceYears, experienceYears) || other.experienceYears == experienceYears)&&(identical(other.trackExperience, trackExperience) || other.trackExperience == trackExperience)&&(identical(other.bikeCount, bikeCount) || other.bikeCount == bikeCount)&&const DeepCollectionEquality().equals(other.diySkills, diySkills)&&(identical(other.xpTotal, xpTotal) || other.xpTotal == xpTotal)&&(identical(other.level, level) || other.level == level)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.rideCount, rideCount) || other.rideCount == rideCount)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.isBusiness, isBusiness) || other.isBusiness == isBusiness)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.homeLat, homeLat) || other.homeLat == homeLat)&&(identical(other.homeLng, homeLng) || other.homeLng == homeLng)&&(identical(other.stripeCustomerId, stripeCustomerId) || other.stripeCustomerId == stripeCustomerId)&&(identical(other.lastActiveAt, lastActiveAt) || other.lastActiveAt == lastActiveAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,email,username,displayName,bikername,avatarUrl,avatarUrlCargram,bio,postalCode,country,community,language,age,birthYear,motoStartAge,carStartAge,gender,showGender,hasTrackExperience,experienceYears,trackExperience,bikeCount,const DeepCollectionEquality().hash(diySkills),xpTotal,level,followerCount,followingCount,postCount,rideCount,isPremium,isBusiness,isVerified,homeLat,homeLng,stripeCustomerId,lastActiveAt,createdAt]);

@override
String toString() {
  return 'User(id: $id, email: $email, username: $username, displayName: $displayName, bikername: $bikername, avatarUrl: $avatarUrl, avatarUrlCargram: $avatarUrlCargram, bio: $bio, postalCode: $postalCode, country: $country, community: $community, language: $language, age: $age, birthYear: $birthYear, motoStartAge: $motoStartAge, carStartAge: $carStartAge, gender: $gender, showGender: $showGender, hasTrackExperience: $hasTrackExperience, experienceYears: $experienceYears, trackExperience: $trackExperience, bikeCount: $bikeCount, diySkills: $diySkills, xpTotal: $xpTotal, level: $level, followerCount: $followerCount, followingCount: $followingCount, postCount: $postCount, rideCount: $rideCount, isPremium: $isPremium, isBusiness: $isBusiness, isVerified: $isVerified, homeLat: $homeLat, homeLng: $homeLng, stripeCustomerId: $stripeCustomerId, lastActiveAt: $lastActiveAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String email, String username, String? displayName, String? bikername, String? avatarUrl, String? avatarUrlCargram, String? bio, String? postalCode, String? country, String? community, String? language, int? age, int? birthYear, int? motoStartAge, int? carStartAge, String? gender, String showGender, bool hasTrackExperience, int experienceYears, bool trackExperience, int bikeCount, List<String> diySkills, int xpTotal, int level, int followerCount, int followingCount, int postCount, int rideCount, bool isPremium, bool isBusiness, bool isVerified, double? homeLat, double? homeLng, String? stripeCustomerId, DateTime? lastActiveAt, DateTime? createdAt
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? username = null,Object? displayName = freezed,Object? bikername = freezed,Object? avatarUrl = freezed,Object? avatarUrlCargram = freezed,Object? bio = freezed,Object? postalCode = freezed,Object? country = freezed,Object? community = freezed,Object? language = freezed,Object? age = freezed,Object? birthYear = freezed,Object? motoStartAge = freezed,Object? carStartAge = freezed,Object? gender = freezed,Object? showGender = null,Object? hasTrackExperience = null,Object? experienceYears = null,Object? trackExperience = null,Object? bikeCount = null,Object? diySkills = null,Object? xpTotal = null,Object? level = null,Object? followerCount = null,Object? followingCount = null,Object? postCount = null,Object? rideCount = null,Object? isPremium = null,Object? isBusiness = null,Object? isVerified = null,Object? homeLat = freezed,Object? homeLng = freezed,Object? stripeCustomerId = freezed,Object? lastActiveAt = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,bikername: freezed == bikername ? _self.bikername : bikername // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,avatarUrlCargram: freezed == avatarUrlCargram ? _self.avatarUrlCargram : avatarUrlCargram // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,postalCode: freezed == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,community: freezed == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,birthYear: freezed == birthYear ? _self.birthYear : birthYear // ignore: cast_nullable_to_non_nullable
as int?,motoStartAge: freezed == motoStartAge ? _self.motoStartAge : motoStartAge // ignore: cast_nullable_to_non_nullable
as int?,carStartAge: freezed == carStartAge ? _self.carStartAge : carStartAge // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,showGender: null == showGender ? _self.showGender : showGender // ignore: cast_nullable_to_non_nullable
as String,hasTrackExperience: null == hasTrackExperience ? _self.hasTrackExperience : hasTrackExperience // ignore: cast_nullable_to_non_nullable
as bool,experienceYears: null == experienceYears ? _self.experienceYears : experienceYears // ignore: cast_nullable_to_non_nullable
as int,trackExperience: null == trackExperience ? _self.trackExperience : trackExperience // ignore: cast_nullable_to_non_nullable
as bool,bikeCount: null == bikeCount ? _self.bikeCount : bikeCount // ignore: cast_nullable_to_non_nullable
as int,diySkills: null == diySkills ? _self.diySkills : diySkills // ignore: cast_nullable_to_non_nullable
as List<String>,xpTotal: null == xpTotal ? _self.xpTotal : xpTotal // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,rideCount: null == rideCount ? _self.rideCount : rideCount // ignore: cast_nullable_to_non_nullable
as int,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,isBusiness: null == isBusiness ? _self.isBusiness : isBusiness // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,homeLat: freezed == homeLat ? _self.homeLat : homeLat // ignore: cast_nullable_to_non_nullable
as double?,homeLng: freezed == homeLng ? _self.homeLng : homeLng // ignore: cast_nullable_to_non_nullable
as double?,stripeCustomerId: freezed == stripeCustomerId ? _self.stripeCustomerId : stripeCustomerId // ignore: cast_nullable_to_non_nullable
as String?,lastActiveAt: freezed == lastActiveAt ? _self.lastActiveAt : lastActiveAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  String username,  String? displayName,  String? bikername,  String? avatarUrl,  String? avatarUrlCargram,  String? bio,  String? postalCode,  String? country,  String? community,  String? language,  int? age,  int? birthYear,  int? motoStartAge,  int? carStartAge,  String? gender,  String showGender,  bool hasTrackExperience,  int experienceYears,  bool trackExperience,  int bikeCount,  List<String> diySkills,  int xpTotal,  int level,  int followerCount,  int followingCount,  int postCount,  int rideCount,  bool isPremium,  bool isBusiness,  bool isVerified,  double? homeLat,  double? homeLng,  String? stripeCustomerId,  DateTime? lastActiveAt,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.username,_that.displayName,_that.bikername,_that.avatarUrl,_that.avatarUrlCargram,_that.bio,_that.postalCode,_that.country,_that.community,_that.language,_that.age,_that.birthYear,_that.motoStartAge,_that.carStartAge,_that.gender,_that.showGender,_that.hasTrackExperience,_that.experienceYears,_that.trackExperience,_that.bikeCount,_that.diySkills,_that.xpTotal,_that.level,_that.followerCount,_that.followingCount,_that.postCount,_that.rideCount,_that.isPremium,_that.isBusiness,_that.isVerified,_that.homeLat,_that.homeLng,_that.stripeCustomerId,_that.lastActiveAt,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  String username,  String? displayName,  String? bikername,  String? avatarUrl,  String? avatarUrlCargram,  String? bio,  String? postalCode,  String? country,  String? community,  String? language,  int? age,  int? birthYear,  int? motoStartAge,  int? carStartAge,  String? gender,  String showGender,  bool hasTrackExperience,  int experienceYears,  bool trackExperience,  int bikeCount,  List<String> diySkills,  int xpTotal,  int level,  int followerCount,  int followingCount,  int postCount,  int rideCount,  bool isPremium,  bool isBusiness,  bool isVerified,  double? homeLat,  double? homeLng,  String? stripeCustomerId,  DateTime? lastActiveAt,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.email,_that.username,_that.displayName,_that.bikername,_that.avatarUrl,_that.avatarUrlCargram,_that.bio,_that.postalCode,_that.country,_that.community,_that.language,_that.age,_that.birthYear,_that.motoStartAge,_that.carStartAge,_that.gender,_that.showGender,_that.hasTrackExperience,_that.experienceYears,_that.trackExperience,_that.bikeCount,_that.diySkills,_that.xpTotal,_that.level,_that.followerCount,_that.followingCount,_that.postCount,_that.rideCount,_that.isPremium,_that.isBusiness,_that.isVerified,_that.homeLat,_that.homeLng,_that.stripeCustomerId,_that.lastActiveAt,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  String username,  String? displayName,  String? bikername,  String? avatarUrl,  String? avatarUrlCargram,  String? bio,  String? postalCode,  String? country,  String? community,  String? language,  int? age,  int? birthYear,  int? motoStartAge,  int? carStartAge,  String? gender,  String showGender,  bool hasTrackExperience,  int experienceYears,  bool trackExperience,  int bikeCount,  List<String> diySkills,  int xpTotal,  int level,  int followerCount,  int followingCount,  int postCount,  int rideCount,  bool isPremium,  bool isBusiness,  bool isVerified,  double? homeLat,  double? homeLng,  String? stripeCustomerId,  DateTime? lastActiveAt,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.username,_that.displayName,_that.bikername,_that.avatarUrl,_that.avatarUrlCargram,_that.bio,_that.postalCode,_that.country,_that.community,_that.language,_that.age,_that.birthYear,_that.motoStartAge,_that.carStartAge,_that.gender,_that.showGender,_that.hasTrackExperience,_that.experienceYears,_that.trackExperience,_that.bikeCount,_that.diySkills,_that.xpTotal,_that.level,_that.followerCount,_that.followingCount,_that.postCount,_that.rideCount,_that.isPremium,_that.isBusiness,_that.isVerified,_that.homeLat,_that.homeLng,_that.stripeCustomerId,_that.lastActiveAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User implements User {
  const _User({required this.id, required this.email, required this.username, this.displayName, this.bikername, this.avatarUrl, this.avatarUrlCargram, this.bio, this.postalCode, this.country, this.community, this.language, this.age, this.birthYear, this.motoStartAge, this.carStartAge, this.gender, this.showGender = 'all', this.hasTrackExperience = false, this.experienceYears = 0, this.trackExperience = false, this.bikeCount = 0, final  List<String> diySkills = const [], this.xpTotal = 0, this.level = 1, this.followerCount = 0, this.followingCount = 0, this.postCount = 0, this.rideCount = 0, this.isPremium = false, this.isBusiness = false, this.isVerified = false, this.homeLat, this.homeLng, this.stripeCustomerId, this.lastActiveAt, this.createdAt}): _diySkills = diySkills;
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

/// Supabase uses UUID strings; legacy PHP used int.
/// We store as String now. Legacy ints are converted via toString().
@override final  String id;
@override final  String email;
@override final  String username;
@override final  String? displayName;
@override final  String? bikername;
@override final  String? avatarUrl;
@override final  String? avatarUrlCargram;
@override final  String? bio;
@override final  String? postalCode;
@override final  String? country;
@override final  String? community;
@override final  String? language;
@override final  int? age;
@override final  int? birthYear;
@override final  int? motoStartAge;
@override final  int? carStartAge;
@override final  String? gender;
@override@JsonKey() final  String showGender;
@override@JsonKey() final  bool hasTrackExperience;
@override@JsonKey() final  int experienceYears;
@override@JsonKey() final  bool trackExperience;
@override@JsonKey() final  int bikeCount;
 final  List<String> _diySkills;
@override@JsonKey() List<String> get diySkills {
  if (_diySkills is EqualUnmodifiableListView) return _diySkills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diySkills);
}

@override@JsonKey() final  int xpTotal;
@override@JsonKey() final  int level;
@override@JsonKey() final  int followerCount;
@override@JsonKey() final  int followingCount;
@override@JsonKey() final  int postCount;
@override@JsonKey() final  int rideCount;
@override@JsonKey() final  bool isPremium;
@override@JsonKey() final  bool isBusiness;
@override@JsonKey() final  bool isVerified;
@override final  double? homeLat;
@override final  double? homeLng;
@override final  String? stripeCustomerId;
@override final  DateTime? lastActiveAt;
@override final  DateTime? createdAt;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.bikername, bikername) || other.bikername == bikername)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.avatarUrlCargram, avatarUrlCargram) || other.avatarUrlCargram == avatarUrlCargram)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.country, country) || other.country == country)&&(identical(other.community, community) || other.community == community)&&(identical(other.language, language) || other.language == language)&&(identical(other.age, age) || other.age == age)&&(identical(other.birthYear, birthYear) || other.birthYear == birthYear)&&(identical(other.motoStartAge, motoStartAge) || other.motoStartAge == motoStartAge)&&(identical(other.carStartAge, carStartAge) || other.carStartAge == carStartAge)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.showGender, showGender) || other.showGender == showGender)&&(identical(other.hasTrackExperience, hasTrackExperience) || other.hasTrackExperience == hasTrackExperience)&&(identical(other.experienceYears, experienceYears) || other.experienceYears == experienceYears)&&(identical(other.trackExperience, trackExperience) || other.trackExperience == trackExperience)&&(identical(other.bikeCount, bikeCount) || other.bikeCount == bikeCount)&&const DeepCollectionEquality().equals(other._diySkills, _diySkills)&&(identical(other.xpTotal, xpTotal) || other.xpTotal == xpTotal)&&(identical(other.level, level) || other.level == level)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postCount, postCount) || other.postCount == postCount)&&(identical(other.rideCount, rideCount) || other.rideCount == rideCount)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.isBusiness, isBusiness) || other.isBusiness == isBusiness)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.homeLat, homeLat) || other.homeLat == homeLat)&&(identical(other.homeLng, homeLng) || other.homeLng == homeLng)&&(identical(other.stripeCustomerId, stripeCustomerId) || other.stripeCustomerId == stripeCustomerId)&&(identical(other.lastActiveAt, lastActiveAt) || other.lastActiveAt == lastActiveAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,email,username,displayName,bikername,avatarUrl,avatarUrlCargram,bio,postalCode,country,community,language,age,birthYear,motoStartAge,carStartAge,gender,showGender,hasTrackExperience,experienceYears,trackExperience,bikeCount,const DeepCollectionEquality().hash(_diySkills),xpTotal,level,followerCount,followingCount,postCount,rideCount,isPremium,isBusiness,isVerified,homeLat,homeLng,stripeCustomerId,lastActiveAt,createdAt]);

@override
String toString() {
  return 'User(id: $id, email: $email, username: $username, displayName: $displayName, bikername: $bikername, avatarUrl: $avatarUrl, avatarUrlCargram: $avatarUrlCargram, bio: $bio, postalCode: $postalCode, country: $country, community: $community, language: $language, age: $age, birthYear: $birthYear, motoStartAge: $motoStartAge, carStartAge: $carStartAge, gender: $gender, showGender: $showGender, hasTrackExperience: $hasTrackExperience, experienceYears: $experienceYears, trackExperience: $trackExperience, bikeCount: $bikeCount, diySkills: $diySkills, xpTotal: $xpTotal, level: $level, followerCount: $followerCount, followingCount: $followingCount, postCount: $postCount, rideCount: $rideCount, isPremium: $isPremium, isBusiness: $isBusiness, isVerified: $isVerified, homeLat: $homeLat, homeLng: $homeLng, stripeCustomerId: $stripeCustomerId, lastActiveAt: $lastActiveAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, String username, String? displayName, String? bikername, String? avatarUrl, String? avatarUrlCargram, String? bio, String? postalCode, String? country, String? community, String? language, int? age, int? birthYear, int? motoStartAge, int? carStartAge, String? gender, String showGender, bool hasTrackExperience, int experienceYears, bool trackExperience, int bikeCount, List<String> diySkills, int xpTotal, int level, int followerCount, int followingCount, int postCount, int rideCount, bool isPremium, bool isBusiness, bool isVerified, double? homeLat, double? homeLng, String? stripeCustomerId, DateTime? lastActiveAt, DateTime? createdAt
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? username = null,Object? displayName = freezed,Object? bikername = freezed,Object? avatarUrl = freezed,Object? avatarUrlCargram = freezed,Object? bio = freezed,Object? postalCode = freezed,Object? country = freezed,Object? community = freezed,Object? language = freezed,Object? age = freezed,Object? birthYear = freezed,Object? motoStartAge = freezed,Object? carStartAge = freezed,Object? gender = freezed,Object? showGender = null,Object? hasTrackExperience = null,Object? experienceYears = null,Object? trackExperience = null,Object? bikeCount = null,Object? diySkills = null,Object? xpTotal = null,Object? level = null,Object? followerCount = null,Object? followingCount = null,Object? postCount = null,Object? rideCount = null,Object? isPremium = null,Object? isBusiness = null,Object? isVerified = null,Object? homeLat = freezed,Object? homeLng = freezed,Object? stripeCustomerId = freezed,Object? lastActiveAt = freezed,Object? createdAt = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,bikername: freezed == bikername ? _self.bikername : bikername // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,avatarUrlCargram: freezed == avatarUrlCargram ? _self.avatarUrlCargram : avatarUrlCargram // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,postalCode: freezed == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,community: freezed == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,birthYear: freezed == birthYear ? _self.birthYear : birthYear // ignore: cast_nullable_to_non_nullable
as int?,motoStartAge: freezed == motoStartAge ? _self.motoStartAge : motoStartAge // ignore: cast_nullable_to_non_nullable
as int?,carStartAge: freezed == carStartAge ? _self.carStartAge : carStartAge // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,showGender: null == showGender ? _self.showGender : showGender // ignore: cast_nullable_to_non_nullable
as String,hasTrackExperience: null == hasTrackExperience ? _self.hasTrackExperience : hasTrackExperience // ignore: cast_nullable_to_non_nullable
as bool,experienceYears: null == experienceYears ? _self.experienceYears : experienceYears // ignore: cast_nullable_to_non_nullable
as int,trackExperience: null == trackExperience ? _self.trackExperience : trackExperience // ignore: cast_nullable_to_non_nullable
as bool,bikeCount: null == bikeCount ? _self.bikeCount : bikeCount // ignore: cast_nullable_to_non_nullable
as int,diySkills: null == diySkills ? _self._diySkills : diySkills // ignore: cast_nullable_to_non_nullable
as List<String>,xpTotal: null == xpTotal ? _self.xpTotal : xpTotal // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,postCount: null == postCount ? _self.postCount : postCount // ignore: cast_nullable_to_non_nullable
as int,rideCount: null == rideCount ? _self.rideCount : rideCount // ignore: cast_nullable_to_non_nullable
as int,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,isBusiness: null == isBusiness ? _self.isBusiness : isBusiness // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,homeLat: freezed == homeLat ? _self.homeLat : homeLat // ignore: cast_nullable_to_non_nullable
as double?,homeLng: freezed == homeLng ? _self.homeLng : homeLng // ignore: cast_nullable_to_non_nullable
as double?,stripeCustomerId: freezed == stripeCustomerId ? _self.stripeCustomerId : stripeCustomerId // ignore: cast_nullable_to_non_nullable
as String?,lastActiveAt: freezed == lastActiveAt ? _self.lastActiveAt : lastActiveAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
