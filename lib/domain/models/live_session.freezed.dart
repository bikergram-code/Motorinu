// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveSession {

 int get id; int get userId; int? get rideId; double? get latitude; double? get longitude; double? get speed; double? get heading; bool get isActive; String? get username; String? get avatarUrl; String? get bikeName; DateTime? get startedAt; DateTime? get endedAt;
/// Create a copy of LiveSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSessionCopyWith<LiveSession> get copyWith => _$LiveSessionCopyWithImpl<LiveSession>(this as LiveSession, _$identity);

  /// Serializes this LiveSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bikeName, bikeName) || other.bikeName == bikeName)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,rideId,latitude,longitude,speed,heading,isActive,username,avatarUrl,bikeName,startedAt,endedAt);

@override
String toString() {
  return 'LiveSession(id: $id, userId: $userId, rideId: $rideId, latitude: $latitude, longitude: $longitude, speed: $speed, heading: $heading, isActive: $isActive, username: $username, avatarUrl: $avatarUrl, bikeName: $bikeName, startedAt: $startedAt, endedAt: $endedAt)';
}


}

/// @nodoc
abstract mixin class $LiveSessionCopyWith<$Res>  {
  factory $LiveSessionCopyWith(LiveSession value, $Res Function(LiveSession) _then) = _$LiveSessionCopyWithImpl;
@useResult
$Res call({
 int id, int userId, int? rideId, double? latitude, double? longitude, double? speed, double? heading, bool isActive, String? username, String? avatarUrl, String? bikeName, DateTime? startedAt, DateTime? endedAt
});




}
/// @nodoc
class _$LiveSessionCopyWithImpl<$Res>
    implements $LiveSessionCopyWith<$Res> {
  _$LiveSessionCopyWithImpl(this._self, this._then);

  final LiveSession _self;
  final $Res Function(LiveSession) _then;

/// Create a copy of LiveSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? rideId = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? speed = freezed,Object? heading = freezed,Object? isActive = null,Object? username = freezed,Object? avatarUrl = freezed,Object? bikeName = freezed,Object? startedAt = freezed,Object? endedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as int?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bikeName: freezed == bikeName ? _self.bikeName : bikeName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveSession].
extension LiveSessionPatterns on LiveSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSession value)  $default,){
final _that = this;
switch (_that) {
case _LiveSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSession value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  int? rideId,  double? latitude,  double? longitude,  double? speed,  double? heading,  bool isActive,  String? username,  String? avatarUrl,  String? bikeName,  DateTime? startedAt,  DateTime? endedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSession() when $default != null:
return $default(_that.id,_that.userId,_that.rideId,_that.latitude,_that.longitude,_that.speed,_that.heading,_that.isActive,_that.username,_that.avatarUrl,_that.bikeName,_that.startedAt,_that.endedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  int? rideId,  double? latitude,  double? longitude,  double? speed,  double? heading,  bool isActive,  String? username,  String? avatarUrl,  String? bikeName,  DateTime? startedAt,  DateTime? endedAt)  $default,) {final _that = this;
switch (_that) {
case _LiveSession():
return $default(_that.id,_that.userId,_that.rideId,_that.latitude,_that.longitude,_that.speed,_that.heading,_that.isActive,_that.username,_that.avatarUrl,_that.bikeName,_that.startedAt,_that.endedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  int? rideId,  double? latitude,  double? longitude,  double? speed,  double? heading,  bool isActive,  String? username,  String? avatarUrl,  String? bikeName,  DateTime? startedAt,  DateTime? endedAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveSession() when $default != null:
return $default(_that.id,_that.userId,_that.rideId,_that.latitude,_that.longitude,_that.speed,_that.heading,_that.isActive,_that.username,_that.avatarUrl,_that.bikeName,_that.startedAt,_that.endedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSession implements LiveSession {
  const _LiveSession({required this.id, required this.userId, this.rideId, this.latitude, this.longitude, this.speed, this.heading, this.isActive = true, this.username, this.avatarUrl, this.bikeName, this.startedAt, this.endedAt});
  factory _LiveSession.fromJson(Map<String, dynamic> json) => _$LiveSessionFromJson(json);

@override final  int id;
@override final  int userId;
@override final  int? rideId;
@override final  double? latitude;
@override final  double? longitude;
@override final  double? speed;
@override final  double? heading;
@override@JsonKey() final  bool isActive;
@override final  String? username;
@override final  String? avatarUrl;
@override final  String? bikeName;
@override final  DateTime? startedAt;
@override final  DateTime? endedAt;

/// Create a copy of LiveSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSessionCopyWith<_LiveSession> get copyWith => __$LiveSessionCopyWithImpl<_LiveSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bikeName, bikeName) || other.bikeName == bikeName)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,rideId,latitude,longitude,speed,heading,isActive,username,avatarUrl,bikeName,startedAt,endedAt);

@override
String toString() {
  return 'LiveSession(id: $id, userId: $userId, rideId: $rideId, latitude: $latitude, longitude: $longitude, speed: $speed, heading: $heading, isActive: $isActive, username: $username, avatarUrl: $avatarUrl, bikeName: $bikeName, startedAt: $startedAt, endedAt: $endedAt)';
}


}

/// @nodoc
abstract mixin class _$LiveSessionCopyWith<$Res> implements $LiveSessionCopyWith<$Res> {
  factory _$LiveSessionCopyWith(_LiveSession value, $Res Function(_LiveSession) _then) = __$LiveSessionCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, int? rideId, double? latitude, double? longitude, double? speed, double? heading, bool isActive, String? username, String? avatarUrl, String? bikeName, DateTime? startedAt, DateTime? endedAt
});




}
/// @nodoc
class __$LiveSessionCopyWithImpl<$Res>
    implements _$LiveSessionCopyWith<$Res> {
  __$LiveSessionCopyWithImpl(this._self, this._then);

  final _LiveSession _self;
  final $Res Function(_LiveSession) _then;

/// Create a copy of LiveSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? rideId = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? speed = freezed,Object? heading = freezed,Object? isActive = null,Object? username = freezed,Object? avatarUrl = freezed,Object? bikeName = freezed,Object? startedAt = freezed,Object? endedAt = freezed,}) {
  return _then(_LiveSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,rideId: freezed == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as int?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bikeName: freezed == bikeName ? _self.bikeName : bikeName // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
