// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_stream.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveStream {

 String get id; String get hostUserId; String get title; String get status;// preparing, live, ended
 int? get topicId; String? get ivsChannelArn; String? get ivsIngestEndpoint; String? get ivsStreamKey; String? get playbackUrl; String? get thumbnailUrl; int get viewerCount; int get peakViewerCount; int get totalUniqueViewers; int get totalChatMessages; String get community; DateTime? get startedAt; DateTime? get endedAt; DateTime? get createdAt;// Host profile info (denormalized for display)
 String? get hostUsername; String? get hostDisplayName; String? get hostAvatarUrl;
/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveStreamCopyWith<LiveStream> get copyWith => _$LiveStreamCopyWithImpl<LiveStream>(this as LiveStream, _$identity);

  /// Serializes this LiveStream to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveStream&&(identical(other.id, id) || other.id == id)&&(identical(other.hostUserId, hostUserId) || other.hostUserId == hostUserId)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.topicId, topicId) || other.topicId == topicId)&&(identical(other.ivsChannelArn, ivsChannelArn) || other.ivsChannelArn == ivsChannelArn)&&(identical(other.ivsIngestEndpoint, ivsIngestEndpoint) || other.ivsIngestEndpoint == ivsIngestEndpoint)&&(identical(other.ivsStreamKey, ivsStreamKey) || other.ivsStreamKey == ivsStreamKey)&&(identical(other.playbackUrl, playbackUrl) || other.playbackUrl == playbackUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.peakViewerCount, peakViewerCount) || other.peakViewerCount == peakViewerCount)&&(identical(other.totalUniqueViewers, totalUniqueViewers) || other.totalUniqueViewers == totalUniqueViewers)&&(identical(other.totalChatMessages, totalChatMessages) || other.totalChatMessages == totalChatMessages)&&(identical(other.community, community) || other.community == community)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.hostUsername, hostUsername) || other.hostUsername == hostUsername)&&(identical(other.hostDisplayName, hostDisplayName) || other.hostDisplayName == hostDisplayName)&&(identical(other.hostAvatarUrl, hostAvatarUrl) || other.hostAvatarUrl == hostAvatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,hostUserId,title,status,topicId,ivsChannelArn,ivsIngestEndpoint,ivsStreamKey,playbackUrl,thumbnailUrl,viewerCount,peakViewerCount,totalUniqueViewers,totalChatMessages,community,startedAt,endedAt,createdAt,hostUsername,hostDisplayName,hostAvatarUrl]);

@override
String toString() {
  return 'LiveStream(id: $id, hostUserId: $hostUserId, title: $title, status: $status, topicId: $topicId, ivsChannelArn: $ivsChannelArn, ivsIngestEndpoint: $ivsIngestEndpoint, ivsStreamKey: $ivsStreamKey, playbackUrl: $playbackUrl, thumbnailUrl: $thumbnailUrl, viewerCount: $viewerCount, peakViewerCount: $peakViewerCount, totalUniqueViewers: $totalUniqueViewers, totalChatMessages: $totalChatMessages, community: $community, startedAt: $startedAt, endedAt: $endedAt, createdAt: $createdAt, hostUsername: $hostUsername, hostDisplayName: $hostDisplayName, hostAvatarUrl: $hostAvatarUrl)';
}


}

/// @nodoc
abstract mixin class $LiveStreamCopyWith<$Res>  {
  factory $LiveStreamCopyWith(LiveStream value, $Res Function(LiveStream) _then) = _$LiveStreamCopyWithImpl;
@useResult
$Res call({
 String id, String hostUserId, String title, String status, int? topicId, String? ivsChannelArn, String? ivsIngestEndpoint, String? ivsStreamKey, String? playbackUrl, String? thumbnailUrl, int viewerCount, int peakViewerCount, int totalUniqueViewers, int totalChatMessages, String community, DateTime? startedAt, DateTime? endedAt, DateTime? createdAt, String? hostUsername, String? hostDisplayName, String? hostAvatarUrl
});




}
/// @nodoc
class _$LiveStreamCopyWithImpl<$Res>
    implements $LiveStreamCopyWith<$Res> {
  _$LiveStreamCopyWithImpl(this._self, this._then);

  final LiveStream _self;
  final $Res Function(LiveStream) _then;

/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? hostUserId = null,Object? title = null,Object? status = null,Object? topicId = freezed,Object? ivsChannelArn = freezed,Object? ivsIngestEndpoint = freezed,Object? ivsStreamKey = freezed,Object? playbackUrl = freezed,Object? thumbnailUrl = freezed,Object? viewerCount = null,Object? peakViewerCount = null,Object? totalUniqueViewers = null,Object? totalChatMessages = null,Object? community = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? createdAt = freezed,Object? hostUsername = freezed,Object? hostDisplayName = freezed,Object? hostAvatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hostUserId: null == hostUserId ? _self.hostUserId : hostUserId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,topicId: freezed == topicId ? _self.topicId : topicId // ignore: cast_nullable_to_non_nullable
as int?,ivsChannelArn: freezed == ivsChannelArn ? _self.ivsChannelArn : ivsChannelArn // ignore: cast_nullable_to_non_nullable
as String?,ivsIngestEndpoint: freezed == ivsIngestEndpoint ? _self.ivsIngestEndpoint : ivsIngestEndpoint // ignore: cast_nullable_to_non_nullable
as String?,ivsStreamKey: freezed == ivsStreamKey ? _self.ivsStreamKey : ivsStreamKey // ignore: cast_nullable_to_non_nullable
as String?,playbackUrl: freezed == playbackUrl ? _self.playbackUrl : playbackUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,peakViewerCount: null == peakViewerCount ? _self.peakViewerCount : peakViewerCount // ignore: cast_nullable_to_non_nullable
as int,totalUniqueViewers: null == totalUniqueViewers ? _self.totalUniqueViewers : totalUniqueViewers // ignore: cast_nullable_to_non_nullable
as int,totalChatMessages: null == totalChatMessages ? _self.totalChatMessages : totalChatMessages // ignore: cast_nullable_to_non_nullable
as int,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hostUsername: freezed == hostUsername ? _self.hostUsername : hostUsername // ignore: cast_nullable_to_non_nullable
as String?,hostDisplayName: freezed == hostDisplayName ? _self.hostDisplayName : hostDisplayName // ignore: cast_nullable_to_non_nullable
as String?,hostAvatarUrl: freezed == hostAvatarUrl ? _self.hostAvatarUrl : hostAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveStream].
extension LiveStreamPatterns on LiveStream {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveStream value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveStream value)  $default,){
final _that = this;
switch (_that) {
case _LiveStream():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveStream value)?  $default,){
final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String hostUserId,  String title,  String status,  int? topicId,  String? ivsChannelArn,  String? ivsIngestEndpoint,  String? ivsStreamKey,  String? playbackUrl,  String? thumbnailUrl,  int viewerCount,  int peakViewerCount,  int totalUniqueViewers,  int totalChatMessages,  String community,  DateTime? startedAt,  DateTime? endedAt,  DateTime? createdAt,  String? hostUsername,  String? hostDisplayName,  String? hostAvatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
return $default(_that.id,_that.hostUserId,_that.title,_that.status,_that.topicId,_that.ivsChannelArn,_that.ivsIngestEndpoint,_that.ivsStreamKey,_that.playbackUrl,_that.thumbnailUrl,_that.viewerCount,_that.peakViewerCount,_that.totalUniqueViewers,_that.totalChatMessages,_that.community,_that.startedAt,_that.endedAt,_that.createdAt,_that.hostUsername,_that.hostDisplayName,_that.hostAvatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String hostUserId,  String title,  String status,  int? topicId,  String? ivsChannelArn,  String? ivsIngestEndpoint,  String? ivsStreamKey,  String? playbackUrl,  String? thumbnailUrl,  int viewerCount,  int peakViewerCount,  int totalUniqueViewers,  int totalChatMessages,  String community,  DateTime? startedAt,  DateTime? endedAt,  DateTime? createdAt,  String? hostUsername,  String? hostDisplayName,  String? hostAvatarUrl)  $default,) {final _that = this;
switch (_that) {
case _LiveStream():
return $default(_that.id,_that.hostUserId,_that.title,_that.status,_that.topicId,_that.ivsChannelArn,_that.ivsIngestEndpoint,_that.ivsStreamKey,_that.playbackUrl,_that.thumbnailUrl,_that.viewerCount,_that.peakViewerCount,_that.totalUniqueViewers,_that.totalChatMessages,_that.community,_that.startedAt,_that.endedAt,_that.createdAt,_that.hostUsername,_that.hostDisplayName,_that.hostAvatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String hostUserId,  String title,  String status,  int? topicId,  String? ivsChannelArn,  String? ivsIngestEndpoint,  String? ivsStreamKey,  String? playbackUrl,  String? thumbnailUrl,  int viewerCount,  int peakViewerCount,  int totalUniqueViewers,  int totalChatMessages,  String community,  DateTime? startedAt,  DateTime? endedAt,  DateTime? createdAt,  String? hostUsername,  String? hostDisplayName,  String? hostAvatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _LiveStream() when $default != null:
return $default(_that.id,_that.hostUserId,_that.title,_that.status,_that.topicId,_that.ivsChannelArn,_that.ivsIngestEndpoint,_that.ivsStreamKey,_that.playbackUrl,_that.thumbnailUrl,_that.viewerCount,_that.peakViewerCount,_that.totalUniqueViewers,_that.totalChatMessages,_that.community,_that.startedAt,_that.endedAt,_that.createdAt,_that.hostUsername,_that.hostDisplayName,_that.hostAvatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveStream implements LiveStream {
  const _LiveStream({required this.id, required this.hostUserId, required this.title, this.status = 'preparing', this.topicId, this.ivsChannelArn, this.ivsIngestEndpoint, this.ivsStreamKey, this.playbackUrl, this.thumbnailUrl, this.viewerCount = 0, this.peakViewerCount = 0, this.totalUniqueViewers = 0, this.totalChatMessages = 0, this.community = 'bikergram', this.startedAt, this.endedAt, this.createdAt, this.hostUsername, this.hostDisplayName, this.hostAvatarUrl});
  factory _LiveStream.fromJson(Map<String, dynamic> json) => _$LiveStreamFromJson(json);

@override final  String id;
@override final  String hostUserId;
@override final  String title;
@override@JsonKey() final  String status;
// preparing, live, ended
@override final  int? topicId;
@override final  String? ivsChannelArn;
@override final  String? ivsIngestEndpoint;
@override final  String? ivsStreamKey;
@override final  String? playbackUrl;
@override final  String? thumbnailUrl;
@override@JsonKey() final  int viewerCount;
@override@JsonKey() final  int peakViewerCount;
@override@JsonKey() final  int totalUniqueViewers;
@override@JsonKey() final  int totalChatMessages;
@override@JsonKey() final  String community;
@override final  DateTime? startedAt;
@override final  DateTime? endedAt;
@override final  DateTime? createdAt;
// Host profile info (denormalized for display)
@override final  String? hostUsername;
@override final  String? hostDisplayName;
@override final  String? hostAvatarUrl;

/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveStreamCopyWith<_LiveStream> get copyWith => __$LiveStreamCopyWithImpl<_LiveStream>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveStreamToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveStream&&(identical(other.id, id) || other.id == id)&&(identical(other.hostUserId, hostUserId) || other.hostUserId == hostUserId)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.topicId, topicId) || other.topicId == topicId)&&(identical(other.ivsChannelArn, ivsChannelArn) || other.ivsChannelArn == ivsChannelArn)&&(identical(other.ivsIngestEndpoint, ivsIngestEndpoint) || other.ivsIngestEndpoint == ivsIngestEndpoint)&&(identical(other.ivsStreamKey, ivsStreamKey) || other.ivsStreamKey == ivsStreamKey)&&(identical(other.playbackUrl, playbackUrl) || other.playbackUrl == playbackUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.peakViewerCount, peakViewerCount) || other.peakViewerCount == peakViewerCount)&&(identical(other.totalUniqueViewers, totalUniqueViewers) || other.totalUniqueViewers == totalUniqueViewers)&&(identical(other.totalChatMessages, totalChatMessages) || other.totalChatMessages == totalChatMessages)&&(identical(other.community, community) || other.community == community)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.hostUsername, hostUsername) || other.hostUsername == hostUsername)&&(identical(other.hostDisplayName, hostDisplayName) || other.hostDisplayName == hostDisplayName)&&(identical(other.hostAvatarUrl, hostAvatarUrl) || other.hostAvatarUrl == hostAvatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,hostUserId,title,status,topicId,ivsChannelArn,ivsIngestEndpoint,ivsStreamKey,playbackUrl,thumbnailUrl,viewerCount,peakViewerCount,totalUniqueViewers,totalChatMessages,community,startedAt,endedAt,createdAt,hostUsername,hostDisplayName,hostAvatarUrl]);

@override
String toString() {
  return 'LiveStream(id: $id, hostUserId: $hostUserId, title: $title, status: $status, topicId: $topicId, ivsChannelArn: $ivsChannelArn, ivsIngestEndpoint: $ivsIngestEndpoint, ivsStreamKey: $ivsStreamKey, playbackUrl: $playbackUrl, thumbnailUrl: $thumbnailUrl, viewerCount: $viewerCount, peakViewerCount: $peakViewerCount, totalUniqueViewers: $totalUniqueViewers, totalChatMessages: $totalChatMessages, community: $community, startedAt: $startedAt, endedAt: $endedAt, createdAt: $createdAt, hostUsername: $hostUsername, hostDisplayName: $hostDisplayName, hostAvatarUrl: $hostAvatarUrl)';
}


}

/// @nodoc
abstract mixin class _$LiveStreamCopyWith<$Res> implements $LiveStreamCopyWith<$Res> {
  factory _$LiveStreamCopyWith(_LiveStream value, $Res Function(_LiveStream) _then) = __$LiveStreamCopyWithImpl;
@override @useResult
$Res call({
 String id, String hostUserId, String title, String status, int? topicId, String? ivsChannelArn, String? ivsIngestEndpoint, String? ivsStreamKey, String? playbackUrl, String? thumbnailUrl, int viewerCount, int peakViewerCount, int totalUniqueViewers, int totalChatMessages, String community, DateTime? startedAt, DateTime? endedAt, DateTime? createdAt, String? hostUsername, String? hostDisplayName, String? hostAvatarUrl
});




}
/// @nodoc
class __$LiveStreamCopyWithImpl<$Res>
    implements _$LiveStreamCopyWith<$Res> {
  __$LiveStreamCopyWithImpl(this._self, this._then);

  final _LiveStream _self;
  final $Res Function(_LiveStream) _then;

/// Create a copy of LiveStream
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hostUserId = null,Object? title = null,Object? status = null,Object? topicId = freezed,Object? ivsChannelArn = freezed,Object? ivsIngestEndpoint = freezed,Object? ivsStreamKey = freezed,Object? playbackUrl = freezed,Object? thumbnailUrl = freezed,Object? viewerCount = null,Object? peakViewerCount = null,Object? totalUniqueViewers = null,Object? totalChatMessages = null,Object? community = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? createdAt = freezed,Object? hostUsername = freezed,Object? hostDisplayName = freezed,Object? hostAvatarUrl = freezed,}) {
  return _then(_LiveStream(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hostUserId: null == hostUserId ? _self.hostUserId : hostUserId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,topicId: freezed == topicId ? _self.topicId : topicId // ignore: cast_nullable_to_non_nullable
as int?,ivsChannelArn: freezed == ivsChannelArn ? _self.ivsChannelArn : ivsChannelArn // ignore: cast_nullable_to_non_nullable
as String?,ivsIngestEndpoint: freezed == ivsIngestEndpoint ? _self.ivsIngestEndpoint : ivsIngestEndpoint // ignore: cast_nullable_to_non_nullable
as String?,ivsStreamKey: freezed == ivsStreamKey ? _self.ivsStreamKey : ivsStreamKey // ignore: cast_nullable_to_non_nullable
as String?,playbackUrl: freezed == playbackUrl ? _self.playbackUrl : playbackUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,peakViewerCount: null == peakViewerCount ? _self.peakViewerCount : peakViewerCount // ignore: cast_nullable_to_non_nullable
as int,totalUniqueViewers: null == totalUniqueViewers ? _self.totalUniqueViewers : totalUniqueViewers // ignore: cast_nullable_to_non_nullable
as int,totalChatMessages: null == totalChatMessages ? _self.totalChatMessages : totalChatMessages // ignore: cast_nullable_to_non_nullable
as int,community: null == community ? _self.community : community // ignore: cast_nullable_to_non_nullable
as String,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,hostUsername: freezed == hostUsername ? _self.hostUsername : hostUsername // ignore: cast_nullable_to_non_nullable
as String?,hostDisplayName: freezed == hostDisplayName ? _self.hostDisplayName : hostDisplayName // ignore: cast_nullable_to_non_nullable
as String?,hostAvatarUrl: freezed == hostAvatarUrl ? _self.hostAvatarUrl : hostAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LiveChatMessage {

 int get id; String get liveSessionId; String get userId; String get message; String get moderationState; DateTime? get createdAt;// Sender info (denormalized)
 String? get username; String? get displayName; String? get avatarUrl;
/// Create a copy of LiveChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveChatMessageCopyWith<LiveChatMessage> get copyWith => _$LiveChatMessageCopyWithImpl<LiveChatMessage>(this as LiveChatMessage, _$identity);

  /// Serializes this LiveChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.liveSessionId, liveSessionId) || other.liveSessionId == liveSessionId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.message, message) || other.message == message)&&(identical(other.moderationState, moderationState) || other.moderationState == moderationState)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,liveSessionId,userId,message,moderationState,createdAt,username,displayName,avatarUrl);

@override
String toString() {
  return 'LiveChatMessage(id: $id, liveSessionId: $liveSessionId, userId: $userId, message: $message, moderationState: $moderationState, createdAt: $createdAt, username: $username, displayName: $displayName, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $LiveChatMessageCopyWith<$Res>  {
  factory $LiveChatMessageCopyWith(LiveChatMessage value, $Res Function(LiveChatMessage) _then) = _$LiveChatMessageCopyWithImpl;
@useResult
$Res call({
 int id, String liveSessionId, String userId, String message, String moderationState, DateTime? createdAt, String? username, String? displayName, String? avatarUrl
});




}
/// @nodoc
class _$LiveChatMessageCopyWithImpl<$Res>
    implements $LiveChatMessageCopyWith<$Res> {
  _$LiveChatMessageCopyWithImpl(this._self, this._then);

  final LiveChatMessage _self;
  final $Res Function(LiveChatMessage) _then;

/// Create a copy of LiveChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? liveSessionId = null,Object? userId = null,Object? message = null,Object? moderationState = null,Object? createdAt = freezed,Object? username = freezed,Object? displayName = freezed,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,liveSessionId: null == liveSessionId ? _self.liveSessionId : liveSessionId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,moderationState: null == moderationState ? _self.moderationState : moderationState // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveChatMessage].
extension LiveChatMessagePatterns on LiveChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _LiveChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _LiveChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String liveSessionId,  String userId,  String message,  String moderationState,  DateTime? createdAt,  String? username,  String? displayName,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveChatMessage() when $default != null:
return $default(_that.id,_that.liveSessionId,_that.userId,_that.message,_that.moderationState,_that.createdAt,_that.username,_that.displayName,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String liveSessionId,  String userId,  String message,  String moderationState,  DateTime? createdAt,  String? username,  String? displayName,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _LiveChatMessage():
return $default(_that.id,_that.liveSessionId,_that.userId,_that.message,_that.moderationState,_that.createdAt,_that.username,_that.displayName,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String liveSessionId,  String userId,  String message,  String moderationState,  DateTime? createdAt,  String? username,  String? displayName,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _LiveChatMessage() when $default != null:
return $default(_that.id,_that.liveSessionId,_that.userId,_that.message,_that.moderationState,_that.createdAt,_that.username,_that.displayName,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveChatMessage implements LiveChatMessage {
  const _LiveChatMessage({required this.id, required this.liveSessionId, required this.userId, required this.message, this.moderationState = 'visible', this.createdAt, this.username, this.displayName, this.avatarUrl});
  factory _LiveChatMessage.fromJson(Map<String, dynamic> json) => _$LiveChatMessageFromJson(json);

@override final  int id;
@override final  String liveSessionId;
@override final  String userId;
@override final  String message;
@override@JsonKey() final  String moderationState;
@override final  DateTime? createdAt;
// Sender info (denormalized)
@override final  String? username;
@override final  String? displayName;
@override final  String? avatarUrl;

/// Create a copy of LiveChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveChatMessageCopyWith<_LiveChatMessage> get copyWith => __$LiveChatMessageCopyWithImpl<_LiveChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.liveSessionId, liveSessionId) || other.liveSessionId == liveSessionId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.message, message) || other.message == message)&&(identical(other.moderationState, moderationState) || other.moderationState == moderationState)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,liveSessionId,userId,message,moderationState,createdAt,username,displayName,avatarUrl);

@override
String toString() {
  return 'LiveChatMessage(id: $id, liveSessionId: $liveSessionId, userId: $userId, message: $message, moderationState: $moderationState, createdAt: $createdAt, username: $username, displayName: $displayName, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$LiveChatMessageCopyWith<$Res> implements $LiveChatMessageCopyWith<$Res> {
  factory _$LiveChatMessageCopyWith(_LiveChatMessage value, $Res Function(_LiveChatMessage) _then) = __$LiveChatMessageCopyWithImpl;
@override @useResult
$Res call({
 int id, String liveSessionId, String userId, String message, String moderationState, DateTime? createdAt, String? username, String? displayName, String? avatarUrl
});




}
/// @nodoc
class __$LiveChatMessageCopyWithImpl<$Res>
    implements _$LiveChatMessageCopyWith<$Res> {
  __$LiveChatMessageCopyWithImpl(this._self, this._then);

  final _LiveChatMessage _self;
  final $Res Function(_LiveChatMessage) _then;

/// Create a copy of LiveChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? liveSessionId = null,Object? userId = null,Object? message = null,Object? moderationState = null,Object? createdAt = freezed,Object? username = freezed,Object? displayName = freezed,Object? avatarUrl = freezed,}) {
  return _then(_LiveChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,liveSessionId: null == liveSessionId ? _self.liveSessionId : liveSessionId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,moderationState: null == moderationState ? _self.moderationState : moderationState // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
