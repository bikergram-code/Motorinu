// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'direct_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Conversation {

 int get id; String get otherUserId; String? get otherUsername; String? get otherAvatarUrl; String? get lastMessageBody; DateTime? get lastMessageAt; int get unreadCount; DateTime? get createdAt;// Group chat fields
 bool get isGroupChat; int? get groupId; String? get groupName; String? get groupAvatarUrl; DateTime? get archivedAt; DateTime? get deletedAt;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.otherUserId, otherUserId) || other.otherUserId == otherUserId)&&(identical(other.otherUsername, otherUsername) || other.otherUsername == otherUsername)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl)&&(identical(other.lastMessageBody, lastMessageBody) || other.lastMessageBody == lastMessageBody)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isGroupChat, isGroupChat) || other.isGroupChat == isGroupChat)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.groupAvatarUrl, groupAvatarUrl) || other.groupAvatarUrl == groupAvatarUrl)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,otherUserId,otherUsername,otherAvatarUrl,lastMessageBody,lastMessageAt,unreadCount,createdAt,isGroupChat,groupId,groupName,groupAvatarUrl,archivedAt,deletedAt);

@override
String toString() {
  return 'Conversation(id: $id, otherUserId: $otherUserId, otherUsername: $otherUsername, otherAvatarUrl: $otherAvatarUrl, lastMessageBody: $lastMessageBody, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount, createdAt: $createdAt, isGroupChat: $isGroupChat, groupId: $groupId, groupName: $groupName, groupAvatarUrl: $groupAvatarUrl, archivedAt: $archivedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 int id, String otherUserId, String? otherUsername, String? otherAvatarUrl, String? lastMessageBody, DateTime? lastMessageAt, int unreadCount, DateTime? createdAt, bool isGroupChat, int? groupId, String? groupName, String? groupAvatarUrl, DateTime? archivedAt, DateTime? deletedAt
});




}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? otherUserId = null,Object? otherUsername = freezed,Object? otherAvatarUrl = freezed,Object? lastMessageBody = freezed,Object? lastMessageAt = freezed,Object? unreadCount = null,Object? createdAt = freezed,Object? isGroupChat = null,Object? groupId = freezed,Object? groupName = freezed,Object? groupAvatarUrl = freezed,Object? archivedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,otherUserId: null == otherUserId ? _self.otherUserId : otherUserId // ignore: cast_nullable_to_non_nullable
as String,otherUsername: freezed == otherUsername ? _self.otherUsername : otherUsername // ignore: cast_nullable_to_non_nullable
as String?,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,lastMessageBody: freezed == lastMessageBody ? _self.lastMessageBody : lastMessageBody // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isGroupChat: null == isGroupChat ? _self.isGroupChat : isGroupChat // ignore: cast_nullable_to_non_nullable
as bool,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int?,groupName: freezed == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String?,groupAvatarUrl: freezed == groupAvatarUrl ? _self.groupAvatarUrl : groupAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String otherUserId,  String? otherUsername,  String? otherAvatarUrl,  String? lastMessageBody,  DateTime? lastMessageAt,  int unreadCount,  DateTime? createdAt,  bool isGroupChat,  int? groupId,  String? groupName,  String? groupAvatarUrl,  DateTime? archivedAt,  DateTime? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.otherUserId,_that.otherUsername,_that.otherAvatarUrl,_that.lastMessageBody,_that.lastMessageAt,_that.unreadCount,_that.createdAt,_that.isGroupChat,_that.groupId,_that.groupName,_that.groupAvatarUrl,_that.archivedAt,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String otherUserId,  String? otherUsername,  String? otherAvatarUrl,  String? lastMessageBody,  DateTime? lastMessageAt,  int unreadCount,  DateTime? createdAt,  bool isGroupChat,  int? groupId,  String? groupName,  String? groupAvatarUrl,  DateTime? archivedAt,  DateTime? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.id,_that.otherUserId,_that.otherUsername,_that.otherAvatarUrl,_that.lastMessageBody,_that.lastMessageAt,_that.unreadCount,_that.createdAt,_that.isGroupChat,_that.groupId,_that.groupName,_that.groupAvatarUrl,_that.archivedAt,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String otherUserId,  String? otherUsername,  String? otherAvatarUrl,  String? lastMessageBody,  DateTime? lastMessageAt,  int unreadCount,  DateTime? createdAt,  bool isGroupChat,  int? groupId,  String? groupName,  String? groupAvatarUrl,  DateTime? archivedAt,  DateTime? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.otherUserId,_that.otherUsername,_that.otherAvatarUrl,_that.lastMessageBody,_that.lastMessageAt,_that.unreadCount,_that.createdAt,_that.isGroupChat,_that.groupId,_that.groupName,_that.groupAvatarUrl,_that.archivedAt,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Conversation implements Conversation {
  const _Conversation({required this.id, required this.otherUserId, this.otherUsername, this.otherAvatarUrl, this.lastMessageBody, this.lastMessageAt, this.unreadCount = 0, this.createdAt, this.isGroupChat = false, this.groupId, this.groupName, this.groupAvatarUrl, this.archivedAt, this.deletedAt});
  factory _Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

@override final  int id;
@override final  String otherUserId;
@override final  String? otherUsername;
@override final  String? otherAvatarUrl;
@override final  String? lastMessageBody;
@override final  DateTime? lastMessageAt;
@override@JsonKey() final  int unreadCount;
@override final  DateTime? createdAt;
// Group chat fields
@override@JsonKey() final  bool isGroupChat;
@override final  int? groupId;
@override final  String? groupName;
@override final  String? groupAvatarUrl;
@override final  DateTime? archivedAt;
@override final  DateTime? deletedAt;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.otherUserId, otherUserId) || other.otherUserId == otherUserId)&&(identical(other.otherUsername, otherUsername) || other.otherUsername == otherUsername)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl)&&(identical(other.lastMessageBody, lastMessageBody) || other.lastMessageBody == lastMessageBody)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isGroupChat, isGroupChat) || other.isGroupChat == isGroupChat)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.groupAvatarUrl, groupAvatarUrl) || other.groupAvatarUrl == groupAvatarUrl)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,otherUserId,otherUsername,otherAvatarUrl,lastMessageBody,lastMessageAt,unreadCount,createdAt,isGroupChat,groupId,groupName,groupAvatarUrl,archivedAt,deletedAt);

@override
String toString() {
  return 'Conversation(id: $id, otherUserId: $otherUserId, otherUsername: $otherUsername, otherAvatarUrl: $otherAvatarUrl, lastMessageBody: $lastMessageBody, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount, createdAt: $createdAt, isGroupChat: $isGroupChat, groupId: $groupId, groupName: $groupName, groupAvatarUrl: $groupAvatarUrl, archivedAt: $archivedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 int id, String otherUserId, String? otherUsername, String? otherAvatarUrl, String? lastMessageBody, DateTime? lastMessageAt, int unreadCount, DateTime? createdAt, bool isGroupChat, int? groupId, String? groupName, String? groupAvatarUrl, DateTime? archivedAt, DateTime? deletedAt
});




}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? otherUserId = null,Object? otherUsername = freezed,Object? otherAvatarUrl = freezed,Object? lastMessageBody = freezed,Object? lastMessageAt = freezed,Object? unreadCount = null,Object? createdAt = freezed,Object? isGroupChat = null,Object? groupId = freezed,Object? groupName = freezed,Object? groupAvatarUrl = freezed,Object? archivedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(_Conversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,otherUserId: null == otherUserId ? _self.otherUserId : otherUserId // ignore: cast_nullable_to_non_nullable
as String,otherUsername: freezed == otherUsername ? _self.otherUsername : otherUsername // ignore: cast_nullable_to_non_nullable
as String?,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,lastMessageBody: freezed == lastMessageBody ? _self.lastMessageBody : lastMessageBody // ignore: cast_nullable_to_non_nullable
as String?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isGroupChat: null == isGroupChat ? _self.isGroupChat : isGroupChat // ignore: cast_nullable_to_non_nullable
as bool,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int?,groupName: freezed == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String?,groupAvatarUrl: freezed == groupAvatarUrl ? _self.groupAvatarUrl : groupAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$DirectMessage {

 int get id; int get conversationId; String get senderId; String get body; String? get imageUrl; String? get audioUrl; int? get audioDurationMs; double? get locationLat; double? get locationLng; String? get locationName; int? get replyToId; String get messageType;// text, image, audio, location
 bool get isRead; DateTime? get createdAt; DateTime? get editedAt;// Group chat enrichment
 String? get senderName; String? get senderAvatar;
/// Create a copy of DirectMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DirectMessageCopyWith<DirectMessage> get copyWith => _$DirectMessageCopyWithImpl<DirectMessage>(this as DirectMessage, _$identity);

  /// Serializes this DirectMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DirectMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.audioDurationMs, audioDurationMs) || other.audioDurationMs == audioDurationMs)&&(identical(other.locationLat, locationLat) || other.locationLat == locationLat)&&(identical(other.locationLng, locationLng) || other.locationLng == locationLng)&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderAvatar, senderAvatar) || other.senderAvatar == senderAvatar));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,senderId,body,imageUrl,audioUrl,audioDurationMs,locationLat,locationLng,locationName,replyToId,messageType,isRead,createdAt,editedAt,senderName,senderAvatar);

@override
String toString() {
  return 'DirectMessage(id: $id, conversationId: $conversationId, senderId: $senderId, body: $body, imageUrl: $imageUrl, audioUrl: $audioUrl, audioDurationMs: $audioDurationMs, locationLat: $locationLat, locationLng: $locationLng, locationName: $locationName, replyToId: $replyToId, messageType: $messageType, isRead: $isRead, createdAt: $createdAt, editedAt: $editedAt, senderName: $senderName, senderAvatar: $senderAvatar)';
}


}

/// @nodoc
abstract mixin class $DirectMessageCopyWith<$Res>  {
  factory $DirectMessageCopyWith(DirectMessage value, $Res Function(DirectMessage) _then) = _$DirectMessageCopyWithImpl;
@useResult
$Res call({
 int id, int conversationId, String senderId, String body, String? imageUrl, String? audioUrl, int? audioDurationMs, double? locationLat, double? locationLng, String? locationName, int? replyToId, String messageType, bool isRead, DateTime? createdAt, DateTime? editedAt, String? senderName, String? senderAvatar
});




}
/// @nodoc
class _$DirectMessageCopyWithImpl<$Res>
    implements $DirectMessageCopyWith<$Res> {
  _$DirectMessageCopyWithImpl(this._self, this._then);

  final DirectMessage _self;
  final $Res Function(DirectMessage) _then;

/// Create a copy of DirectMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conversationId = null,Object? senderId = null,Object? body = null,Object? imageUrl = freezed,Object? audioUrl = freezed,Object? audioDurationMs = freezed,Object? locationLat = freezed,Object? locationLng = freezed,Object? locationName = freezed,Object? replyToId = freezed,Object? messageType = null,Object? isRead = null,Object? createdAt = freezed,Object? editedAt = freezed,Object? senderName = freezed,Object? senderAvatar = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as int,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,audioDurationMs: freezed == audioDurationMs ? _self.audioDurationMs : audioDurationMs // ignore: cast_nullable_to_non_nullable
as int?,locationLat: freezed == locationLat ? _self.locationLat : locationLat // ignore: cast_nullable_to_non_nullable
as double?,locationLng: freezed == locationLng ? _self.locationLng : locationLng // ignore: cast_nullable_to_non_nullable
as double?,locationName: freezed == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String?,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as int?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,senderAvatar: freezed == senderAvatar ? _self.senderAvatar : senderAvatar // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DirectMessage].
extension DirectMessagePatterns on DirectMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DirectMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DirectMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DirectMessage value)  $default,){
final _that = this;
switch (_that) {
case _DirectMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DirectMessage value)?  $default,){
final _that = this;
switch (_that) {
case _DirectMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int conversationId,  String senderId,  String body,  String? imageUrl,  String? audioUrl,  int? audioDurationMs,  double? locationLat,  double? locationLng,  String? locationName,  int? replyToId,  String messageType,  bool isRead,  DateTime? createdAt,  DateTime? editedAt,  String? senderName,  String? senderAvatar)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DirectMessage() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.body,_that.imageUrl,_that.audioUrl,_that.audioDurationMs,_that.locationLat,_that.locationLng,_that.locationName,_that.replyToId,_that.messageType,_that.isRead,_that.createdAt,_that.editedAt,_that.senderName,_that.senderAvatar);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int conversationId,  String senderId,  String body,  String? imageUrl,  String? audioUrl,  int? audioDurationMs,  double? locationLat,  double? locationLng,  String? locationName,  int? replyToId,  String messageType,  bool isRead,  DateTime? createdAt,  DateTime? editedAt,  String? senderName,  String? senderAvatar)  $default,) {final _that = this;
switch (_that) {
case _DirectMessage():
return $default(_that.id,_that.conversationId,_that.senderId,_that.body,_that.imageUrl,_that.audioUrl,_that.audioDurationMs,_that.locationLat,_that.locationLng,_that.locationName,_that.replyToId,_that.messageType,_that.isRead,_that.createdAt,_that.editedAt,_that.senderName,_that.senderAvatar);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int conversationId,  String senderId,  String body,  String? imageUrl,  String? audioUrl,  int? audioDurationMs,  double? locationLat,  double? locationLng,  String? locationName,  int? replyToId,  String messageType,  bool isRead,  DateTime? createdAt,  DateTime? editedAt,  String? senderName,  String? senderAvatar)?  $default,) {final _that = this;
switch (_that) {
case _DirectMessage() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.body,_that.imageUrl,_that.audioUrl,_that.audioDurationMs,_that.locationLat,_that.locationLng,_that.locationName,_that.replyToId,_that.messageType,_that.isRead,_that.createdAt,_that.editedAt,_that.senderName,_that.senderAvatar);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DirectMessage implements DirectMessage {
  const _DirectMessage({required this.id, required this.conversationId, required this.senderId, required this.body, this.imageUrl, this.audioUrl, this.audioDurationMs, this.locationLat, this.locationLng, this.locationName, this.replyToId, this.messageType = 'text', this.isRead = false, this.createdAt, this.editedAt, this.senderName, this.senderAvatar});
  factory _DirectMessage.fromJson(Map<String, dynamic> json) => _$DirectMessageFromJson(json);

@override final  int id;
@override final  int conversationId;
@override final  String senderId;
@override final  String body;
@override final  String? imageUrl;
@override final  String? audioUrl;
@override final  int? audioDurationMs;
@override final  double? locationLat;
@override final  double? locationLng;
@override final  String? locationName;
@override final  int? replyToId;
@override@JsonKey() final  String messageType;
// text, image, audio, location
@override@JsonKey() final  bool isRead;
@override final  DateTime? createdAt;
@override final  DateTime? editedAt;
// Group chat enrichment
@override final  String? senderName;
@override final  String? senderAvatar;

/// Create a copy of DirectMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DirectMessageCopyWith<_DirectMessage> get copyWith => __$DirectMessageCopyWithImpl<_DirectMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DirectMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DirectMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.audioDurationMs, audioDurationMs) || other.audioDurationMs == audioDurationMs)&&(identical(other.locationLat, locationLat) || other.locationLat == locationLat)&&(identical(other.locationLng, locationLng) || other.locationLng == locationLng)&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderAvatar, senderAvatar) || other.senderAvatar == senderAvatar));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,senderId,body,imageUrl,audioUrl,audioDurationMs,locationLat,locationLng,locationName,replyToId,messageType,isRead,createdAt,editedAt,senderName,senderAvatar);

@override
String toString() {
  return 'DirectMessage(id: $id, conversationId: $conversationId, senderId: $senderId, body: $body, imageUrl: $imageUrl, audioUrl: $audioUrl, audioDurationMs: $audioDurationMs, locationLat: $locationLat, locationLng: $locationLng, locationName: $locationName, replyToId: $replyToId, messageType: $messageType, isRead: $isRead, createdAt: $createdAt, editedAt: $editedAt, senderName: $senderName, senderAvatar: $senderAvatar)';
}


}

/// @nodoc
abstract mixin class _$DirectMessageCopyWith<$Res> implements $DirectMessageCopyWith<$Res> {
  factory _$DirectMessageCopyWith(_DirectMessage value, $Res Function(_DirectMessage) _then) = __$DirectMessageCopyWithImpl;
@override @useResult
$Res call({
 int id, int conversationId, String senderId, String body, String? imageUrl, String? audioUrl, int? audioDurationMs, double? locationLat, double? locationLng, String? locationName, int? replyToId, String messageType, bool isRead, DateTime? createdAt, DateTime? editedAt, String? senderName, String? senderAvatar
});




}
/// @nodoc
class __$DirectMessageCopyWithImpl<$Res>
    implements _$DirectMessageCopyWith<$Res> {
  __$DirectMessageCopyWithImpl(this._self, this._then);

  final _DirectMessage _self;
  final $Res Function(_DirectMessage) _then;

/// Create a copy of DirectMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conversationId = null,Object? senderId = null,Object? body = null,Object? imageUrl = freezed,Object? audioUrl = freezed,Object? audioDurationMs = freezed,Object? locationLat = freezed,Object? locationLng = freezed,Object? locationName = freezed,Object? replyToId = freezed,Object? messageType = null,Object? isRead = null,Object? createdAt = freezed,Object? editedAt = freezed,Object? senderName = freezed,Object? senderAvatar = freezed,}) {
  return _then(_DirectMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as int,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,audioDurationMs: freezed == audioDurationMs ? _self.audioDurationMs : audioDurationMs // ignore: cast_nullable_to_non_nullable
as int?,locationLat: freezed == locationLat ? _self.locationLat : locationLat // ignore: cast_nullable_to_non_nullable
as double?,locationLng: freezed == locationLng ? _self.locationLng : locationLng // ignore: cast_nullable_to_non_nullable
as double?,locationName: freezed == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String?,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as int?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,senderAvatar: freezed == senderAvatar ? _self.senderAvatar : senderAvatar // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
