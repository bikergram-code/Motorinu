// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BikerEvent {

 int get id; String get userId;// UUID from auth.users
 String get title; String? get description; String? get imageUrl; String? get location;// location_text in DB
 double? get latitude; double? get longitude; DateTime get startsAt; DateTime? get endsAt; int? get maxParticipants; int get participantCount; bool get isFeatured; String get category;// meetup, trackday, ride, fair, race
 String get community; String? get creatorName; String? get creatorAvatarUrl; String? get myStatus;// going, interested, null
 String? get ticketUrl;// Affiliate ticket link
 DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of BikerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BikerEventCopyWith<BikerEvent> get copyWith => _$BikerEventCopyWithImpl<BikerEvent>(this as BikerEvent, _$identity);

  /// Serializes this BikerEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BikerEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.location, location) || other.location == location)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.category, category) || other.category == category)&&(identical(other.community, community) || other.community == community)&&(identical(other.creatorName, creatorName) || other.creatorName == creatorName)&&(identical(other.creatorAvatarUrl, creatorAvatarUrl) || other.creatorAvatarUrl == creatorAvatarUrl)&&(identical(other.myStatus, myStatus) || other.myStatus == myStatus)&&(identical(other.ticketUrl, ticketUrl) || other.ticketUrl == ticketUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,title,description,imageUrl,location,latitude,longitude,startsAt,endsAt,maxParticipants,participantCount,isFeatured,category,community,creatorName,creatorAvatarUrl,myStatus,ticketUrl,createdAt,updatedAt]);

@override
String toString() {
  return 'BikerEvent(id: $id, userId: $userId, title: $title, description: $description, imageUrl: $imageUrl, location: $location, latitude: $latitude, longitude: $longitude, startsAt: $startsAt, endsAt: $endsAt, maxParticipants: $maxParticipants, participantCount: $participantCount, isFeatured: $isFeatured, category: $category, community: $community, creatorName: $creatorName, creatorAvatarUrl: $creatorAvatarUrl, myStatus: $myStatus, ticketUrl: $ticketUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BikerEventCopyWith<$Res>  {
  factory $BikerEventCopyWith(BikerEvent value, $Res Function(BikerEvent) _then) = _$BikerEventCopyWithImpl;
@useResult
$Res call({
 int id, String userId, String title, String? description, String? imageUrl, String? location, double? latitude, double? longitude, DateTime startsAt, DateTime? endsAt, int? maxParticipants, int participantCount, bool isFeatured, String category, String community, String? creatorName, String? creatorAvatarUrl, String? myStatus, String? ticketUrl, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$BikerEventCopyWithImpl<$Res>
    implements $BikerEventCopyWith<$Res> {
  _$BikerEventCopyWithImpl(this._self, this._then);

  final BikerEvent _self;
  final $Res Function(BikerEvent) _then;

/// Create a copy of BikerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? title = null,Object? description = freezed,Object? imageUrl = freezed,Object? location = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? startsAt = null,Object? endsAt = freezed,Object? maxParticipants = freezed,Object? participantCount = null,Object? isFeatured = null,Object? category = null,Object? community = null,Object? creatorName = freezed,Object? creatorAvatarUrl = freezed,Object? myStatus = freezed,Object? ticketUrl = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,creatorName: freezed == creatorName ? _self.creatorName : creatorName // ignore: cast_nullable_to_non_nullable
as String?,creatorAvatarUrl: freezed == creatorAvatarUrl ? _self.creatorAvatarUrl : creatorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,myStatus: freezed == myStatus ? _self.myStatus : myStatus // ignore: cast_nullable_to_non_nullable
as String?,ticketUrl: freezed == ticketUrl ? _self.ticketUrl : ticketUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BikerEvent].
extension BikerEventPatterns on BikerEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BikerEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BikerEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BikerEvent value)  $default,){
final _that = this;
switch (_that) {
case _BikerEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BikerEvent value)?  $default,){
final _that = this;
switch (_that) {
case _BikerEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String userId,  String title,  String? description,  String? imageUrl,  String? location,  double? latitude,  double? longitude,  DateTime startsAt,  DateTime? endsAt,  int? maxParticipants,  int participantCount,  bool isFeatured,  String category,  String community,  String? creatorName,  String? creatorAvatarUrl,  String? myStatus,  String? ticketUrl,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BikerEvent() when $default != null:
return $default(_that.id,_that.userId,_that.title,_that.description,_that.imageUrl,_that.location,_that.latitude,_that.longitude,_that.startsAt,_that.endsAt,_that.maxParticipants,_that.participantCount,_that.isFeatured,_that.category,_that.community,_that.creatorName,_that.creatorAvatarUrl,_that.myStatus,_that.ticketUrl,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String userId,  String title,  String? description,  String? imageUrl,  String? location,  double? latitude,  double? longitude,  DateTime startsAt,  DateTime? endsAt,  int? maxParticipants,  int participantCount,  bool isFeatured,  String category,  String community,  String? creatorName,  String? creatorAvatarUrl,  String? myStatus,  String? ticketUrl,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _BikerEvent():
return $default(_that.id,_that.userId,_that.title,_that.description,_that.imageUrl,_that.location,_that.latitude,_that.longitude,_that.startsAt,_that.endsAt,_that.maxParticipants,_that.participantCount,_that.isFeatured,_that.category,_that.community,_that.creatorName,_that.creatorAvatarUrl,_that.myStatus,_that.ticketUrl,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String userId,  String title,  String? description,  String? imageUrl,  String? location,  double? latitude,  double? longitude,  DateTime startsAt,  DateTime? endsAt,  int? maxParticipants,  int participantCount,  bool isFeatured,  String category,  String community,  String? creatorName,  String? creatorAvatarUrl,  String? myStatus,  String? ticketUrl,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _BikerEvent() when $default != null:
return $default(_that.id,_that.userId,_that.title,_that.description,_that.imageUrl,_that.location,_that.latitude,_that.longitude,_that.startsAt,_that.endsAt,_that.maxParticipants,_that.participantCount,_that.isFeatured,_that.category,_that.community,_that.creatorName,_that.creatorAvatarUrl,_that.myStatus,_that.ticketUrl,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BikerEvent implements BikerEvent {
  const _BikerEvent({required this.id, required this.userId, required this.title, this.description, this.imageUrl, this.location, this.latitude, this.longitude, required this.startsAt, this.endsAt, this.maxParticipants, this.participantCount = 0, this.isFeatured = false, this.category = 'meetup', this.community = 'bikergram', this.creatorName, this.creatorAvatarUrl, this.myStatus, this.ticketUrl, this.createdAt, this.updatedAt});
  factory _BikerEvent.fromJson(Map<String, dynamic> json) => _$BikerEventFromJson(json);

@override final  int id;
@override final  String userId;
// UUID from auth.users
@override final  String title;
@override final  String? description;
@override final  String? imageUrl;
@override final  String? location;
// location_text in DB
@override final  double? latitude;
@override final  double? longitude;
@override final  DateTime startsAt;
@override final  DateTime? endsAt;
@override final  int? maxParticipants;
@override@JsonKey() final  int participantCount;
@override@JsonKey() final  bool isFeatured;
@override@JsonKey() final  String category;
// meetup, trackday, ride, fair, race
@override@JsonKey() final  String community;
@override final  String? creatorName;
@override final  String? creatorAvatarUrl;
@override final  String? myStatus;
// going, interested, null
@override final  String? ticketUrl;
// Affiliate ticket link
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of BikerEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BikerEventCopyWith<_BikerEvent> get copyWith => __$BikerEventCopyWithImpl<_BikerEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BikerEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BikerEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.location, location) || other.location == location)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.category, category) || other.category == category)&&(identical(other.community, community) || other.community == community)&&(identical(other.creatorName, creatorName) || other.creatorName == creatorName)&&(identical(other.creatorAvatarUrl, creatorAvatarUrl) || other.creatorAvatarUrl == creatorAvatarUrl)&&(identical(other.myStatus, myStatus) || other.myStatus == myStatus)&&(identical(other.ticketUrl, ticketUrl) || other.ticketUrl == ticketUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,title,description,imageUrl,location,latitude,longitude,startsAt,endsAt,maxParticipants,participantCount,isFeatured,category,community,creatorName,creatorAvatarUrl,myStatus,ticketUrl,createdAt,updatedAt]);

@override
String toString() {
  return 'BikerEvent(id: $id, userId: $userId, title: $title, description: $description, imageUrl: $imageUrl, location: $location, latitude: $latitude, longitude: $longitude, startsAt: $startsAt, endsAt: $endsAt, maxParticipants: $maxParticipants, participantCount: $participantCount, isFeatured: $isFeatured, category: $category, community: $community, creatorName: $creatorName, creatorAvatarUrl: $creatorAvatarUrl, myStatus: $myStatus, ticketUrl: $ticketUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BikerEventCopyWith<$Res> implements $BikerEventCopyWith<$Res> {
  factory _$BikerEventCopyWith(_BikerEvent value, $Res Function(_BikerEvent) _then) = __$BikerEventCopyWithImpl;
@override @useResult
$Res call({
 int id, String userId, String title, String? description, String? imageUrl, String? location, double? latitude, double? longitude, DateTime startsAt, DateTime? endsAt, int? maxParticipants, int participantCount, bool isFeatured, String category, String community, String? creatorName, String? creatorAvatarUrl, String? myStatus, String? ticketUrl, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$BikerEventCopyWithImpl<$Res>
    implements _$BikerEventCopyWith<$Res> {
  __$BikerEventCopyWithImpl(this._self, this._then);

  final _BikerEvent _self;
  final $Res Function(_BikerEvent) _then;

/// Create a copy of BikerEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? title = null,Object? description = freezed,Object? imageUrl = freezed,Object? location = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? startsAt = null,Object? endsAt = freezed,Object? maxParticipants = freezed,Object? participantCount = null,Object? isFeatured = null,Object? category = null,Object? community = null,Object? creatorName = freezed,Object? creatorAvatarUrl = freezed,Object? myStatus = freezed,Object? ticketUrl = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_BikerEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,creatorName: freezed == creatorName ? _self.creatorName : creatorName // ignore: cast_nullable_to_non_nullable
as String?,creatorAvatarUrl: freezed == creatorAvatarUrl ? _self.creatorAvatarUrl : creatorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,myStatus: freezed == myStatus ? _self.myStatus : myStatus // ignore: cast_nullable_to_non_nullable
as String?,ticketUrl: freezed == ticketUrl ? _self.ticketUrl : ticketUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
