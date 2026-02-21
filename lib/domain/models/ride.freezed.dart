// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Ride {

 int get id; int get userId; int? get motorcycleId; DateTime get startedAt; DateTime? get endedAt; double get distanceKm; int get durationSeconds; double get avgSpeedKmh; double get maxSpeedKmh; int get xpEarned; bool get isLiveGo; List<RidePoint> get points; DateTime? get createdAt;
/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideCopyWith<Ride> get copyWith => _$RideCopyWithImpl<Ride>(this as Ride, _$identity);

  /// Serializes this Ride to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Ride&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.motorcycleId, motorcycleId) || other.motorcycleId == motorcycleId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.avgSpeedKmh, avgSpeedKmh) || other.avgSpeedKmh == avgSpeedKmh)&&(identical(other.maxSpeedKmh, maxSpeedKmh) || other.maxSpeedKmh == maxSpeedKmh)&&(identical(other.xpEarned, xpEarned) || other.xpEarned == xpEarned)&&(identical(other.isLiveGo, isLiveGo) || other.isLiveGo == isLiveGo)&&const DeepCollectionEquality().equals(other.points, points)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,motorcycleId,startedAt,endedAt,distanceKm,durationSeconds,avgSpeedKmh,maxSpeedKmh,xpEarned,isLiveGo,const DeepCollectionEquality().hash(points),createdAt);

@override
String toString() {
  return 'Ride(id: $id, userId: $userId, motorcycleId: $motorcycleId, startedAt: $startedAt, endedAt: $endedAt, distanceKm: $distanceKm, durationSeconds: $durationSeconds, avgSpeedKmh: $avgSpeedKmh, maxSpeedKmh: $maxSpeedKmh, xpEarned: $xpEarned, isLiveGo: $isLiveGo, points: $points, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RideCopyWith<$Res>  {
  factory $RideCopyWith(Ride value, $Res Function(Ride) _then) = _$RideCopyWithImpl;
@useResult
$Res call({
 int id, int userId, int? motorcycleId, DateTime startedAt, DateTime? endedAt, double distanceKm, int durationSeconds, double avgSpeedKmh, double maxSpeedKmh, int xpEarned, bool isLiveGo, List<RidePoint> points, DateTime? createdAt
});




}
/// @nodoc
class _$RideCopyWithImpl<$Res>
    implements $RideCopyWith<$Res> {
  _$RideCopyWithImpl(this._self, this._then);

  final Ride _self;
  final $Res Function(Ride) _then;

/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? motorcycleId = freezed,Object? startedAt = null,Object? endedAt = freezed,Object? distanceKm = null,Object? durationSeconds = null,Object? avgSpeedKmh = null,Object? maxSpeedKmh = null,Object? xpEarned = null,Object? isLiveGo = null,Object? points = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,motorcycleId: freezed == motorcycleId ? _self.motorcycleId : motorcycleId // ignore: cast_nullable_to_non_nullable
as int?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,avgSpeedKmh: null == avgSpeedKmh ? _self.avgSpeedKmh : avgSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,maxSpeedKmh: null == maxSpeedKmh ? _self.maxSpeedKmh : maxSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,xpEarned: null == xpEarned ? _self.xpEarned : xpEarned // ignore: cast_nullable_to_non_nullable
as int,isLiveGo: null == isLiveGo ? _self.isLiveGo : isLiveGo // ignore: cast_nullable_to_non_nullable
as bool,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<RidePoint>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Ride].
extension RidePatterns on Ride {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Ride value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Ride() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Ride value)  $default,){
final _that = this;
switch (_that) {
case _Ride():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Ride value)?  $default,){
final _that = this;
switch (_that) {
case _Ride() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  int? motorcycleId,  DateTime startedAt,  DateTime? endedAt,  double distanceKm,  int durationSeconds,  double avgSpeedKmh,  double maxSpeedKmh,  int xpEarned,  bool isLiveGo,  List<RidePoint> points,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Ride() when $default != null:
return $default(_that.id,_that.userId,_that.motorcycleId,_that.startedAt,_that.endedAt,_that.distanceKm,_that.durationSeconds,_that.avgSpeedKmh,_that.maxSpeedKmh,_that.xpEarned,_that.isLiveGo,_that.points,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  int? motorcycleId,  DateTime startedAt,  DateTime? endedAt,  double distanceKm,  int durationSeconds,  double avgSpeedKmh,  double maxSpeedKmh,  int xpEarned,  bool isLiveGo,  List<RidePoint> points,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Ride():
return $default(_that.id,_that.userId,_that.motorcycleId,_that.startedAt,_that.endedAt,_that.distanceKm,_that.durationSeconds,_that.avgSpeedKmh,_that.maxSpeedKmh,_that.xpEarned,_that.isLiveGo,_that.points,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  int? motorcycleId,  DateTime startedAt,  DateTime? endedAt,  double distanceKm,  int durationSeconds,  double avgSpeedKmh,  double maxSpeedKmh,  int xpEarned,  bool isLiveGo,  List<RidePoint> points,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Ride() when $default != null:
return $default(_that.id,_that.userId,_that.motorcycleId,_that.startedAt,_that.endedAt,_that.distanceKm,_that.durationSeconds,_that.avgSpeedKmh,_that.maxSpeedKmh,_that.xpEarned,_that.isLiveGo,_that.points,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Ride implements Ride {
  const _Ride({required this.id, required this.userId, this.motorcycleId, required this.startedAt, this.endedAt, this.distanceKm = 0.0, this.durationSeconds = 0, this.avgSpeedKmh = 0.0, this.maxSpeedKmh = 0.0, this.xpEarned = 0, this.isLiveGo = false, final  List<RidePoint> points = const [], this.createdAt}): _points = points;
  factory _Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);

@override final  int id;
@override final  int userId;
@override final  int? motorcycleId;
@override final  DateTime startedAt;
@override final  DateTime? endedAt;
@override@JsonKey() final  double distanceKm;
@override@JsonKey() final  int durationSeconds;
@override@JsonKey() final  double avgSpeedKmh;
@override@JsonKey() final  double maxSpeedKmh;
@override@JsonKey() final  int xpEarned;
@override@JsonKey() final  bool isLiveGo;
 final  List<RidePoint> _points;
@override@JsonKey() List<RidePoint> get points {
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_points);
}

@override final  DateTime? createdAt;

/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideCopyWith<_Ride> get copyWith => __$RideCopyWithImpl<_Ride>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ride&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.motorcycleId, motorcycleId) || other.motorcycleId == motorcycleId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.avgSpeedKmh, avgSpeedKmh) || other.avgSpeedKmh == avgSpeedKmh)&&(identical(other.maxSpeedKmh, maxSpeedKmh) || other.maxSpeedKmh == maxSpeedKmh)&&(identical(other.xpEarned, xpEarned) || other.xpEarned == xpEarned)&&(identical(other.isLiveGo, isLiveGo) || other.isLiveGo == isLiveGo)&&const DeepCollectionEquality().equals(other._points, _points)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,motorcycleId,startedAt,endedAt,distanceKm,durationSeconds,avgSpeedKmh,maxSpeedKmh,xpEarned,isLiveGo,const DeepCollectionEquality().hash(_points),createdAt);

@override
String toString() {
  return 'Ride(id: $id, userId: $userId, motorcycleId: $motorcycleId, startedAt: $startedAt, endedAt: $endedAt, distanceKm: $distanceKm, durationSeconds: $durationSeconds, avgSpeedKmh: $avgSpeedKmh, maxSpeedKmh: $maxSpeedKmh, xpEarned: $xpEarned, isLiveGo: $isLiveGo, points: $points, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RideCopyWith<$Res> implements $RideCopyWith<$Res> {
  factory _$RideCopyWith(_Ride value, $Res Function(_Ride) _then) = __$RideCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, int? motorcycleId, DateTime startedAt, DateTime? endedAt, double distanceKm, int durationSeconds, double avgSpeedKmh, double maxSpeedKmh, int xpEarned, bool isLiveGo, List<RidePoint> points, DateTime? createdAt
});




}
/// @nodoc
class __$RideCopyWithImpl<$Res>
    implements _$RideCopyWith<$Res> {
  __$RideCopyWithImpl(this._self, this._then);

  final _Ride _self;
  final $Res Function(_Ride) _then;

/// Create a copy of Ride
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? motorcycleId = freezed,Object? startedAt = null,Object? endedAt = freezed,Object? distanceKm = null,Object? durationSeconds = null,Object? avgSpeedKmh = null,Object? maxSpeedKmh = null,Object? xpEarned = null,Object? isLiveGo = null,Object? points = null,Object? createdAt = freezed,}) {
  return _then(_Ride(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,motorcycleId: freezed == motorcycleId ? _self.motorcycleId : motorcycleId // ignore: cast_nullable_to_non_nullable
as int?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,avgSpeedKmh: null == avgSpeedKmh ? _self.avgSpeedKmh : avgSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,maxSpeedKmh: null == maxSpeedKmh ? _self.maxSpeedKmh : maxSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,xpEarned: null == xpEarned ? _self.xpEarned : xpEarned // ignore: cast_nullable_to_non_nullable
as int,isLiveGo: null == isLiveGo ? _self.isLiveGo : isLiveGo // ignore: cast_nullable_to_non_nullable
as bool,points: null == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<RidePoint>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$RidePoint {

 int get id; int get rideId; double get latitude; double get longitude; double? get altitude; double? get speed; DateTime get timestamp;
/// Create a copy of RidePoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RidePointCopyWith<RidePoint> get copyWith => _$RidePointCopyWithImpl<RidePoint>(this as RidePoint, _$identity);

  /// Serializes this RidePoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RidePoint&&(identical(other.id, id) || other.id == id)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.altitude, altitude) || other.altitude == altitude)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,rideId,latitude,longitude,altitude,speed,timestamp);

@override
String toString() {
  return 'RidePoint(id: $id, rideId: $rideId, latitude: $latitude, longitude: $longitude, altitude: $altitude, speed: $speed, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $RidePointCopyWith<$Res>  {
  factory $RidePointCopyWith(RidePoint value, $Res Function(RidePoint) _then) = _$RidePointCopyWithImpl;
@useResult
$Res call({
 int id, int rideId, double latitude, double longitude, double? altitude, double? speed, DateTime timestamp
});




}
/// @nodoc
class _$RidePointCopyWithImpl<$Res>
    implements $RidePointCopyWith<$Res> {
  _$RidePointCopyWithImpl(this._self, this._then);

  final RidePoint _self;
  final $Res Function(RidePoint) _then;

/// Create a copy of RidePoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? rideId = null,Object? latitude = null,Object? longitude = null,Object? altitude = freezed,Object? speed = freezed,Object? timestamp = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,rideId: null == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as int,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,altitude: freezed == altitude ? _self.altitude : altitude // ignore: cast_nullable_to_non_nullable
as double?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RidePoint].
extension RidePointPatterns on RidePoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RidePoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RidePoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RidePoint value)  $default,){
final _that = this;
switch (_that) {
case _RidePoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RidePoint value)?  $default,){
final _that = this;
switch (_that) {
case _RidePoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int rideId,  double latitude,  double longitude,  double? altitude,  double? speed,  DateTime timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RidePoint() when $default != null:
return $default(_that.id,_that.rideId,_that.latitude,_that.longitude,_that.altitude,_that.speed,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int rideId,  double latitude,  double longitude,  double? altitude,  double? speed,  DateTime timestamp)  $default,) {final _that = this;
switch (_that) {
case _RidePoint():
return $default(_that.id,_that.rideId,_that.latitude,_that.longitude,_that.altitude,_that.speed,_that.timestamp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int rideId,  double latitude,  double longitude,  double? altitude,  double? speed,  DateTime timestamp)?  $default,) {final _that = this;
switch (_that) {
case _RidePoint() when $default != null:
return $default(_that.id,_that.rideId,_that.latitude,_that.longitude,_that.altitude,_that.speed,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RidePoint implements RidePoint {
  const _RidePoint({required this.id, required this.rideId, required this.latitude, required this.longitude, this.altitude, this.speed, required this.timestamp});
  factory _RidePoint.fromJson(Map<String, dynamic> json) => _$RidePointFromJson(json);

@override final  int id;
@override final  int rideId;
@override final  double latitude;
@override final  double longitude;
@override final  double? altitude;
@override final  double? speed;
@override final  DateTime timestamp;

/// Create a copy of RidePoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RidePointCopyWith<_RidePoint> get copyWith => __$RidePointCopyWithImpl<_RidePoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RidePointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RidePoint&&(identical(other.id, id) || other.id == id)&&(identical(other.rideId, rideId) || other.rideId == rideId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.altitude, altitude) || other.altitude == altitude)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,rideId,latitude,longitude,altitude,speed,timestamp);

@override
String toString() {
  return 'RidePoint(id: $id, rideId: $rideId, latitude: $latitude, longitude: $longitude, altitude: $altitude, speed: $speed, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$RidePointCopyWith<$Res> implements $RidePointCopyWith<$Res> {
  factory _$RidePointCopyWith(_RidePoint value, $Res Function(_RidePoint) _then) = __$RidePointCopyWithImpl;
@override @useResult
$Res call({
 int id, int rideId, double latitude, double longitude, double? altitude, double? speed, DateTime timestamp
});




}
/// @nodoc
class __$RidePointCopyWithImpl<$Res>
    implements _$RidePointCopyWith<$Res> {
  __$RidePointCopyWithImpl(this._self, this._then);

  final _RidePoint _self;
  final $Res Function(_RidePoint) _then;

/// Create a copy of RidePoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? rideId = null,Object? latitude = null,Object? longitude = null,Object? altitude = freezed,Object? speed = freezed,Object? timestamp = null,}) {
  return _then(_RidePoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,rideId: null == rideId ? _self.rideId : rideId // ignore: cast_nullable_to_non_nullable
as int,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,altitude: freezed == altitude ? _self.altitude : altitude // ignore: cast_nullable_to_non_nullable
as double?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
