// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'motorcycle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Motorcycle {

 int get id; int get userId; String get make; String get model; int get year; String? get imageUrl; String? get category; bool get isPrimary; Map<String, String> get specifications; List<Modification> get modifications; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of Motorcycle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MotorcycleCopyWith<Motorcycle> get copyWith => _$MotorcycleCopyWithImpl<Motorcycle>(this as Motorcycle, _$identity);

  /// Serializes this Motorcycle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Motorcycle&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model)&&(identical(other.year, year) || other.year == year)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&const DeepCollectionEquality().equals(other.specifications, specifications)&&const DeepCollectionEquality().equals(other.modifications, modifications)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,make,model,year,imageUrl,category,isPrimary,const DeepCollectionEquality().hash(specifications),const DeepCollectionEquality().hash(modifications),createdAt,updatedAt);

@override
String toString() {
  return 'Motorcycle(id: $id, userId: $userId, make: $make, model: $model, year: $year, imageUrl: $imageUrl, category: $category, isPrimary: $isPrimary, specifications: $specifications, modifications: $modifications, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MotorcycleCopyWith<$Res>  {
  factory $MotorcycleCopyWith(Motorcycle value, $Res Function(Motorcycle) _then) = _$MotorcycleCopyWithImpl;
@useResult
$Res call({
 int id, int userId, String make, String model, int year, String? imageUrl, String? category, bool isPrimary, Map<String, String> specifications, List<Modification> modifications, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$MotorcycleCopyWithImpl<$Res>
    implements $MotorcycleCopyWith<$Res> {
  _$MotorcycleCopyWithImpl(this._self, this._then);

  final Motorcycle _self;
  final $Res Function(Motorcycle) _then;

/// Create a copy of Motorcycle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? make = null,Object? model = null,Object? year = null,Object? imageUrl = freezed,Object? category = freezed,Object? isPrimary = null,Object? specifications = null,Object? modifications = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,make: null == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,specifications: null == specifications ? _self.specifications : specifications // ignore: cast_nullable_to_non_nullable
as Map<String, String>,modifications: null == modifications ? _self.modifications : modifications // ignore: cast_nullable_to_non_nullable
as List<Modification>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Motorcycle].
extension MotorcyclePatterns on Motorcycle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Motorcycle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Motorcycle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Motorcycle value)  $default,){
final _that = this;
switch (_that) {
case _Motorcycle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Motorcycle value)?  $default,){
final _that = this;
switch (_that) {
case _Motorcycle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int userId,  String make,  String model,  int year,  String? imageUrl,  String? category,  bool isPrimary,  Map<String, String> specifications,  List<Modification> modifications,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Motorcycle() when $default != null:
return $default(_that.id,_that.userId,_that.make,_that.model,_that.year,_that.imageUrl,_that.category,_that.isPrimary,_that.specifications,_that.modifications,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int userId,  String make,  String model,  int year,  String? imageUrl,  String? category,  bool isPrimary,  Map<String, String> specifications,  List<Modification> modifications,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Motorcycle():
return $default(_that.id,_that.userId,_that.make,_that.model,_that.year,_that.imageUrl,_that.category,_that.isPrimary,_that.specifications,_that.modifications,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int userId,  String make,  String model,  int year,  String? imageUrl,  String? category,  bool isPrimary,  Map<String, String> specifications,  List<Modification> modifications,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Motorcycle() when $default != null:
return $default(_that.id,_that.userId,_that.make,_that.model,_that.year,_that.imageUrl,_that.category,_that.isPrimary,_that.specifications,_that.modifications,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Motorcycle implements Motorcycle {
  const _Motorcycle({required this.id, required this.userId, required this.make, required this.model, required this.year, this.imageUrl, this.category, this.isPrimary = false, final  Map<String, String> specifications = const {}, final  List<Modification> modifications = const [], this.createdAt, this.updatedAt}): _specifications = specifications,_modifications = modifications;
  factory _Motorcycle.fromJson(Map<String, dynamic> json) => _$MotorcycleFromJson(json);

@override final  int id;
@override final  int userId;
@override final  String make;
@override final  String model;
@override final  int year;
@override final  String? imageUrl;
@override final  String? category;
@override@JsonKey() final  bool isPrimary;
 final  Map<String, String> _specifications;
@override@JsonKey() Map<String, String> get specifications {
  if (_specifications is EqualUnmodifiableMapView) return _specifications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_specifications);
}

 final  List<Modification> _modifications;
@override@JsonKey() List<Modification> get modifications {
  if (_modifications is EqualUnmodifiableListView) return _modifications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modifications);
}

@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Motorcycle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MotorcycleCopyWith<_Motorcycle> get copyWith => __$MotorcycleCopyWithImpl<_Motorcycle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MotorcycleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Motorcycle&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model)&&(identical(other.year, year) || other.year == year)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&const DeepCollectionEquality().equals(other._specifications, _specifications)&&const DeepCollectionEquality().equals(other._modifications, _modifications)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,make,model,year,imageUrl,category,isPrimary,const DeepCollectionEquality().hash(_specifications),const DeepCollectionEquality().hash(_modifications),createdAt,updatedAt);

@override
String toString() {
  return 'Motorcycle(id: $id, userId: $userId, make: $make, model: $model, year: $year, imageUrl: $imageUrl, category: $category, isPrimary: $isPrimary, specifications: $specifications, modifications: $modifications, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MotorcycleCopyWith<$Res> implements $MotorcycleCopyWith<$Res> {
  factory _$MotorcycleCopyWith(_Motorcycle value, $Res Function(_Motorcycle) _then) = __$MotorcycleCopyWithImpl;
@override @useResult
$Res call({
 int id, int userId, String make, String model, int year, String? imageUrl, String? category, bool isPrimary, Map<String, String> specifications, List<Modification> modifications, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$MotorcycleCopyWithImpl<$Res>
    implements _$MotorcycleCopyWith<$Res> {
  __$MotorcycleCopyWithImpl(this._self, this._then);

  final _Motorcycle _self;
  final $Res Function(_Motorcycle) _then;

/// Create a copy of Motorcycle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? make = null,Object? model = null,Object? year = null,Object? imageUrl = freezed,Object? category = freezed,Object? isPrimary = null,Object? specifications = null,Object? modifications = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Motorcycle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,make: null == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,specifications: null == specifications ? _self._specifications : specifications // ignore: cast_nullable_to_non_nullable
as Map<String, String>,modifications: null == modifications ? _self._modifications : modifications // ignore: cast_nullable_to_non_nullable
as List<Modification>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$Modification {

 int get id; int get motorcycleId; String get title; String? get description; double? get cost; DateTime? get date; String? get beforeImageUrl; String? get afterImageUrl; DateTime? get createdAt;
/// Create a copy of Modification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModificationCopyWith<Modification> get copyWith => _$ModificationCopyWithImpl<Modification>(this as Modification, _$identity);

  /// Serializes this Modification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Modification&&(identical(other.id, id) || other.id == id)&&(identical(other.motorcycleId, motorcycleId) || other.motorcycleId == motorcycleId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.date, date) || other.date == date)&&(identical(other.beforeImageUrl, beforeImageUrl) || other.beforeImageUrl == beforeImageUrl)&&(identical(other.afterImageUrl, afterImageUrl) || other.afterImageUrl == afterImageUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,motorcycleId,title,description,cost,date,beforeImageUrl,afterImageUrl,createdAt);

@override
String toString() {
  return 'Modification(id: $id, motorcycleId: $motorcycleId, title: $title, description: $description, cost: $cost, date: $date, beforeImageUrl: $beforeImageUrl, afterImageUrl: $afterImageUrl, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ModificationCopyWith<$Res>  {
  factory $ModificationCopyWith(Modification value, $Res Function(Modification) _then) = _$ModificationCopyWithImpl;
@useResult
$Res call({
 int id, int motorcycleId, String title, String? description, double? cost, DateTime? date, String? beforeImageUrl, String? afterImageUrl, DateTime? createdAt
});




}
/// @nodoc
class _$ModificationCopyWithImpl<$Res>
    implements $ModificationCopyWith<$Res> {
  _$ModificationCopyWithImpl(this._self, this._then);

  final Modification _self;
  final $Res Function(Modification) _then;

/// Create a copy of Modification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? motorcycleId = null,Object? title = null,Object? description = freezed,Object? cost = freezed,Object? date = freezed,Object? beforeImageUrl = freezed,Object? afterImageUrl = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,motorcycleId: null == motorcycleId ? _self.motorcycleId : motorcycleId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,beforeImageUrl: freezed == beforeImageUrl ? _self.beforeImageUrl : beforeImageUrl // ignore: cast_nullable_to_non_nullable
as String?,afterImageUrl: freezed == afterImageUrl ? _self.afterImageUrl : afterImageUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Modification].
extension ModificationPatterns on Modification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Modification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Modification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Modification value)  $default,){
final _that = this;
switch (_that) {
case _Modification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Modification value)?  $default,){
final _that = this;
switch (_that) {
case _Modification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int motorcycleId,  String title,  String? description,  double? cost,  DateTime? date,  String? beforeImageUrl,  String? afterImageUrl,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Modification() when $default != null:
return $default(_that.id,_that.motorcycleId,_that.title,_that.description,_that.cost,_that.date,_that.beforeImageUrl,_that.afterImageUrl,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int motorcycleId,  String title,  String? description,  double? cost,  DateTime? date,  String? beforeImageUrl,  String? afterImageUrl,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Modification():
return $default(_that.id,_that.motorcycleId,_that.title,_that.description,_that.cost,_that.date,_that.beforeImageUrl,_that.afterImageUrl,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int motorcycleId,  String title,  String? description,  double? cost,  DateTime? date,  String? beforeImageUrl,  String? afterImageUrl,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Modification() when $default != null:
return $default(_that.id,_that.motorcycleId,_that.title,_that.description,_that.cost,_that.date,_that.beforeImageUrl,_that.afterImageUrl,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Modification implements Modification {
  const _Modification({required this.id, required this.motorcycleId, required this.title, this.description, this.cost, this.date, this.beforeImageUrl, this.afterImageUrl, this.createdAt});
  factory _Modification.fromJson(Map<String, dynamic> json) => _$ModificationFromJson(json);

@override final  int id;
@override final  int motorcycleId;
@override final  String title;
@override final  String? description;
@override final  double? cost;
@override final  DateTime? date;
@override final  String? beforeImageUrl;
@override final  String? afterImageUrl;
@override final  DateTime? createdAt;

/// Create a copy of Modification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModificationCopyWith<_Modification> get copyWith => __$ModificationCopyWithImpl<_Modification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Modification&&(identical(other.id, id) || other.id == id)&&(identical(other.motorcycleId, motorcycleId) || other.motorcycleId == motorcycleId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.date, date) || other.date == date)&&(identical(other.beforeImageUrl, beforeImageUrl) || other.beforeImageUrl == beforeImageUrl)&&(identical(other.afterImageUrl, afterImageUrl) || other.afterImageUrl == afterImageUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,motorcycleId,title,description,cost,date,beforeImageUrl,afterImageUrl,createdAt);

@override
String toString() {
  return 'Modification(id: $id, motorcycleId: $motorcycleId, title: $title, description: $description, cost: $cost, date: $date, beforeImageUrl: $beforeImageUrl, afterImageUrl: $afterImageUrl, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ModificationCopyWith<$Res> implements $ModificationCopyWith<$Res> {
  factory _$ModificationCopyWith(_Modification value, $Res Function(_Modification) _then) = __$ModificationCopyWithImpl;
@override @useResult
$Res call({
 int id, int motorcycleId, String title, String? description, double? cost, DateTime? date, String? beforeImageUrl, String? afterImageUrl, DateTime? createdAt
});




}
/// @nodoc
class __$ModificationCopyWithImpl<$Res>
    implements _$ModificationCopyWith<$Res> {
  __$ModificationCopyWithImpl(this._self, this._then);

  final _Modification _self;
  final $Res Function(_Modification) _then;

/// Create a copy of Modification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? motorcycleId = null,Object? title = null,Object? description = freezed,Object? cost = freezed,Object? date = freezed,Object? beforeImageUrl = freezed,Object? afterImageUrl = freezed,Object? createdAt = freezed,}) {
  return _then(_Modification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,motorcycleId: null == motorcycleId ? _self.motorcycleId : motorcycleId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,beforeImageUrl: freezed == beforeImageUrl ? _self.beforeImageUrl : beforeImageUrl // ignore: cast_nullable_to_non_nullable
as String?,afterImageUrl: freezed == afterImageUrl ? _self.afterImageUrl : afterImageUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
