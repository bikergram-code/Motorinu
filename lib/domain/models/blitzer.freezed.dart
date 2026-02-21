// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blitzer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BlitzerReport {

 int get id; int get userId; String get type; double get latitude; double get longitude; int? get speedLimit; String? get description; bool get isActive; int get confirmations; String? get reporterName; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of BlitzerReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlitzerReportCopyWith<BlitzerReport> get copyWith => _$BlitzerReportCopyWithImpl<BlitzerReport>(this as BlitzerReport, _$identity);

  /// Serializes this BlitzerReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlitzerReport&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.type, type) || other.type == type)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speedLimit, speedLimit) || other.speedLimit == speedLimit)&&(identical(other.description, description) || other.description == description)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.confirmations, confirmations) || other.confirmations == confirmations)&&(identical(other.reporterName, reporterName) || other.reporterName == reporterName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,type,latitude,longitude,speedLimit,description,isActive,confirmations,reporterName,createdAt,updatedAt);

@override
String toString() {
  return 'BlitzerReport(id: $id, userId: $userId, type: $type, latitude: $latitude, longitude: $longitude, speedLimit: $speedLimit, description: $description, isActive: $isActive, confirmations: $confirmations, reporterName: $reporterName, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BlitzerReportCopyWith<$Res>  {
  factory $BlitzerReportCopyWith(BlitzerReport value, $Res Function(BlitzerReport) _then) = _$BlitzerReportCopyWithImpl;
@useResult
$Res call({
 int id, int userId, String type, double latitude, double longitude, int? speedLimit, String? description, bool isActive, int confirmations, String? reporterName, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$BlitzerReportCopyWithImpl<$Res>
    implements $BlitzerReportCopyWith<$Res> {
  _$BlitzerReportCopyWithImpl(this._self, this._then);

  final BlitzerReport _self;
  final $Res Function(BlitzerReport) _then;

/// Create a copy of BlitzerReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? type = null,Object? latitude = null,Object? longitude = null,Object? speedLimit = freezed,Object? description = freezed,Object? isActive = null,Object? confirmations = null,Object? reporterName = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,speedLimit: freezed == speedLimit ? _self.speedLimit : speedLimit // ignore: cast_nullable_to_non_nullable
as int?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,confirmations: null == confirmations ? _self.confirmations : confirmations // ignore: cast_nullable_to_non_nullable
as int,reporterName: freezed == reporterName ? _self.reporterName : reporterName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BlitzerReport].
extension BlitzerReportPatterns on BlitzerReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlitzerReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlitzerReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlitzerReport value)  $default,){
final _that = this;
switch (_that) {
case _BlitzerReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlitzerReport value)?  $default,){
final _that = this;
switch (_that) {
case _BlitzerReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  String type,  double latitude,  double longitude,  int? speedLimit,  String? description,  bool isActive,  int confirmations,  String? reporterName,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlitzerReport() when $default != null:
return $default(_that.id,_that.userId,_that.type,_that.latitude,_that.longitude,_that.speedLimit,_that.description,_that.isActive,_that.confirmations,_that.reporterName,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  String type,  double latitude,  double longitude,  int? speedLimit,  String? description,  bool isActive,  int confirmations,  String? reporterName,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _BlitzerReport():
return $default(_that.id,_that.userId,_that.type,_that.latitude,_that.longitude,_that.speedLimit,_that.description,_that.isActive,_that.confirmations,_that.reporterName,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  String type,  double latitude,  double longitude,  int? speedLimit,  String? description,  bool isActive,  int confirmations,  String? reporterName,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _BlitzerReport() when $default != null:
return $default(_that.id,_that.userId,_that.type,_that.latitude,_that.longitude,_that.speedLimit,_that.description,_that.isActive,_that.confirmations,_that.reporterName,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BlitzerReport implements BlitzerReport {
  const _BlitzerReport({required this.id, required this.userId, required this.type, required this.latitude, required this.longitude, this.speedLimit, this.description, this.isActive = true, this.confirmations = 0, this.reporterName, this.createdAt, this.updatedAt});
  factory _BlitzerReport.fromJson(Map<String, dynamic> json) => _$BlitzerReportFromJson(json);

@override final  int id;
@override final  int userId;
@override final  String type;
@override final  double latitude;
@override final  double longitude;
@override final  int? speedLimit;
@override final  String? description;
@override@JsonKey() final  bool isActive;
@override@JsonKey() final  int confirmations;
@override final  String? reporterName;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of BlitzerReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlitzerReportCopyWith<_BlitzerReport> get copyWith => __$BlitzerReportCopyWithImpl<_BlitzerReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BlitzerReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlitzerReport&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.type, type) || other.type == type)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.speedLimit, speedLimit) || other.speedLimit == speedLimit)&&(identical(other.description, description) || other.description == description)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.confirmations, confirmations) || other.confirmations == confirmations)&&(identical(other.reporterName, reporterName) || other.reporterName == reporterName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,type,latitude,longitude,speedLimit,description,isActive,confirmations,reporterName,createdAt,updatedAt);

@override
String toString() {
  return 'BlitzerReport(id: $id, userId: $userId, type: $type, latitude: $latitude, longitude: $longitude, speedLimit: $speedLimit, description: $description, isActive: $isActive, confirmations: $confirmations, reporterName: $reporterName, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BlitzerReportCopyWith<$Res> implements $BlitzerReportCopyWith<$Res> {
  factory _$BlitzerReportCopyWith(_BlitzerReport value, $Res Function(_BlitzerReport) _then) = __$BlitzerReportCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, String type, double latitude, double longitude, int? speedLimit, String? description, bool isActive, int confirmations, String? reporterName, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$BlitzerReportCopyWithImpl<$Res>
    implements _$BlitzerReportCopyWith<$Res> {
  __$BlitzerReportCopyWithImpl(this._self, this._then);

  final _BlitzerReport _self;
  final $Res Function(_BlitzerReport) _then;

/// Create a copy of BlitzerReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? type = null,Object? latitude = null,Object? longitude = null,Object? speedLimit = freezed,Object? description = freezed,Object? isActive = null,Object? confirmations = null,Object? reporterName = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_BlitzerReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,speedLimit: freezed == speedLimit ? _self.speedLimit : speedLimit // ignore: cast_nullable_to_non_nullable
as int?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,confirmations: null == confirmations ? _self.confirmations : confirmations // ignore: cast_nullable_to_non_nullable
as int,reporterName: freezed == reporterName ? _self.reporterName : reporterName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
