// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'achievement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Achievement {

 int get id; String get slug; String get name; String? get description; String? get iconUrl; int get xpReward; Map<String, dynamic>? get criteria; bool get isUnlocked; DateTime? get unlockedAt; double get progress;
/// Create a copy of Achievement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AchievementCopyWith<Achievement> get copyWith => _$AchievementCopyWithImpl<Achievement>(this as Achievement, _$identity);

  /// Serializes this Achievement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Achievement&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.xpReward, xpReward) || other.xpReward == xpReward)&&const DeepCollectionEquality().equals(other.criteria, criteria)&&(identical(other.isUnlocked, isUnlocked) || other.isUnlocked == isUnlocked)&&(identical(other.unlockedAt, unlockedAt) || other.unlockedAt == unlockedAt)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,name,description,iconUrl,xpReward,const DeepCollectionEquality().hash(criteria),isUnlocked,unlockedAt,progress);

@override
String toString() {
  return 'Achievement(id: $id, slug: $slug, name: $name, description: $description, iconUrl: $iconUrl, xpReward: $xpReward, criteria: $criteria, isUnlocked: $isUnlocked, unlockedAt: $unlockedAt, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $AchievementCopyWith<$Res>  {
  factory $AchievementCopyWith(Achievement value, $Res Function(Achievement) _then) = _$AchievementCopyWithImpl;
@useResult
$Res call({
 int id, String slug, String name, String? description, String? iconUrl, int xpReward, Map<String, dynamic>? criteria, bool isUnlocked, DateTime? unlockedAt, double progress
});




}
/// @nodoc
class _$AchievementCopyWithImpl<$Res>
    implements $AchievementCopyWith<$Res> {
  _$AchievementCopyWithImpl(this._self, this._then);

  final Achievement _self;
  final $Res Function(Achievement) _then;

/// Create a copy of Achievement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? description = freezed,Object? iconUrl = freezed,Object? xpReward = null,Object? criteria = freezed,Object? isUnlocked = null,Object? unlockedAt = freezed,Object? progress = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,xpReward: null == xpReward ? _self.xpReward : xpReward // ignore: cast_nullable_to_non_nullable
as int,criteria: freezed == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isUnlocked: null == isUnlocked ? _self.isUnlocked : isUnlocked // ignore: cast_nullable_to_non_nullable
as bool,unlockedAt: freezed == unlockedAt ? _self.unlockedAt : unlockedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [Achievement].
extension AchievementPatterns on Achievement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Achievement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Achievement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Achievement value)  $default,){
final _that = this;
switch (_that) {
case _Achievement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Achievement value)?  $default,){
final _that = this;
switch (_that) {
case _Achievement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String slug,  String name,  String? description,  String? iconUrl,  int xpReward,  Map<String, dynamic>? criteria,  bool isUnlocked,  DateTime? unlockedAt,  double progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Achievement() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.description,_that.iconUrl,_that.xpReward,_that.criteria,_that.isUnlocked,_that.unlockedAt,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String slug,  String name,  String? description,  String? iconUrl,  int xpReward,  Map<String, dynamic>? criteria,  bool isUnlocked,  DateTime? unlockedAt,  double progress)  $default,) {final _that = this;
switch (_that) {
case _Achievement():
return $default(_that.id,_that.slug,_that.name,_that.description,_that.iconUrl,_that.xpReward,_that.criteria,_that.isUnlocked,_that.unlockedAt,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String slug,  String name,  String? description,  String? iconUrl,  int xpReward,  Map<String, dynamic>? criteria,  bool isUnlocked,  DateTime? unlockedAt,  double progress)?  $default,) {final _that = this;
switch (_that) {
case _Achievement() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.description,_that.iconUrl,_that.xpReward,_that.criteria,_that.isUnlocked,_that.unlockedAt,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Achievement implements Achievement {
  const _Achievement({required this.id, required this.slug, required this.name, this.description, this.iconUrl, this.xpReward = 0, final  Map<String, dynamic>? criteria, this.isUnlocked = false, this.unlockedAt, this.progress = 0.0}): _criteria = criteria;
  factory _Achievement.fromJson(Map<String, dynamic> json) => _$AchievementFromJson(json);

@override final  int id;
@override final  String slug;
@override final  String name;
@override final  String? description;
@override final  String? iconUrl;
@override@JsonKey() final  int xpReward;
 final  Map<String, dynamic>? _criteria;
@override Map<String, dynamic>? get criteria {
  final value = _criteria;
  if (value == null) return null;
  if (_criteria is EqualUnmodifiableMapView) return _criteria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool isUnlocked;
@override final  DateTime? unlockedAt;
@override@JsonKey() final  double progress;

/// Create a copy of Achievement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AchievementCopyWith<_Achievement> get copyWith => __$AchievementCopyWithImpl<_Achievement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AchievementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Achievement&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.xpReward, xpReward) || other.xpReward == xpReward)&&const DeepCollectionEquality().equals(other._criteria, _criteria)&&(identical(other.isUnlocked, isUnlocked) || other.isUnlocked == isUnlocked)&&(identical(other.unlockedAt, unlockedAt) || other.unlockedAt == unlockedAt)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,name,description,iconUrl,xpReward,const DeepCollectionEquality().hash(_criteria),isUnlocked,unlockedAt,progress);

@override
String toString() {
  return 'Achievement(id: $id, slug: $slug, name: $name, description: $description, iconUrl: $iconUrl, xpReward: $xpReward, criteria: $criteria, isUnlocked: $isUnlocked, unlockedAt: $unlockedAt, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$AchievementCopyWith<$Res> implements $AchievementCopyWith<$Res> {
  factory _$AchievementCopyWith(_Achievement value, $Res Function(_Achievement) _then) = __$AchievementCopyWithImpl;
@override @useResult
$Res call({
 int id, String slug, String name, String? description, String? iconUrl, int xpReward, Map<String, dynamic>? criteria, bool isUnlocked, DateTime? unlockedAt, double progress
});




}
/// @nodoc
class __$AchievementCopyWithImpl<$Res>
    implements _$AchievementCopyWith<$Res> {
  __$AchievementCopyWithImpl(this._self, this._then);

  final _Achievement _self;
  final $Res Function(_Achievement) _then;

/// Create a copy of Achievement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? description = freezed,Object? iconUrl = freezed,Object? xpReward = null,Object? criteria = freezed,Object? isUnlocked = null,Object? unlockedAt = freezed,Object? progress = null,}) {
  return _then(_Achievement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,xpReward: null == xpReward ? _self.xpReward : xpReward // ignore: cast_nullable_to_non_nullable
as int,criteria: freezed == criteria ? _self._criteria : criteria // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isUnlocked: null == isUnlocked ? _self.isUnlocked : isUnlocked // ignore: cast_nullable_to_non_nullable
as bool,unlockedAt: freezed == unlockedAt ? _self.unlockedAt : unlockedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$XpTransaction {

 int get id; int get userId; int get amount; String get source; int? get sourceId; DateTime? get createdAt;
/// Create a copy of XpTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XpTransactionCopyWith<XpTransaction> get copyWith => _$XpTransactionCopyWithImpl<XpTransaction>(this as XpTransaction, _$identity);

  /// Serializes this XpTransaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XpTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,amount,source,sourceId,createdAt);

@override
String toString() {
  return 'XpTransaction(id: $id, userId: $userId, amount: $amount, source: $source, sourceId: $sourceId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $XpTransactionCopyWith<$Res>  {
  factory $XpTransactionCopyWith(XpTransaction value, $Res Function(XpTransaction) _then) = _$XpTransactionCopyWithImpl;
@useResult
$Res call({
 int id, int userId, int amount, String source, int? sourceId, DateTime? createdAt
});




}
/// @nodoc
class _$XpTransactionCopyWithImpl<$Res>
    implements $XpTransactionCopyWith<$Res> {
  _$XpTransactionCopyWithImpl(this._self, this._then);

  final XpTransaction _self;
  final $Res Function(XpTransaction) _then;

/// Create a copy of XpTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? amount = null,Object? source = null,Object? sourceId = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [XpTransaction].
extension XpTransactionPatterns on XpTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XpTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XpTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XpTransaction value)  $default,){
final _that = this;
switch (_that) {
case _XpTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XpTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _XpTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  int amount,  String source,  int? sourceId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XpTransaction() when $default != null:
return $default(_that.id,_that.userId,_that.amount,_that.source,_that.sourceId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  int amount,  String source,  int? sourceId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _XpTransaction():
return $default(_that.id,_that.userId,_that.amount,_that.source,_that.sourceId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  int amount,  String source,  int? sourceId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _XpTransaction() when $default != null:
return $default(_that.id,_that.userId,_that.amount,_that.source,_that.sourceId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _XpTransaction implements XpTransaction {
  const _XpTransaction({required this.id, required this.userId, required this.amount, required this.source, this.sourceId, this.createdAt});
  factory _XpTransaction.fromJson(Map<String, dynamic> json) => _$XpTransactionFromJson(json);

@override final  int id;
@override final  int userId;
@override final  int amount;
@override final  String source;
@override final  int? sourceId;
@override final  DateTime? createdAt;

/// Create a copy of XpTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XpTransactionCopyWith<_XpTransaction> get copyWith => __$XpTransactionCopyWithImpl<_XpTransaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$XpTransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _XpTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,amount,source,sourceId,createdAt);

@override
String toString() {
  return 'XpTransaction(id: $id, userId: $userId, amount: $amount, source: $source, sourceId: $sourceId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$XpTransactionCopyWith<$Res> implements $XpTransactionCopyWith<$Res> {
  factory _$XpTransactionCopyWith(_XpTransaction value, $Res Function(_XpTransaction) _then) = __$XpTransactionCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, int amount, String source, int? sourceId, DateTime? createdAt
});




}
/// @nodoc
class __$XpTransactionCopyWithImpl<$Res>
    implements _$XpTransactionCopyWith<$Res> {
  __$XpTransactionCopyWithImpl(this._self, this._then);

  final _XpTransaction _self;
  final $Res Function(_XpTransaction) _then;

/// Create a copy of XpTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? amount = null,Object? source = null,Object? sourceId = freezed,Object? createdAt = freezed,}) {
  return _then(_XpTransaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$XpSummary {

 int get totalXp; int get currentLevel; int get xpForCurrentLevel; int get xpForNextLevel; double get progress; String? get levelName;
/// Create a copy of XpSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XpSummaryCopyWith<XpSummary> get copyWith => _$XpSummaryCopyWithImpl<XpSummary>(this as XpSummary, _$identity);

  /// Serializes this XpSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XpSummary&&(identical(other.totalXp, totalXp) || other.totalXp == totalXp)&&(identical(other.currentLevel, currentLevel) || other.currentLevel == currentLevel)&&(identical(other.xpForCurrentLevel, xpForCurrentLevel) || other.xpForCurrentLevel == xpForCurrentLevel)&&(identical(other.xpForNextLevel, xpForNextLevel) || other.xpForNextLevel == xpForNextLevel)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.levelName, levelName) || other.levelName == levelName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalXp,currentLevel,xpForCurrentLevel,xpForNextLevel,progress,levelName);

@override
String toString() {
  return 'XpSummary(totalXp: $totalXp, currentLevel: $currentLevel, xpForCurrentLevel: $xpForCurrentLevel, xpForNextLevel: $xpForNextLevel, progress: $progress, levelName: $levelName)';
}


}

/// @nodoc
abstract mixin class $XpSummaryCopyWith<$Res>  {
  factory $XpSummaryCopyWith(XpSummary value, $Res Function(XpSummary) _then) = _$XpSummaryCopyWithImpl;
@useResult
$Res call({
 int totalXp, int currentLevel, int xpForCurrentLevel, int xpForNextLevel, double progress, String? levelName
});




}
/// @nodoc
class _$XpSummaryCopyWithImpl<$Res>
    implements $XpSummaryCopyWith<$Res> {
  _$XpSummaryCopyWithImpl(this._self, this._then);

  final XpSummary _self;
  final $Res Function(XpSummary) _then;

/// Create a copy of XpSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalXp = null,Object? currentLevel = null,Object? xpForCurrentLevel = null,Object? xpForNextLevel = null,Object? progress = null,Object? levelName = freezed,}) {
  return _then(_self.copyWith(
totalXp: null == totalXp ? _self.totalXp : totalXp // ignore: cast_nullable_to_non_nullable
as int,currentLevel: null == currentLevel ? _self.currentLevel : currentLevel // ignore: cast_nullable_to_non_nullable
as int,xpForCurrentLevel: null == xpForCurrentLevel ? _self.xpForCurrentLevel : xpForCurrentLevel // ignore: cast_nullable_to_non_nullable
as int,xpForNextLevel: null == xpForNextLevel ? _self.xpForNextLevel : xpForNextLevel // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,levelName: freezed == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [XpSummary].
extension XpSummaryPatterns on XpSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XpSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XpSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XpSummary value)  $default,){
final _that = this;
switch (_that) {
case _XpSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XpSummary value)?  $default,){
final _that = this;
switch (_that) {
case _XpSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalXp,  int currentLevel,  int xpForCurrentLevel,  int xpForNextLevel,  double progress,  String? levelName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XpSummary() when $default != null:
return $default(_that.totalXp,_that.currentLevel,_that.xpForCurrentLevel,_that.xpForNextLevel,_that.progress,_that.levelName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalXp,  int currentLevel,  int xpForCurrentLevel,  int xpForNextLevel,  double progress,  String? levelName)  $default,) {final _that = this;
switch (_that) {
case _XpSummary():
return $default(_that.totalXp,_that.currentLevel,_that.xpForCurrentLevel,_that.xpForNextLevel,_that.progress,_that.levelName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalXp,  int currentLevel,  int xpForCurrentLevel,  int xpForNextLevel,  double progress,  String? levelName)?  $default,) {final _that = this;
switch (_that) {
case _XpSummary() when $default != null:
return $default(_that.totalXp,_that.currentLevel,_that.xpForCurrentLevel,_that.xpForNextLevel,_that.progress,_that.levelName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _XpSummary implements XpSummary {
  const _XpSummary({this.totalXp = 0, this.currentLevel = 1, this.xpForCurrentLevel = 0, this.xpForNextLevel = 100, this.progress = 0.0, this.levelName});
  factory _XpSummary.fromJson(Map<String, dynamic> json) => _$XpSummaryFromJson(json);

@override@JsonKey() final  int totalXp;
@override@JsonKey() final  int currentLevel;
@override@JsonKey() final  int xpForCurrentLevel;
@override@JsonKey() final  int xpForNextLevel;
@override@JsonKey() final  double progress;
@override final  String? levelName;

/// Create a copy of XpSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XpSummaryCopyWith<_XpSummary> get copyWith => __$XpSummaryCopyWithImpl<_XpSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$XpSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _XpSummary&&(identical(other.totalXp, totalXp) || other.totalXp == totalXp)&&(identical(other.currentLevel, currentLevel) || other.currentLevel == currentLevel)&&(identical(other.xpForCurrentLevel, xpForCurrentLevel) || other.xpForCurrentLevel == xpForCurrentLevel)&&(identical(other.xpForNextLevel, xpForNextLevel) || other.xpForNextLevel == xpForNextLevel)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.levelName, levelName) || other.levelName == levelName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalXp,currentLevel,xpForCurrentLevel,xpForNextLevel,progress,levelName);

@override
String toString() {
  return 'XpSummary(totalXp: $totalXp, currentLevel: $currentLevel, xpForCurrentLevel: $xpForCurrentLevel, xpForNextLevel: $xpForNextLevel, progress: $progress, levelName: $levelName)';
}


}

/// @nodoc
abstract mixin class _$XpSummaryCopyWith<$Res> implements $XpSummaryCopyWith<$Res> {
  factory _$XpSummaryCopyWith(_XpSummary value, $Res Function(_XpSummary) _then) = __$XpSummaryCopyWithImpl;
@override @useResult
$Res call({
 int totalXp, int currentLevel, int xpForCurrentLevel, int xpForNextLevel, double progress, String? levelName
});




}
/// @nodoc
class __$XpSummaryCopyWithImpl<$Res>
    implements _$XpSummaryCopyWith<$Res> {
  __$XpSummaryCopyWithImpl(this._self, this._then);

  final _XpSummary _self;
  final $Res Function(_XpSummary) _then;

/// Create a copy of XpSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalXp = null,Object? currentLevel = null,Object? xpForCurrentLevel = null,Object? xpForNextLevel = null,Object? progress = null,Object? levelName = freezed,}) {
  return _then(_XpSummary(
totalXp: null == totalXp ? _self.totalXp : totalXp // ignore: cast_nullable_to_non_nullable
as int,currentLevel: null == currentLevel ? _self.currentLevel : currentLevel // ignore: cast_nullable_to_non_nullable
as int,xpForCurrentLevel: null == xpForCurrentLevel ? _self.xpForCurrentLevel : xpForCurrentLevel // ignore: cast_nullable_to_non_nullable
as int,xpForNextLevel: null == xpForNextLevel ? _self.xpForNextLevel : xpForNextLevel // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,levelName: freezed == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
