// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Post {

/// Supabase uses bigint auto-increment for posts
 int get id;/// Supabase user UUID
 String get userId; String get username; String? get displayName; String? get avatarUrl; String? get body; String? get imageUrl; String? get videoUrl; String? get thumbnailUrl; List<String> get attachmentUrls; String? get community;/// Media type: image, video, carousel, text
 String get mediaType; double? get aspectRatio; int? get durationSeconds; int get likeCount; int get commentCount; int get viewCount; int get repostCount; int get saveCount; bool get likedByMe;/// Reaction type if user reacted ('fire', 'love', etc.) — null = regular like
 String? get myReaction; bool get savedByMe; bool get isMine; bool get isPromoted; int? get promotionId;/// Visibility: 'public', 'followers', 'private'
 String get visibility;/// Topic IDs attached to this post (≤3)
 List<int> get topicIds; DateTime? get createdAt; DateTime? get editedAt;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&const DeepCollectionEquality().equals(other.attachmentUrls, attachmentUrls)&&(identical(other.community, community) || other.community == community)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.repostCount, repostCount) || other.repostCount == repostCount)&&(identical(other.saveCount, saveCount) || other.saveCount == saveCount)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.savedByMe, savedByMe) || other.savedByMe == savedByMe)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.isPromoted, isPromoted) || other.isPromoted == isPromoted)&&(identical(other.promotionId, promotionId) || other.promotionId == promotionId)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&const DeepCollectionEquality().equals(other.topicIds, topicIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,username,displayName,avatarUrl,body,imageUrl,videoUrl,thumbnailUrl,const DeepCollectionEquality().hash(attachmentUrls),community,mediaType,aspectRatio,durationSeconds,likeCount,commentCount,viewCount,repostCount,saveCount,likedByMe,myReaction,savedByMe,isMine,isPromoted,promotionId,visibility,const DeepCollectionEquality().hash(topicIds),createdAt,editedAt]);

@override
String toString() {
  return 'Post(id: $id, userId: $userId, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, body: $body, imageUrl: $imageUrl, videoUrl: $videoUrl, thumbnailUrl: $thumbnailUrl, attachmentUrls: $attachmentUrls, community: $community, mediaType: $mediaType, aspectRatio: $aspectRatio, durationSeconds: $durationSeconds, likeCount: $likeCount, commentCount: $commentCount, viewCount: $viewCount, repostCount: $repostCount, saveCount: $saveCount, likedByMe: $likedByMe, myReaction: $myReaction, savedByMe: $savedByMe, isMine: $isMine, isPromoted: $isPromoted, promotionId: $promotionId, visibility: $visibility, topicIds: $topicIds, createdAt: $createdAt, editedAt: $editedAt)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 int id, String userId, String username, String? displayName, String? avatarUrl, String? body, String? imageUrl, String? videoUrl, String? thumbnailUrl, List<String> attachmentUrls, String? community, String mediaType, double? aspectRatio, int? durationSeconds, int likeCount, int commentCount, int viewCount, int repostCount, int saveCount, bool likedByMe, String? myReaction, bool savedByMe, bool isMine, bool isPromoted, int? promotionId, String visibility, List<int> topicIds, DateTime? createdAt, DateTime? editedAt
});




}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? body = freezed,Object? imageUrl = freezed,Object? videoUrl = freezed,Object? thumbnailUrl = freezed,Object? attachmentUrls = null,Object? community = freezed,Object? mediaType = null,Object? aspectRatio = freezed,Object? durationSeconds = freezed,Object? likeCount = null,Object? commentCount = null,Object? viewCount = null,Object? repostCount = null,Object? saveCount = null,Object? likedByMe = null,Object? myReaction = freezed,Object? savedByMe = null,Object? isMine = null,Object? isPromoted = null,Object? promotionId = freezed,Object? visibility = null,Object? topicIds = null,Object? createdAt = freezed,Object? editedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,attachmentUrls: null == attachmentUrls ? _self.attachmentUrls : attachmentUrls // ignore: cast_nullable_to_non_nullable
as List<String>,community: freezed == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String?,mediaType: null == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String,aspectRatio: freezed == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as double?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,repostCount: null == repostCount ? _self.repostCount : repostCount // ignore: cast_nullable_to_non_nullable
as int,saveCount: null == saveCount ? _self.saveCount : saveCount // ignore: cast_nullable_to_non_nullable
as int,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,savedByMe: null == savedByMe ? _self.savedByMe : savedByMe // ignore: cast_nullable_to_non_nullable
as bool,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,isPromoted: null == isPromoted ? _self.isPromoted : isPromoted // ignore: cast_nullable_to_non_nullable
as bool,promotionId: freezed == promotionId ? _self.promotionId : promotionId // ignore: cast_nullable_to_non_nullable
as int?,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,topicIds: null == topicIds ? _self.topicIds : topicIds // ignore: cast_nullable_to_non_nullable
as List<int>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String userId,  String username,  String? displayName,  String? avatarUrl,  String? body,  String? imageUrl,  String? videoUrl,  String? thumbnailUrl,  List<String> attachmentUrls,  String? community,  String mediaType,  double? aspectRatio,  int? durationSeconds,  int likeCount,  int commentCount,  int viewCount,  int repostCount,  int saveCount,  bool likedByMe,  String? myReaction,  bool savedByMe,  bool isMine,  bool isPromoted,  int? promotionId,  String visibility,  List<int> topicIds,  DateTime? createdAt,  DateTime? editedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.userId,_that.username,_that.displayName,_that.avatarUrl,_that.body,_that.imageUrl,_that.videoUrl,_that.thumbnailUrl,_that.attachmentUrls,_that.community,_that.mediaType,_that.aspectRatio,_that.durationSeconds,_that.likeCount,_that.commentCount,_that.viewCount,_that.repostCount,_that.saveCount,_that.likedByMe,_that.myReaction,_that.savedByMe,_that.isMine,_that.isPromoted,_that.promotionId,_that.visibility,_that.topicIds,_that.createdAt,_that.editedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String userId,  String username,  String? displayName,  String? avatarUrl,  String? body,  String? imageUrl,  String? videoUrl,  String? thumbnailUrl,  List<String> attachmentUrls,  String? community,  String mediaType,  double? aspectRatio,  int? durationSeconds,  int likeCount,  int commentCount,  int viewCount,  int repostCount,  int saveCount,  bool likedByMe,  String? myReaction,  bool savedByMe,  bool isMine,  bool isPromoted,  int? promotionId,  String visibility,  List<int> topicIds,  DateTime? createdAt,  DateTime? editedAt)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.userId,_that.username,_that.displayName,_that.avatarUrl,_that.body,_that.imageUrl,_that.videoUrl,_that.thumbnailUrl,_that.attachmentUrls,_that.community,_that.mediaType,_that.aspectRatio,_that.durationSeconds,_that.likeCount,_that.commentCount,_that.viewCount,_that.repostCount,_that.saveCount,_that.likedByMe,_that.myReaction,_that.savedByMe,_that.isMine,_that.isPromoted,_that.promotionId,_that.visibility,_that.topicIds,_that.createdAt,_that.editedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String userId,  String username,  String? displayName,  String? avatarUrl,  String? body,  String? imageUrl,  String? videoUrl,  String? thumbnailUrl,  List<String> attachmentUrls,  String? community,  String mediaType,  double? aspectRatio,  int? durationSeconds,  int likeCount,  int commentCount,  int viewCount,  int repostCount,  int saveCount,  bool likedByMe,  String? myReaction,  bool savedByMe,  bool isMine,  bool isPromoted,  int? promotionId,  String visibility,  List<int> topicIds,  DateTime? createdAt,  DateTime? editedAt)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.userId,_that.username,_that.displayName,_that.avatarUrl,_that.body,_that.imageUrl,_that.videoUrl,_that.thumbnailUrl,_that.attachmentUrls,_that.community,_that.mediaType,_that.aspectRatio,_that.durationSeconds,_that.likeCount,_that.commentCount,_that.viewCount,_that.repostCount,_that.saveCount,_that.likedByMe,_that.myReaction,_that.savedByMe,_that.isMine,_that.isPromoted,_that.promotionId,_that.visibility,_that.topicIds,_that.createdAt,_that.editedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post implements Post {
  const _Post({required this.id, required this.userId, required this.username, this.displayName, this.avatarUrl, this.body, this.imageUrl, this.videoUrl, this.thumbnailUrl, final  List<String> attachmentUrls = const [], this.community, this.mediaType = 'image', this.aspectRatio, this.durationSeconds, this.likeCount = 0, this.commentCount = 0, this.viewCount = 0, this.repostCount = 0, this.saveCount = 0, this.likedByMe = false, this.myReaction, this.savedByMe = false, this.isMine = false, this.isPromoted = false, this.promotionId, this.visibility = 'public', final  List<int> topicIds = const [], this.createdAt, this.editedAt}): _attachmentUrls = attachmentUrls,_topicIds = topicIds;
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

/// Supabase uses bigint auto-increment for posts
@override final  int id;
/// Supabase user UUID
@override final  String userId;
@override final  String username;
@override final  String? displayName;
@override final  String? avatarUrl;
@override final  String? body;
@override final  String? imageUrl;
@override final  String? videoUrl;
@override final  String? thumbnailUrl;
 final  List<String> _attachmentUrls;
@override@JsonKey() List<String> get attachmentUrls {
  if (_attachmentUrls is EqualUnmodifiableListView) return _attachmentUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachmentUrls);
}

@override final  String? community;
/// Media type: image, video, carousel, text
@override@JsonKey() final  String mediaType;
@override final  double? aspectRatio;
@override final  int? durationSeconds;
@override@JsonKey() final  int likeCount;
@override@JsonKey() final  int commentCount;
@override@JsonKey() final  int viewCount;
@override@JsonKey() final  int repostCount;
@override@JsonKey() final  int saveCount;
@override@JsonKey() final  bool likedByMe;
/// Reaction type if user reacted ('fire', 'love', etc.) — null = regular like
@override final  String? myReaction;
@override@JsonKey() final  bool savedByMe;
@override@JsonKey() final  bool isMine;
@override@JsonKey() final  bool isPromoted;
@override final  int? promotionId;
/// Visibility: 'public', 'followers', 'private'
@override@JsonKey() final  String visibility;
/// Topic IDs attached to this post (≤3)
 final  List<int> _topicIds;
/// Topic IDs attached to this post (≤3)
@override@JsonKey() List<int> get topicIds {
  if (_topicIds is EqualUnmodifiableListView) return _topicIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topicIds);
}

@override final  DateTime? createdAt;
@override final  DateTime? editedAt;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&const DeepCollectionEquality().equals(other._attachmentUrls, _attachmentUrls)&&(identical(other.community, community) || other.community == community)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.viewCount, viewCount) || other.viewCount == viewCount)&&(identical(other.repostCount, repostCount) || other.repostCount == repostCount)&&(identical(other.saveCount, saveCount) || other.saveCount == saveCount)&&(identical(other.likedByMe, likedByMe) || other.likedByMe == likedByMe)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.savedByMe, savedByMe) || other.savedByMe == savedByMe)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.isPromoted, isPromoted) || other.isPromoted == isPromoted)&&(identical(other.promotionId, promotionId) || other.promotionId == promotionId)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&const DeepCollectionEquality().equals(other._topicIds, _topicIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,username,displayName,avatarUrl,body,imageUrl,videoUrl,thumbnailUrl,const DeepCollectionEquality().hash(_attachmentUrls),community,mediaType,aspectRatio,durationSeconds,likeCount,commentCount,viewCount,repostCount,saveCount,likedByMe,myReaction,savedByMe,isMine,isPromoted,promotionId,visibility,const DeepCollectionEquality().hash(_topicIds),createdAt,editedAt]);

@override
String toString() {
  return 'Post(id: $id, userId: $userId, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, body: $body, imageUrl: $imageUrl, videoUrl: $videoUrl, thumbnailUrl: $thumbnailUrl, attachmentUrls: $attachmentUrls, community: $community, mediaType: $mediaType, aspectRatio: $aspectRatio, durationSeconds: $durationSeconds, likeCount: $likeCount, commentCount: $commentCount, viewCount: $viewCount, repostCount: $repostCount, saveCount: $saveCount, likedByMe: $likedByMe, myReaction: $myReaction, savedByMe: $savedByMe, isMine: $isMine, isPromoted: $isPromoted, promotionId: $promotionId, visibility: $visibility, topicIds: $topicIds, createdAt: $createdAt, editedAt: $editedAt)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 int id, String userId, String username, String? displayName, String? avatarUrl, String? body, String? imageUrl, String? videoUrl, String? thumbnailUrl, List<String> attachmentUrls, String? community, String mediaType, double? aspectRatio, int? durationSeconds, int likeCount, int commentCount, int viewCount, int repostCount, int saveCount, bool likedByMe, String? myReaction, bool savedByMe, bool isMine, bool isPromoted, int? promotionId, String visibility, List<int> topicIds, DateTime? createdAt, DateTime? editedAt
});




}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? username = null,Object? displayName = freezed,Object? avatarUrl = freezed,Object? body = freezed,Object? imageUrl = freezed,Object? videoUrl = freezed,Object? thumbnailUrl = freezed,Object? attachmentUrls = null,Object? community = freezed,Object? mediaType = null,Object? aspectRatio = freezed,Object? durationSeconds = freezed,Object? likeCount = null,Object? commentCount = null,Object? viewCount = null,Object? repostCount = null,Object? saveCount = null,Object? likedByMe = null,Object? myReaction = freezed,Object? savedByMe = null,Object? isMine = null,Object? isPromoted = null,Object? promotionId = freezed,Object? visibility = null,Object? topicIds = null,Object? createdAt = freezed,Object? editedAt = freezed,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,attachmentUrls: null == attachmentUrls ? _self._attachmentUrls : attachmentUrls // ignore: cast_nullable_to_non_nullable
as List<String>,community: freezed == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String?,mediaType: null == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String,aspectRatio: freezed == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as double?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,commentCount: null == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int,viewCount: null == viewCount ? _self.viewCount : viewCount // ignore: cast_nullable_to_non_nullable
as int,repostCount: null == repostCount ? _self.repostCount : repostCount // ignore: cast_nullable_to_non_nullable
as int,saveCount: null == saveCount ? _self.saveCount : saveCount // ignore: cast_nullable_to_non_nullable
as int,likedByMe: null == likedByMe ? _self.likedByMe : likedByMe // ignore: cast_nullable_to_non_nullable
as bool,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,savedByMe: null == savedByMe ? _self.savedByMe : savedByMe // ignore: cast_nullable_to_non_nullable
as bool,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,isPromoted: null == isPromoted ? _self.isPromoted : isPromoted // ignore: cast_nullable_to_non_nullable
as bool,promotionId: freezed == promotionId ? _self.promotionId : promotionId // ignore: cast_nullable_to_non_nullable
as int?,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,topicIds: null == topicIds ? _self._topicIds : topicIds // ignore: cast_nullable_to_non_nullable
as List<int>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
