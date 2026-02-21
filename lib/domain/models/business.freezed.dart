// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Business {

 int get id; int get userId; String get name; String? get description; String get category; String? get address; String? get phone; String? get website; double? get latitude; double? get longitude; String? get priceRange; List<String> get specializations; List<String> get services; String? get imageUrl; String? get openingHours; bool get isVerified; bool get isFeatured; DateTime? get featuredUntil; double get avgRating; int get reviewCount; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of Business
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessCopyWith<Business> get copyWith => _$BusinessCopyWithImpl<Business>(this as Business, _$identity);

  /// Serializes this Business to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Business&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.address, address) || other.address == address)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.website, website) || other.website == website)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.priceRange, priceRange) || other.priceRange == priceRange)&&const DeepCollectionEquality().equals(other.specializations, specializations)&&const DeepCollectionEquality().equals(other.services, services)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.openingHours, openingHours) || other.openingHours == openingHours)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.featuredUntil, featuredUntil) || other.featuredUntil == featuredUntil)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,name,description,category,address,phone,website,latitude,longitude,priceRange,const DeepCollectionEquality().hash(specializations),const DeepCollectionEquality().hash(services),imageUrl,openingHours,isVerified,isFeatured,featuredUntil,avgRating,reviewCount,createdAt,updatedAt]);

@override
String toString() {
  return 'Business(id: $id, userId: $userId, name: $name, description: $description, category: $category, address: $address, phone: $phone, website: $website, latitude: $latitude, longitude: $longitude, priceRange: $priceRange, specializations: $specializations, services: $services, imageUrl: $imageUrl, openingHours: $openingHours, isVerified: $isVerified, isFeatured: $isFeatured, featuredUntil: $featuredUntil, avgRating: $avgRating, reviewCount: $reviewCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BusinessCopyWith<$Res>  {
  factory $BusinessCopyWith(Business value, $Res Function(Business) _then) = _$BusinessCopyWithImpl;
@useResult
$Res call({
 int id, int userId, String name, String? description, String category, String? address, String? phone, String? website, double? latitude, double? longitude, String? priceRange, List<String> specializations, List<String> services, String? imageUrl, String? openingHours, bool isVerified, bool isFeatured, DateTime? featuredUntil, double avgRating, int reviewCount, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$BusinessCopyWithImpl<$Res>
    implements $BusinessCopyWith<$Res> {
  _$BusinessCopyWithImpl(this._self, this._then);

  final Business _self;
  final $Res Function(Business) _then;

/// Create a copy of Business
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? name = null,Object? description = freezed,Object? category = null,Object? address = freezed,Object? phone = freezed,Object? website = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? priceRange = freezed,Object? specializations = null,Object? services = null,Object? imageUrl = freezed,Object? openingHours = freezed,Object? isVerified = null,Object? isFeatured = null,Object? featuredUntil = freezed,Object? avgRating = null,Object? reviewCount = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,priceRange: freezed == priceRange ? _self.priceRange : priceRange // ignore: cast_nullable_to_non_nullable
as String?,specializations: null == specializations ? _self.specializations : specializations // ignore: cast_nullable_to_non_nullable
as List<String>,services: null == services ? _self.services : services // ignore: cast_nullable_to_non_nullable
as List<String>,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,openingHours: freezed == openingHours ? _self.openingHours : openingHours // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,featuredUntil: freezed == featuredUntil ? _self.featuredUntil : featuredUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,avgRating: null == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Business].
extension BusinessPatterns on Business {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Business value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Business() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Business value)  $default,){
final _that = this;
switch (_that) {
case _Business():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Business value)?  $default,){
final _that = this;
switch (_that) {
case _Business() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  String name,  String? description,  String category,  String? address,  String? phone,  String? website,  double? latitude,  double? longitude,  String? priceRange,  List<String> specializations,  List<String> services,  String? imageUrl,  String? openingHours,  bool isVerified,  bool isFeatured,  DateTime? featuredUntil,  double avgRating,  int reviewCount,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Business() when $default != null:
return $default(_that.id,_that.userId,_that.name,_that.description,_that.category,_that.address,_that.phone,_that.website,_that.latitude,_that.longitude,_that.priceRange,_that.specializations,_that.services,_that.imageUrl,_that.openingHours,_that.isVerified,_that.isFeatured,_that.featuredUntil,_that.avgRating,_that.reviewCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  String name,  String? description,  String category,  String? address,  String? phone,  String? website,  double? latitude,  double? longitude,  String? priceRange,  List<String> specializations,  List<String> services,  String? imageUrl,  String? openingHours,  bool isVerified,  bool isFeatured,  DateTime? featuredUntil,  double avgRating,  int reviewCount,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Business():
return $default(_that.id,_that.userId,_that.name,_that.description,_that.category,_that.address,_that.phone,_that.website,_that.latitude,_that.longitude,_that.priceRange,_that.specializations,_that.services,_that.imageUrl,_that.openingHours,_that.isVerified,_that.isFeatured,_that.featuredUntil,_that.avgRating,_that.reviewCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  String name,  String? description,  String category,  String? address,  String? phone,  String? website,  double? latitude,  double? longitude,  String? priceRange,  List<String> specializations,  List<String> services,  String? imageUrl,  String? openingHours,  bool isVerified,  bool isFeatured,  DateTime? featuredUntil,  double avgRating,  int reviewCount,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Business() when $default != null:
return $default(_that.id,_that.userId,_that.name,_that.description,_that.category,_that.address,_that.phone,_that.website,_that.latitude,_that.longitude,_that.priceRange,_that.specializations,_that.services,_that.imageUrl,_that.openingHours,_that.isVerified,_that.isFeatured,_that.featuredUntil,_that.avgRating,_that.reviewCount,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Business implements Business {
  const _Business({required this.id, required this.userId, required this.name, this.description, required this.category, this.address, this.phone, this.website, this.latitude, this.longitude, this.priceRange, final  List<String> specializations = const [], final  List<String> services = const [], this.imageUrl, this.openingHours, this.isVerified = false, this.isFeatured = false, this.featuredUntil, this.avgRating = 0.0, this.reviewCount = 0, this.createdAt, this.updatedAt}): _specializations = specializations,_services = services;
  factory _Business.fromJson(Map<String, dynamic> json) => _$BusinessFromJson(json);

@override final  int id;
@override final  int userId;
@override final  String name;
@override final  String? description;
@override final  String category;
@override final  String? address;
@override final  String? phone;
@override final  String? website;
@override final  double? latitude;
@override final  double? longitude;
@override final  String? priceRange;
 final  List<String> _specializations;
@override@JsonKey() List<String> get specializations {
  if (_specializations is EqualUnmodifiableListView) return _specializations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_specializations);
}

 final  List<String> _services;
@override@JsonKey() List<String> get services {
  if (_services is EqualUnmodifiableListView) return _services;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_services);
}

@override final  String? imageUrl;
@override final  String? openingHours;
@override@JsonKey() final  bool isVerified;
@override@JsonKey() final  bool isFeatured;
@override final  DateTime? featuredUntil;
@override@JsonKey() final  double avgRating;
@override@JsonKey() final  int reviewCount;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Business
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessCopyWith<_Business> get copyWith => __$BusinessCopyWithImpl<_Business>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Business&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.address, address) || other.address == address)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.website, website) || other.website == website)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.priceRange, priceRange) || other.priceRange == priceRange)&&const DeepCollectionEquality().equals(other._specializations, _specializations)&&const DeepCollectionEquality().equals(other._services, _services)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.openingHours, openingHours) || other.openingHours == openingHours)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.featuredUntil, featuredUntil) || other.featuredUntil == featuredUntil)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,name,description,category,address,phone,website,latitude,longitude,priceRange,const DeepCollectionEquality().hash(_specializations),const DeepCollectionEquality().hash(_services),imageUrl,openingHours,isVerified,isFeatured,featuredUntil,avgRating,reviewCount,createdAt,updatedAt]);

@override
String toString() {
  return 'Business(id: $id, userId: $userId, name: $name, description: $description, category: $category, address: $address, phone: $phone, website: $website, latitude: $latitude, longitude: $longitude, priceRange: $priceRange, specializations: $specializations, services: $services, imageUrl: $imageUrl, openingHours: $openingHours, isVerified: $isVerified, isFeatured: $isFeatured, featuredUntil: $featuredUntil, avgRating: $avgRating, reviewCount: $reviewCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BusinessCopyWith<$Res> implements $BusinessCopyWith<$Res> {
  factory _$BusinessCopyWith(_Business value, $Res Function(_Business) _then) = __$BusinessCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, String name, String? description, String category, String? address, String? phone, String? website, double? latitude, double? longitude, String? priceRange, List<String> specializations, List<String> services, String? imageUrl, String? openingHours, bool isVerified, bool isFeatured, DateTime? featuredUntil, double avgRating, int reviewCount, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$BusinessCopyWithImpl<$Res>
    implements _$BusinessCopyWith<$Res> {
  __$BusinessCopyWithImpl(this._self, this._then);

  final _Business _self;
  final $Res Function(_Business) _then;

/// Create a copy of Business
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? name = null,Object? description = freezed,Object? category = null,Object? address = freezed,Object? phone = freezed,Object? website = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? priceRange = freezed,Object? specializations = null,Object? services = null,Object? imageUrl = freezed,Object? openingHours = freezed,Object? isVerified = null,Object? isFeatured = null,Object? featuredUntil = freezed,Object? avgRating = null,Object? reviewCount = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Business(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,priceRange: freezed == priceRange ? _self.priceRange : priceRange // ignore: cast_nullable_to_non_nullable
as String?,specializations: null == specializations ? _self._specializations : specializations // ignore: cast_nullable_to_non_nullable
as List<String>,services: null == services ? _self._services : services // ignore: cast_nullable_to_non_nullable
as List<String>,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,openingHours: freezed == openingHours ? _self.openingHours : openingHours // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,featuredUntil: freezed == featuredUntil ? _self.featuredUntil : featuredUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,avgRating: null == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$BusinessReview {

 int get id; int get businessId; int get userId; int get rating; String? get body; String? get username; String? get avatarUrl; DateTime? get createdAt;
/// Create a copy of BusinessReview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessReviewCopyWith<BusinessReview> get copyWith => _$BusinessReviewCopyWithImpl<BusinessReview>(this as BusinessReview, _$identity);

  /// Serializes this BusinessReview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessReview&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.body, body) || other.body == body)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,businessId,userId,rating,body,username,avatarUrl,createdAt);

@override
String toString() {
  return 'BusinessReview(id: $id, businessId: $businessId, userId: $userId, rating: $rating, body: $body, username: $username, avatarUrl: $avatarUrl, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $BusinessReviewCopyWith<$Res>  {
  factory $BusinessReviewCopyWith(BusinessReview value, $Res Function(BusinessReview) _then) = _$BusinessReviewCopyWithImpl;
@useResult
$Res call({
 int id, int businessId, int userId, int rating, String? body, String? username, String? avatarUrl, DateTime? createdAt
});




}
/// @nodoc
class _$BusinessReviewCopyWithImpl<$Res>
    implements $BusinessReviewCopyWith<$Res> {
  _$BusinessReviewCopyWithImpl(this._self, this._then);

  final BusinessReview _self;
  final $Res Function(BusinessReview) _then;

/// Create a copy of BusinessReview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? businessId = null,Object? userId = null,Object? rating = null,Object? body = freezed,Object? username = freezed,Object? avatarUrl = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessReview].
extension BusinessReviewPatterns on BusinessReview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessReview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessReview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessReview value)  $default,){
final _that = this;
switch (_that) {
case _BusinessReview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessReview value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessReview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int businessId,  int userId,  int rating,  String? body,  String? username,  String? avatarUrl,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessReview() when $default != null:
return $default(_that.id,_that.businessId,_that.userId,_that.rating,_that.body,_that.username,_that.avatarUrl,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int businessId,  int userId,  int rating,  String? body,  String? username,  String? avatarUrl,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _BusinessReview():
return $default(_that.id,_that.businessId,_that.userId,_that.rating,_that.body,_that.username,_that.avatarUrl,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int businessId,  int userId,  int rating,  String? body,  String? username,  String? avatarUrl,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _BusinessReview() when $default != null:
return $default(_that.id,_that.businessId,_that.userId,_that.rating,_that.body,_that.username,_that.avatarUrl,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessReview implements BusinessReview {
  const _BusinessReview({required this.id, required this.businessId, required this.userId, required this.rating, this.body, this.username, this.avatarUrl, this.createdAt});
  factory _BusinessReview.fromJson(Map<String, dynamic> json) => _$BusinessReviewFromJson(json);

@override final  int id;
@override final  int businessId;
@override final  int userId;
@override final  int rating;
@override final  String? body;
@override final  String? username;
@override final  String? avatarUrl;
@override final  DateTime? createdAt;

/// Create a copy of BusinessReview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessReviewCopyWith<_BusinessReview> get copyWith => __$BusinessReviewCopyWithImpl<_BusinessReview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessReviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessReview&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.body, body) || other.body == body)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,businessId,userId,rating,body,username,avatarUrl,createdAt);

@override
String toString() {
  return 'BusinessReview(id: $id, businessId: $businessId, userId: $userId, rating: $rating, body: $body, username: $username, avatarUrl: $avatarUrl, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$BusinessReviewCopyWith<$Res> implements $BusinessReviewCopyWith<$Res> {
  factory _$BusinessReviewCopyWith(_BusinessReview value, $Res Function(_BusinessReview) _then) = __$BusinessReviewCopyWithImpl;
@override @useResult
$Res call({
 int id, int businessId, int userId, int rating, String? body, String? username, String? avatarUrl, DateTime? createdAt
});




}
/// @nodoc
class __$BusinessReviewCopyWithImpl<$Res>
    implements _$BusinessReviewCopyWith<$Res> {
  __$BusinessReviewCopyWithImpl(this._self, this._then);

  final _BusinessReview _self;
  final $Res Function(_BusinessReview) _then;

/// Create a copy of BusinessReview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? businessId = null,Object? userId = null,Object? rating = null,Object? body = freezed,Object? username = freezed,Object? avatarUrl = freezed,Object? createdAt = freezed,}) {
  return _then(_BusinessReview(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
