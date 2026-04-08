// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meetup.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Meetup {

 int get id; String get title; String? get description; String? get imageUrl; String? get locationText; double? get latitude; double? get longitude; DateTime get startsAt; DateTime? get endsAt; String? get sourceUrl; String? get sourceName; String get community; String? get region; bool get isVerified; DateTime? get createdAt;
/// Create a copy of Meetup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeetupCopyWith<Meetup> get copyWith => _$MeetupCopyWithImpl<Meetup>(this as Meetup, _$identity);

  /// Serializes this Meetup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Meetup&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.locationText, locationText) || other.locationText == locationText)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.sourceName, sourceName) || other.sourceName == sourceName)&&(identical(other.community, community) || other.community == community)&&(identical(other.region, region) || other.region == region)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,imageUrl,locationText,latitude,longitude,startsAt,endsAt,sourceUrl,sourceName,community,region,isVerified,createdAt);

@override
String toString() {
  return 'Meetup(id: $id, title: $title, description: $description, imageUrl: $imageUrl, locationText: $locationText, latitude: $latitude, longitude: $longitude, startsAt: $startsAt, endsAt: $endsAt, sourceUrl: $sourceUrl, sourceName: $sourceName, community: $community, region: $region, isVerified: $isVerified, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $MeetupCopyWith<$Res>  {
  factory $MeetupCopyWith(Meetup value, $Res Function(Meetup) _then) = _$MeetupCopyWithImpl;
@useResult
$Res call({
 int id, String title, String? description, String? imageUrl, String? locationText, double? latitude, double? longitude, DateTime startsAt, DateTime? endsAt, String? sourceUrl, String? sourceName, String community, String? region, bool isVerified, DateTime? createdAt
});




}
/// @nodoc
class _$MeetupCopyWithImpl<$Res>
    implements $MeetupCopyWith<$Res> {
  _$MeetupCopyWithImpl(this._self, this._then);

  final Meetup _self;
  final $Res Function(Meetup) _then;

/// Create a copy of Meetup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? imageUrl = freezed,Object? locationText = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? startsAt = null,Object? endsAt = freezed,Object? sourceUrl = freezed,Object? sourceName = freezed,Object? community = null,Object? region = freezed,Object? isVerified = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,locationText: freezed == locationText ? _self.locationText : locationText // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,sourceName: freezed == sourceName ? _self.sourceName : sourceName // ignore: cast_nullable_to_non_nullable
as String?,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Meetup].
extension MeetupPatterns on Meetup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Meetup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Meetup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Meetup value)  $default,){
final _that = this;
switch (_that) {
case _Meetup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Meetup value)?  $default,){
final _that = this;
switch (_that) {
case _Meetup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String? description,  String? imageUrl,  String? locationText,  double? latitude,  double? longitude,  DateTime startsAt,  DateTime? endsAt,  String? sourceUrl,  String? sourceName,  String community,  String? region,  bool isVerified,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Meetup() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.imageUrl,_that.locationText,_that.latitude,_that.longitude,_that.startsAt,_that.endsAt,_that.sourceUrl,_that.sourceName,_that.community,_that.region,_that.isVerified,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String? description,  String? imageUrl,  String? locationText,  double? latitude,  double? longitude,  DateTime startsAt,  DateTime? endsAt,  String? sourceUrl,  String? sourceName,  String community,  String? region,  bool isVerified,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Meetup():
return $default(_that.id,_that.title,_that.description,_that.imageUrl,_that.locationText,_that.latitude,_that.longitude,_that.startsAt,_that.endsAt,_that.sourceUrl,_that.sourceName,_that.community,_that.region,_that.isVerified,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String? description,  String? imageUrl,  String? locationText,  double? latitude,  double? longitude,  DateTime startsAt,  DateTime? endsAt,  String? sourceUrl,  String? sourceName,  String community,  String? region,  bool isVerified,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Meetup() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.imageUrl,_that.locationText,_that.latitude,_that.longitude,_that.startsAt,_that.endsAt,_that.sourceUrl,_that.sourceName,_that.community,_that.region,_that.isVerified,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Meetup implements Meetup {
  const _Meetup({required this.id, required this.title, this.description, this.imageUrl, this.locationText, this.latitude, this.longitude, required this.startsAt, this.endsAt, this.sourceUrl, this.sourceName, this.community = 'bikergram', this.region, this.isVerified = false, this.createdAt});
  factory _Meetup.fromJson(Map<String, dynamic> json) => _$MeetupFromJson(json);

@override final  int id;
@override final  String title;
@override final  String? description;
@override final  String? imageUrl;
@override final  String? locationText;
@override final  double? latitude;
@override final  double? longitude;
@override final  DateTime startsAt;
@override final  DateTime? endsAt;
@override final  String? sourceUrl;
@override final  String? sourceName;
@override@JsonKey() final  String community;
@override final  String? region;
@override@JsonKey() final  bool isVerified;
@override final  DateTime? createdAt;

/// Create a copy of Meetup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MeetupCopyWith<_Meetup> get copyWith => __$MeetupCopyWithImpl<_Meetup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MeetupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Meetup&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.locationText, locationText) || other.locationText == locationText)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl)&&(identical(other.sourceName, sourceName) || other.sourceName == sourceName)&&(identical(other.community, community) || other.community == community)&&(identical(other.region, region) || other.region == region)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,imageUrl,locationText,latitude,longitude,startsAt,endsAt,sourceUrl,sourceName,community,region,isVerified,createdAt);

@override
String toString() {
  return 'Meetup(id: $id, title: $title, description: $description, imageUrl: $imageUrl, locationText: $locationText, latitude: $latitude, longitude: $longitude, startsAt: $startsAt, endsAt: $endsAt, sourceUrl: $sourceUrl, sourceName: $sourceName, community: $community, region: $region, isVerified: $isVerified, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$MeetupCopyWith<$Res> implements $MeetupCopyWith<$Res> {
  factory _$MeetupCopyWith(_Meetup value, $Res Function(_Meetup) _then) = __$MeetupCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String? description, String? imageUrl, String? locationText, double? latitude, double? longitude, DateTime startsAt, DateTime? endsAt, String? sourceUrl, String? sourceName, String community, String? region, bool isVerified, DateTime? createdAt
});




}
/// @nodoc
class __$MeetupCopyWithImpl<$Res>
    implements _$MeetupCopyWith<$Res> {
  __$MeetupCopyWithImpl(this._self, this._then);

  final _Meetup _self;
  final $Res Function(_Meetup) _then;

/// Create a copy of Meetup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? imageUrl = freezed,Object? locationText = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? startsAt = null,Object? endsAt = freezed,Object? sourceUrl = freezed,Object? sourceName = freezed,Object? community = null,Object? region = freezed,Object? isVerified = null,Object? createdAt = freezed,}) {
  return _then(_Meetup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,locationText: freezed == locationText ? _self.locationText : locationText // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,sourceName: freezed == sourceName ? _self.sourceName : sourceName // ignore: cast_nullable_to_non_nullable
as String?,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,region: freezed == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String?,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
