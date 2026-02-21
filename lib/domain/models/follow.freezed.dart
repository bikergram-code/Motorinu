// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'follow.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FollowRelation {

 int get id; int get followerId; int get followingId; DateTime? get createdAt;
/// Create a copy of FollowRelation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowRelationCopyWith<FollowRelation> get copyWith => _$FollowRelationCopyWithImpl<FollowRelation>(this as FollowRelation, _$identity);

  /// Serializes this FollowRelation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowRelation&&(identical(other.id, id) || other.id == id)&&(identical(other.followerId, followerId) || other.followerId == followerId)&&(identical(other.followingId, followingId) || other.followingId == followingId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,followerId,followingId,createdAt);

@override
String toString() {
  return 'FollowRelation(id: $id, followerId: $followerId, followingId: $followingId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FollowRelationCopyWith<$Res>  {
  factory $FollowRelationCopyWith(FollowRelation value, $Res Function(FollowRelation) _then) = _$FollowRelationCopyWithImpl;
@useResult
$Res call({
 int id, int followerId, int followingId, DateTime? createdAt
});




}
/// @nodoc
class _$FollowRelationCopyWithImpl<$Res>
    implements $FollowRelationCopyWith<$Res> {
  _$FollowRelationCopyWithImpl(this._self, this._then);

  final FollowRelation _self;
  final $Res Function(FollowRelation) _then;

/// Create a copy of FollowRelation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? followerId = null,Object? followingId = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,followerId: null == followerId ? _self.followerId : followerId // ignore: cast_nullable_to_non_nullable
as int,followingId: null == followingId ? _self.followingId : followingId // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowRelation].
extension FollowRelationPatterns on FollowRelation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowRelation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowRelation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowRelation value)  $default,){
final _that = this;
switch (_that) {
case _FollowRelation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowRelation value)?  $default,){
final _that = this;
switch (_that) {
case _FollowRelation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int followerId,  int followingId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowRelation() when $default != null:
return $default(_that.id,_that.followerId,_that.followingId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int followerId,  int followingId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _FollowRelation():
return $default(_that.id,_that.followerId,_that.followingId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int followerId,  int followingId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FollowRelation() when $default != null:
return $default(_that.id,_that.followerId,_that.followingId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FollowRelation implements FollowRelation {
  const _FollowRelation({required this.id, required this.followerId, required this.followingId, this.createdAt});
  factory _FollowRelation.fromJson(Map<String, dynamic> json) => _$FollowRelationFromJson(json);

@override final  int id;
@override final  int followerId;
@override final  int followingId;
@override final  DateTime? createdAt;

/// Create a copy of FollowRelation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowRelationCopyWith<_FollowRelation> get copyWith => __$FollowRelationCopyWithImpl<_FollowRelation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FollowRelationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowRelation&&(identical(other.id, id) || other.id == id)&&(identical(other.followerId, followerId) || other.followerId == followerId)&&(identical(other.followingId, followingId) || other.followingId == followingId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,followerId,followingId,createdAt);

@override
String toString() {
  return 'FollowRelation(id: $id, followerId: $followerId, followingId: $followingId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FollowRelationCopyWith<$Res> implements $FollowRelationCopyWith<$Res> {
  factory _$FollowRelationCopyWith(_FollowRelation value, $Res Function(_FollowRelation) _then) = __$FollowRelationCopyWithImpl;
@override @useResult
$Res call({
 int id, int followerId, int followingId, DateTime? createdAt
});




}
/// @nodoc
class __$FollowRelationCopyWithImpl<$Res>
    implements _$FollowRelationCopyWith<$Res> {
  __$FollowRelationCopyWithImpl(this._self, this._then);

  final _FollowRelation _self;
  final $Res Function(_FollowRelation) _then;

/// Create a copy of FollowRelation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? followerId = null,Object? followingId = null,Object? createdAt = freezed,}) {
  return _then(_FollowRelation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,followerId: null == followerId ? _self.followerId : followerId // ignore: cast_nullable_to_non_nullable
as int,followingId: null == followingId ? _self.followingId : followingId // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$UserSummary {

 int get id; String get username; String? get displayName; String? get avatarUrl; bool get isFollowing; bool get isFollowedByMe;
/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<UserSummary> get copyWith => _$UserSummaryCopyWithImpl<UserSummary>(this as UserSummary, _$identity);

  /// Serializes this UserSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isFollowedByMe, isFollowedByMe) || other.isFollowedByMe == isFollowedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,isFollowing,isFollowedByMe);

@override
String toString() {
  return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isFollowing: $isFollowing, isFollowedByMe: $isFollowedByMe)';
}


}

/// @nodoc
abstract mixin class $UserSummaryCopyWith<$Res>  {
  factory $UserSummaryCopyWith(UserSummary value, $Res Function(UserSummary) _then) = _$UserSummaryCopyWithImpl;
@useResult
$Res call({
 int id, String username, String? displayName, String? avatarUrl, bool isFollowing, bool isFollowedByMe
});




}
/// @nodoc
class _$UserSummaryCopyWithImpl<$Res>
    implements $UserSummaryCopyWith<$Res> {
  _$UserSummaryCopyWithImpl(this._self, this._then);

  final UserSummary _self;
  final $Res Function(UserSummary) _then;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isFollowing = null,Object? isFollowedByMe = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,isFollowedByMe: null == isFollowedByMe ? _self.isFollowedByMe : isFollowedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSummary].
extension UserSummaryPatterns on UserSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSummary value)  $default,){
final _that = this;
switch (_that) {
case _UserSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSummary value)?  $default,){
final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String username,  String? displayName,  String? avatarUrl,  bool isFollowing,  bool isFollowedByMe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isFollowing,_that.isFollowedByMe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String username,  String? displayName,  String? avatarUrl,  bool isFollowing,  bool isFollowedByMe)  $default,) {final _that = this;
switch (_that) {
case _UserSummary():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isFollowing,_that.isFollowedByMe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String username,  String? displayName,  String? avatarUrl,  bool isFollowing,  bool isFollowedByMe)?  $default,) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.isFollowing,_that.isFollowedByMe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserSummary implements UserSummary {
  const _UserSummary({required this.id, required this.username, this.displayName, this.avatarUrl, this.isFollowing = false, this.isFollowedByMe = false});
  factory _UserSummary.fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);

@override final  int id;
@override final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override@JsonKey() final  bool isFollowing;
@override@JsonKey() final  bool isFollowedByMe;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSummaryCopyWith<_UserSummary> get copyWith => __$UserSummaryCopyWithImpl<_UserSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isFollowedByMe, isFollowedByMe) || other.isFollowedByMe == isFollowedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,displayName,avatarUrl,isFollowing,isFollowedByMe);

@override
String toString() {
  return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, isFollowing: $isFollowing, isFollowedByMe: $isFollowedByMe)';
}


}

/// @nodoc
abstract mixin class _$UserSummaryCopyWith<$Res> implements $UserSummaryCopyWith<$Res> {
  factory _$UserSummaryCopyWith(_UserSummary value, $Res Function(_UserSummary) _then) = __$UserSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, String username, String? displayName, String? avatarUrl, bool isFollowing, bool isFollowedByMe
});




}
/// @nodoc
class __$UserSummaryCopyWithImpl<$Res>
    implements _$UserSummaryCopyWith<$Res> {
  __$UserSummaryCopyWithImpl(this._self, this._then);

  final _UserSummary _self;
  final $Res Function(_UserSummary) _then;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? isFollowing = null,Object? isFollowedByMe = null,}) {
  return _then(_UserSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,isFollowedByMe: null == isFollowedByMe ? _self.isFollowedByMe : isFollowedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
