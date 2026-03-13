// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BikerGroup {

 int get id; String get creatorId; String get name; String? get description; String? get avatarUrl; String get groupType;// ride, chat, club
 String get community; bool get isRideActive; String get rideColor; bool get isPublic; int get memberCount; int? get maxMembers;// Enriched fields (joined from profiles / group_members)
 String? get creatorName; String? get creatorAvatarUrl; bool get isMember; bool get isAdmin; int? get conversationId;// Ride navigation fields
 double? get destinationLat; double? get destinationLng; String? get destinationName; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of BikerGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BikerGroupCopyWith<BikerGroup> get copyWith => _$BikerGroupCopyWithImpl<BikerGroup>(this as BikerGroup, _$identity);

  /// Serializes this BikerGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BikerGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.creatorId, creatorId) || other.creatorId == creatorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.groupType, groupType) || other.groupType == groupType)&&(identical(other.community, community) || other.community == community)&&(identical(other.isRideActive, isRideActive) || other.isRideActive == isRideActive)&&(identical(other.rideColor, rideColor) || other.rideColor == rideColor)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.maxMembers, maxMembers) || other.maxMembers == maxMembers)&&(identical(other.creatorName, creatorName) || other.creatorName == creatorName)&&(identical(other.creatorAvatarUrl, creatorAvatarUrl) || other.creatorAvatarUrl == creatorAvatarUrl)&&(identical(other.isMember, isMember) || other.isMember == isMember)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.destinationLat, destinationLat) || other.destinationLat == destinationLat)&&(identical(other.destinationLng, destinationLng) || other.destinationLng == destinationLng)&&(identical(other.destinationName, destinationName) || other.destinationName == destinationName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,creatorId,name,description,avatarUrl,groupType,community,isRideActive,rideColor,isPublic,memberCount,maxMembers,creatorName,creatorAvatarUrl,isMember,isAdmin,conversationId,destinationLat,destinationLng,destinationName,createdAt,updatedAt]);

@override
String toString() {
  return 'BikerGroup(id: $id, creatorId: $creatorId, name: $name, description: $description, avatarUrl: $avatarUrl, groupType: $groupType, community: $community, isRideActive: $isRideActive, rideColor: $rideColor, isPublic: $isPublic, memberCount: $memberCount, maxMembers: $maxMembers, creatorName: $creatorName, creatorAvatarUrl: $creatorAvatarUrl, isMember: $isMember, isAdmin: $isAdmin, conversationId: $conversationId, destinationLat: $destinationLat, destinationLng: $destinationLng, destinationName: $destinationName, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BikerGroupCopyWith<$Res>  {
  factory $BikerGroupCopyWith(BikerGroup value, $Res Function(BikerGroup) _then) = _$BikerGroupCopyWithImpl;
@useResult
$Res call({
 int id, String creatorId, String name, String? description, String? avatarUrl, String groupType, String community, bool isRideActive, String rideColor, bool isPublic, int memberCount, int? maxMembers, String? creatorName, String? creatorAvatarUrl, bool isMember, bool isAdmin, int? conversationId, double? destinationLat, double? destinationLng, String? destinationName, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$BikerGroupCopyWithImpl<$Res>
    implements $BikerGroupCopyWith<$Res> {
  _$BikerGroupCopyWithImpl(this._self, this._then);

  final BikerGroup _self;
  final $Res Function(BikerGroup) _then;

/// Create a copy of BikerGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? creatorId = null,Object? name = null,Object? description = freezed,Object? avatarUrl = freezed,Object? groupType = null,Object? community = null,Object? isRideActive = null,Object? rideColor = null,Object? isPublic = null,Object? memberCount = null,Object? maxMembers = freezed,Object? creatorName = freezed,Object? creatorAvatarUrl = freezed,Object? isMember = null,Object? isAdmin = null,Object? conversationId = freezed,Object? destinationLat = freezed,Object? destinationLng = freezed,Object? destinationName = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,creatorId: null == creatorId ? _self.creatorId : creatorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,groupType: null == groupType ? _self.groupType : groupType // ignore: cast_nullable_to_non_nullable
as String,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,isRideActive: null == isRideActive ? _self.isRideActive : isRideActive // ignore: cast_nullable_to_non_nullable
as bool,rideColor: null == rideColor ? _self.rideColor : rideColor // ignore: cast_nullable_to_non_nullable
as String,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,maxMembers: freezed == maxMembers ? _self.maxMembers : maxMembers // ignore: cast_nullable_to_non_nullable
as int?,creatorName: freezed == creatorName ? _self.creatorName : creatorName // ignore: cast_nullable_to_non_nullable
as String?,creatorAvatarUrl: freezed == creatorAvatarUrl ? _self.creatorAvatarUrl : creatorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isMember: null == isMember ? _self.isMember : isMember // ignore: cast_nullable_to_non_nullable
as bool,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as int?,destinationLat: freezed == destinationLat ? _self.destinationLat : destinationLat // ignore: cast_nullable_to_non_nullable
as double?,destinationLng: freezed == destinationLng ? _self.destinationLng : destinationLng // ignore: cast_nullable_to_non_nullable
as double?,destinationName: freezed == destinationName ? _self.destinationName : destinationName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BikerGroup].
extension BikerGroupPatterns on BikerGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BikerGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BikerGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BikerGroup value)  $default,){
final _that = this;
switch (_that) {
case _BikerGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BikerGroup value)?  $default,){
final _that = this;
switch (_that) {
case _BikerGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String creatorId,  String name,  String? description,  String? avatarUrl,  String groupType,  String community,  bool isRideActive,  String rideColor,  bool isPublic,  int memberCount,  int? maxMembers,  String? creatorName,  String? creatorAvatarUrl,  bool isMember,  bool isAdmin,  int? conversationId,  double? destinationLat,  double? destinationLng,  String? destinationName,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BikerGroup() when $default != null:
return $default(_that.id,_that.creatorId,_that.name,_that.description,_that.avatarUrl,_that.groupType,_that.community,_that.isRideActive,_that.rideColor,_that.isPublic,_that.memberCount,_that.maxMembers,_that.creatorName,_that.creatorAvatarUrl,_that.isMember,_that.isAdmin,_that.conversationId,_that.destinationLat,_that.destinationLng,_that.destinationName,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String creatorId,  String name,  String? description,  String? avatarUrl,  String groupType,  String community,  bool isRideActive,  String rideColor,  bool isPublic,  int memberCount,  int? maxMembers,  String? creatorName,  String? creatorAvatarUrl,  bool isMember,  bool isAdmin,  int? conversationId,  double? destinationLat,  double? destinationLng,  String? destinationName,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _BikerGroup():
return $default(_that.id,_that.creatorId,_that.name,_that.description,_that.avatarUrl,_that.groupType,_that.community,_that.isRideActive,_that.rideColor,_that.isPublic,_that.memberCount,_that.maxMembers,_that.creatorName,_that.creatorAvatarUrl,_that.isMember,_that.isAdmin,_that.conversationId,_that.destinationLat,_that.destinationLng,_that.destinationName,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String creatorId,  String name,  String? description,  String? avatarUrl,  String groupType,  String community,  bool isRideActive,  String rideColor,  bool isPublic,  int memberCount,  int? maxMembers,  String? creatorName,  String? creatorAvatarUrl,  bool isMember,  bool isAdmin,  int? conversationId,  double? destinationLat,  double? destinationLng,  String? destinationName,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _BikerGroup() when $default != null:
return $default(_that.id,_that.creatorId,_that.name,_that.description,_that.avatarUrl,_that.groupType,_that.community,_that.isRideActive,_that.rideColor,_that.isPublic,_that.memberCount,_that.maxMembers,_that.creatorName,_that.creatorAvatarUrl,_that.isMember,_that.isAdmin,_that.conversationId,_that.destinationLat,_that.destinationLng,_that.destinationName,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BikerGroup implements BikerGroup {
  const _BikerGroup({required this.id, required this.creatorId, required this.name, this.description, this.avatarUrl, this.groupType = 'chat', this.community = 'bikergram', this.isRideActive = false, this.rideColor = '#4CAF50', this.isPublic = true, this.memberCount = 1, this.maxMembers, this.creatorName, this.creatorAvatarUrl, this.isMember = false, this.isAdmin = false, this.conversationId, this.destinationLat, this.destinationLng, this.destinationName, this.createdAt, this.updatedAt});
  factory _BikerGroup.fromJson(Map<String, dynamic> json) => _$BikerGroupFromJson(json);

@override final  int id;
@override final  String creatorId;
@override final  String name;
@override final  String? description;
@override final  String? avatarUrl;
@override@JsonKey() final  String groupType;
// ride, chat, club
@override@JsonKey() final  String community;
@override@JsonKey() final  bool isRideActive;
@override@JsonKey() final  String rideColor;
@override@JsonKey() final  bool isPublic;
@override@JsonKey() final  int memberCount;
@override final  int? maxMembers;
// Enriched fields (joined from profiles / group_members)
@override final  String? creatorName;
@override final  String? creatorAvatarUrl;
@override@JsonKey() final  bool isMember;
@override@JsonKey() final  bool isAdmin;
@override final  int? conversationId;
// Ride navigation fields
@override final  double? destinationLat;
@override final  double? destinationLng;
@override final  String? destinationName;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of BikerGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BikerGroupCopyWith<_BikerGroup> get copyWith => __$BikerGroupCopyWithImpl<_BikerGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BikerGroupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BikerGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.creatorId, creatorId) || other.creatorId == creatorId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.groupType, groupType) || other.groupType == groupType)&&(identical(other.community, community) || other.community == community)&&(identical(other.isRideActive, isRideActive) || other.isRideActive == isRideActive)&&(identical(other.rideColor, rideColor) || other.rideColor == rideColor)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.maxMembers, maxMembers) || other.maxMembers == maxMembers)&&(identical(other.creatorName, creatorName) || other.creatorName == creatorName)&&(identical(other.creatorAvatarUrl, creatorAvatarUrl) || other.creatorAvatarUrl == creatorAvatarUrl)&&(identical(other.isMember, isMember) || other.isMember == isMember)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.destinationLat, destinationLat) || other.destinationLat == destinationLat)&&(identical(other.destinationLng, destinationLng) || other.destinationLng == destinationLng)&&(identical(other.destinationName, destinationName) || other.destinationName == destinationName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,creatorId,name,description,avatarUrl,groupType,community,isRideActive,rideColor,isPublic,memberCount,maxMembers,creatorName,creatorAvatarUrl,isMember,isAdmin,conversationId,destinationLat,destinationLng,destinationName,createdAt,updatedAt]);

@override
String toString() {
  return 'BikerGroup(id: $id, creatorId: $creatorId, name: $name, description: $description, avatarUrl: $avatarUrl, groupType: $groupType, community: $community, isRideActive: $isRideActive, rideColor: $rideColor, isPublic: $isPublic, memberCount: $memberCount, maxMembers: $maxMembers, creatorName: $creatorName, creatorAvatarUrl: $creatorAvatarUrl, isMember: $isMember, isAdmin: $isAdmin, conversationId: $conversationId, destinationLat: $destinationLat, destinationLng: $destinationLng, destinationName: $destinationName, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BikerGroupCopyWith<$Res> implements $BikerGroupCopyWith<$Res> {
  factory _$BikerGroupCopyWith(_BikerGroup value, $Res Function(_BikerGroup) _then) = __$BikerGroupCopyWithImpl;
@override @useResult
$Res call({
 int id, String creatorId, String name, String? description, String? avatarUrl, String groupType, String community, bool isRideActive, String rideColor, bool isPublic, int memberCount, int? maxMembers, String? creatorName, String? creatorAvatarUrl, bool isMember, bool isAdmin, int? conversationId, double? destinationLat, double? destinationLng, String? destinationName, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$BikerGroupCopyWithImpl<$Res>
    implements _$BikerGroupCopyWith<$Res> {
  __$BikerGroupCopyWithImpl(this._self, this._then);

  final _BikerGroup _self;
  final $Res Function(_BikerGroup) _then;

/// Create a copy of BikerGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? creatorId = null,Object? name = null,Object? description = freezed,Object? avatarUrl = freezed,Object? groupType = null,Object? community = null,Object? isRideActive = null,Object? rideColor = null,Object? isPublic = null,Object? memberCount = null,Object? maxMembers = freezed,Object? creatorName = freezed,Object? creatorAvatarUrl = freezed,Object? isMember = null,Object? isAdmin = null,Object? conversationId = freezed,Object? destinationLat = freezed,Object? destinationLng = freezed,Object? destinationName = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_BikerGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,creatorId: null == creatorId ? _self.creatorId : creatorId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,groupType: null == groupType ? _self.groupType : groupType // ignore: cast_nullable_to_non_nullable
as String,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,isRideActive: null == isRideActive ? _self.isRideActive : isRideActive // ignore: cast_nullable_to_non_nullable
as bool,rideColor: null == rideColor ? _self.rideColor : rideColor // ignore: cast_nullable_to_non_nullable
as String,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,maxMembers: freezed == maxMembers ? _self.maxMembers : maxMembers // ignore: cast_nullable_to_non_nullable
as int?,creatorName: freezed == creatorName ? _self.creatorName : creatorName // ignore: cast_nullable_to_non_nullable
as String?,creatorAvatarUrl: freezed == creatorAvatarUrl ? _self.creatorAvatarUrl : creatorAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,isMember: null == isMember ? _self.isMember : isMember // ignore: cast_nullable_to_non_nullable
as bool,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as int?,destinationLat: freezed == destinationLat ? _self.destinationLat : destinationLat // ignore: cast_nullable_to_non_nullable
as double?,destinationLng: freezed == destinationLng ? _self.destinationLng : destinationLng // ignore: cast_nullable_to_non_nullable
as double?,destinationName: freezed == destinationName ? _self.destinationName : destinationName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
