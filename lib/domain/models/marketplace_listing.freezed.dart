// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marketplace_listing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarketplaceListing {

 int get id; int get userId; String get title; String? get description; double get price; String get currency; String get condition; String get category; String? get location; double? get latitude; double? get longitude; List<String> get imageUrls; String? get sellerName; String? get sellerAvatarUrl; double? get sellerRating; int? get reviewCount; bool get isSold; bool get isFeatured; DateTime? get featuredUntil; String? get stripePaymentId; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of MarketplaceListing
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarketplaceListingCopyWith<MarketplaceListing> get copyWith => _$MarketplaceListingCopyWithImpl<MarketplaceListing>(this as MarketplaceListing, _$identity);

  /// Serializes this MarketplaceListing to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarketplaceListing&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.category, category) || other.category == category)&&(identical(other.location, location) || other.location == location)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.sellerName, sellerName) || other.sellerName == sellerName)&&(identical(other.sellerAvatarUrl, sellerAvatarUrl) || other.sellerAvatarUrl == sellerAvatarUrl)&&(identical(other.sellerRating, sellerRating) || other.sellerRating == sellerRating)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.isSold, isSold) || other.isSold == isSold)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.featuredUntil, featuredUntil) || other.featuredUntil == featuredUntil)&&(identical(other.stripePaymentId, stripePaymentId) || other.stripePaymentId == stripePaymentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,title,description,price,currency,condition,category,location,latitude,longitude,const DeepCollectionEquality().hash(imageUrls),sellerName,sellerAvatarUrl,sellerRating,reviewCount,isSold,isFeatured,featuredUntil,stripePaymentId,createdAt,updatedAt]);

@override
String toString() {
  return 'MarketplaceListing(id: $id, userId: $userId, title: $title, description: $description, price: $price, currency: $currency, condition: $condition, category: $category, location: $location, latitude: $latitude, longitude: $longitude, imageUrls: $imageUrls, sellerName: $sellerName, sellerAvatarUrl: $sellerAvatarUrl, sellerRating: $sellerRating, reviewCount: $reviewCount, isSold: $isSold, isFeatured: $isFeatured, featuredUntil: $featuredUntil, stripePaymentId: $stripePaymentId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MarketplaceListingCopyWith<$Res>  {
  factory $MarketplaceListingCopyWith(MarketplaceListing value, $Res Function(MarketplaceListing) _then) = _$MarketplaceListingCopyWithImpl;
@useResult
$Res call({
 int id, int userId, String title, String? description, double price, String currency, String condition, String category, String? location, double? latitude, double? longitude, List<String> imageUrls, String? sellerName, String? sellerAvatarUrl, double? sellerRating, int? reviewCount, bool isSold, bool isFeatured, DateTime? featuredUntil, String? stripePaymentId, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$MarketplaceListingCopyWithImpl<$Res>
    implements $MarketplaceListingCopyWith<$Res> {
  _$MarketplaceListingCopyWithImpl(this._self, this._then);

  final MarketplaceListing _self;
  final $Res Function(MarketplaceListing) _then;

/// Create a copy of MarketplaceListing
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? title = null,Object? description = freezed,Object? price = null,Object? currency = null,Object? condition = null,Object? category = null,Object? location = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? imageUrls = null,Object? sellerName = freezed,Object? sellerAvatarUrl = freezed,Object? sellerRating = freezed,Object? reviewCount = freezed,Object? isSold = null,Object? isFeatured = null,Object? featuredUntil = freezed,Object? stripePaymentId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,sellerName: freezed == sellerName ? _self.sellerName : sellerName // ignore: cast_nullable_to_non_nullable
as String?,sellerAvatarUrl: freezed == sellerAvatarUrl ? _self.sellerAvatarUrl : sellerAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,sellerRating: freezed == sellerRating ? _self.sellerRating : sellerRating // ignore: cast_nullable_to_non_nullable
as double?,reviewCount: freezed == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int?,isSold: null == isSold ? _self.isSold : isSold // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,featuredUntil: freezed == featuredUntil ? _self.featuredUntil : featuredUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,stripePaymentId: freezed == stripePaymentId ? _self.stripePaymentId : stripePaymentId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MarketplaceListing].
extension MarketplaceListingPatterns on MarketplaceListing {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MarketplaceListing value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MarketplaceListing() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MarketplaceListing value)  $default,){
final _that = this;
switch (_that) {
case _MarketplaceListing():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MarketplaceListing value)?  $default,){
final _that = this;
switch (_that) {
case _MarketplaceListing() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  String title,  String? description,  double price,  String currency,  String condition,  String category,  String? location,  double? latitude,  double? longitude,  List<String> imageUrls,  String? sellerName,  String? sellerAvatarUrl,  double? sellerRating,  int? reviewCount,  bool isSold,  bool isFeatured,  DateTime? featuredUntil,  String? stripePaymentId,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MarketplaceListing() when $default != null:
return $default(_that.id,_that.userId,_that.title,_that.description,_that.price,_that.currency,_that.condition,_that.category,_that.location,_that.latitude,_that.longitude,_that.imageUrls,_that.sellerName,_that.sellerAvatarUrl,_that.sellerRating,_that.reviewCount,_that.isSold,_that.isFeatured,_that.featuredUntil,_that.stripePaymentId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  String title,  String? description,  double price,  String currency,  String condition,  String category,  String? location,  double? latitude,  double? longitude,  List<String> imageUrls,  String? sellerName,  String? sellerAvatarUrl,  double? sellerRating,  int? reviewCount,  bool isSold,  bool isFeatured,  DateTime? featuredUntil,  String? stripePaymentId,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MarketplaceListing():
return $default(_that.id,_that.userId,_that.title,_that.description,_that.price,_that.currency,_that.condition,_that.category,_that.location,_that.latitude,_that.longitude,_that.imageUrls,_that.sellerName,_that.sellerAvatarUrl,_that.sellerRating,_that.reviewCount,_that.isSold,_that.isFeatured,_that.featuredUntil,_that.stripePaymentId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  String title,  String? description,  double price,  String currency,  String condition,  String category,  String? location,  double? latitude,  double? longitude,  List<String> imageUrls,  String? sellerName,  String? sellerAvatarUrl,  double? sellerRating,  int? reviewCount,  bool isSold,  bool isFeatured,  DateTime? featuredUntil,  String? stripePaymentId,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MarketplaceListing() when $default != null:
return $default(_that.id,_that.userId,_that.title,_that.description,_that.price,_that.currency,_that.condition,_that.category,_that.location,_that.latitude,_that.longitude,_that.imageUrls,_that.sellerName,_that.sellerAvatarUrl,_that.sellerRating,_that.reviewCount,_that.isSold,_that.isFeatured,_that.featuredUntil,_that.stripePaymentId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MarketplaceListing implements MarketplaceListing {
  const _MarketplaceListing({required this.id, required this.userId, required this.title, this.description, required this.price, this.currency = 'EUR', required this.condition, required this.category, this.location, this.latitude, this.longitude, final  List<String> imageUrls = const [], this.sellerName, this.sellerAvatarUrl, this.sellerRating, this.reviewCount, this.isSold = false, this.isFeatured = false, this.featuredUntil, this.stripePaymentId, this.createdAt, this.updatedAt}): _imageUrls = imageUrls;
  factory _MarketplaceListing.fromJson(Map<String, dynamic> json) => _$MarketplaceListingFromJson(json);

@override final  int id;
@override final  int userId;
@override final  String title;
@override final  String? description;
@override final  double price;
@override@JsonKey() final  String currency;
@override final  String condition;
@override final  String category;
@override final  String? location;
@override final  double? latitude;
@override final  double? longitude;
 final  List<String> _imageUrls;
@override@JsonKey() List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override final  String? sellerName;
@override final  String? sellerAvatarUrl;
@override final  double? sellerRating;
@override final  int? reviewCount;
@override@JsonKey() final  bool isSold;
@override@JsonKey() final  bool isFeatured;
@override final  DateTime? featuredUntil;
@override final  String? stripePaymentId;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of MarketplaceListing
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarketplaceListingCopyWith<_MarketplaceListing> get copyWith => __$MarketplaceListingCopyWithImpl<_MarketplaceListing>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MarketplaceListingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarketplaceListing&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.category, category) || other.category == category)&&(identical(other.location, location) || other.location == location)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.sellerName, sellerName) || other.sellerName == sellerName)&&(identical(other.sellerAvatarUrl, sellerAvatarUrl) || other.sellerAvatarUrl == sellerAvatarUrl)&&(identical(other.sellerRating, sellerRating) || other.sellerRating == sellerRating)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.isSold, isSold) || other.isSold == isSold)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.featuredUntil, featuredUntil) || other.featuredUntil == featuredUntil)&&(identical(other.stripePaymentId, stripePaymentId) || other.stripePaymentId == stripePaymentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,title,description,price,currency,condition,category,location,latitude,longitude,const DeepCollectionEquality().hash(_imageUrls),sellerName,sellerAvatarUrl,sellerRating,reviewCount,isSold,isFeatured,featuredUntil,stripePaymentId,createdAt,updatedAt]);

@override
String toString() {
  return 'MarketplaceListing(id: $id, userId: $userId, title: $title, description: $description, price: $price, currency: $currency, condition: $condition, category: $category, location: $location, latitude: $latitude, longitude: $longitude, imageUrls: $imageUrls, sellerName: $sellerName, sellerAvatarUrl: $sellerAvatarUrl, sellerRating: $sellerRating, reviewCount: $reviewCount, isSold: $isSold, isFeatured: $isFeatured, featuredUntil: $featuredUntil, stripePaymentId: $stripePaymentId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MarketplaceListingCopyWith<$Res> implements $MarketplaceListingCopyWith<$Res> {
  factory _$MarketplaceListingCopyWith(_MarketplaceListing value, $Res Function(_MarketplaceListing) _then) = __$MarketplaceListingCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, String title, String? description, double price, String currency, String condition, String category, String? location, double? latitude, double? longitude, List<String> imageUrls, String? sellerName, String? sellerAvatarUrl, double? sellerRating, int? reviewCount, bool isSold, bool isFeatured, DateTime? featuredUntil, String? stripePaymentId, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$MarketplaceListingCopyWithImpl<$Res>
    implements _$MarketplaceListingCopyWith<$Res> {
  __$MarketplaceListingCopyWithImpl(this._self, this._then);

  final _MarketplaceListing _self;
  final $Res Function(_MarketplaceListing) _then;

/// Create a copy of MarketplaceListing
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? title = null,Object? description = freezed,Object? price = null,Object? currency = null,Object? condition = null,Object? category = null,Object? location = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? imageUrls = null,Object? sellerName = freezed,Object? sellerAvatarUrl = freezed,Object? sellerRating = freezed,Object? reviewCount = freezed,Object? isSold = null,Object? isFeatured = null,Object? featuredUntil = freezed,Object? stripePaymentId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_MarketplaceListing(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,sellerName: freezed == sellerName ? _self.sellerName : sellerName // ignore: cast_nullable_to_non_nullable
as String?,sellerAvatarUrl: freezed == sellerAvatarUrl ? _self.sellerAvatarUrl : sellerAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,sellerRating: freezed == sellerRating ? _self.sellerRating : sellerRating // ignore: cast_nullable_to_non_nullable
as double?,reviewCount: freezed == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int?,isSold: null == isSold ? _self.isSold : isSold // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,featuredUntil: freezed == featuredUntil ? _self.featuredUntil : featuredUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,stripePaymentId: freezed == stripePaymentId ? _self.stripePaymentId : stripePaymentId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
