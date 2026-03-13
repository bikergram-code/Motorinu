import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages a single LiveKit [Room] for live-streaming.
///
/// Call [connectAsHost] to broadcast (camera + mic) or
/// [connectAsViewer] to watch a stream. Always call [disconnect]
/// when leaving.
class LiveKitService {
  LiveKitService._();
  static final LiveKitService instance = LiveKitService._();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  // ── Public state ──────────────────────────────────────────────────────

  Room? get room => _room;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  /// Number of remote participants (viewers for the host).
  int get remoteParticipantCount => _room?.remoteParticipants.length ?? 0;

  /// Local camera track (for the broadcaster).
  VideoTrack? get localVideoTrack {
    final pubs = _room?.localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return null;
    final pub = pubs.firstWhere(
      (p) => p.kind == TrackType.VIDEO && !(p.source == TrackSource.screenShareVideo),
      orElse: () => pubs.first,
    );
    return pub.track as VideoTrack?;
  }

  /// Remote video track (for the viewer — the host's camera).
  VideoTrack? get remoteVideoTrack {
    if (_room == null) return null;
    for (final participant in _room!.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) {
          return pub.track as VideoTrack;
        }
      }
    }
    return null;
  }

  bool get isCameraEnabled =>
      _room?.localParticipant?.isCameraEnabled() ?? false;

  bool get isMicEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  // ── Callbacks ─────────────────────────────────────────────────────────

  /// Called when a remote video track becomes available (for viewers).
  VoidCallback? onRemoteTrackChanged;

  /// Called when connection state changes (reconnecting, disconnected, etc.)
  ValueChanged<ConnectionState>? onConnectionStateChanged;

  /// Called when the room is disconnected.
  VoidCallback? onDisconnected;

  /// Called when a participant joins (for viewer count updates).
  VoidCallback? onParticipantChanged;

  // ── Connect ───────────────────────────────────────────────────────────

  /// Connect as the host (broadcaster). Publishes camera + microphone.
  Future<void> connectAsHost(String sessionId) async {
    // Request permissions
    final granted = await _requestPermissions();
    if (!granted) {
      throw Exception('Kamera- und Mikrofon-Berechtigung erforderlich');
    }

    // Get token from Supabase Edge Function
    final tokenData = await _requestToken(sessionId, isHost: true);

    // Create and connect room
    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultVideoPublishOptions: VideoPublishOptions(
          videoCodec: 'vp8',
          simulcast: true,
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          dtx: true, // Discontinuous transmission — save bandwidth when silent
        ),
      ),
    );

    _setupListener();

    await _room!.connect(
      tokenData['url'] as String,
      tokenData['token'] as String,
    );

    // Start publishing camera + mic
    try {
      await _room!.localParticipant?.setCameraEnabled(true);
    } catch (e) {
      debugPrint('[LiveKit] Camera publish error: $e');
    }

    try {
      await _room!.localParticipant?.setMicrophoneEnabled(true);
    } catch (e) {
      debugPrint('[LiveKit] Mic publish error: $e');
    }
  }

  /// Connect as a viewer. Subscribes to the host's tracks.
  Future<void> connectAsViewer(String sessionId) async {
    final tokenData = await _requestToken(sessionId, isHost: false);

    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    _setupListener();

    await _room!.connect(
      tokenData['url'] as String,
      tokenData['token'] as String,
    );
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    _listener?.dispose();
    _listener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
  }

  // ── Controls (for broadcaster) ────────────────────────────────────────

  Future<void> toggleCamera() async {
    final enabled = isCameraEnabled;
    await _room?.localParticipant?.setCameraEnabled(!enabled);
  }

  Future<void> toggleMic() async {
    final enabled = isMicEnabled;
    await _room?.localParticipant?.setMicrophoneEnabled(!enabled);
  }

  Future<void> switchCamera() async {
    final pubs = _room?.localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return;

    for (final pub in pubs) {
      final track = pub.track;
      if (track is LocalVideoTrack) {
        try {
          final currentPos =
              (track.currentOptions as CameraCaptureOptions).cameraPosition;
          await track.setCameraPosition(
            currentPos == CameraPosition.front
                ? CameraPosition.back
                : CameraPosition.front,
          );
        } catch (e) {
          debugPrint('[LiveKit] Switch camera error: $e');
        }
        break;
      }
    }
  }

  // ── Group Call (multi-party voice/video) ──────────────────────────────

  /// Connect to a group voice/video call. All participants can publish.
  Future<void> connectToGroupCall(int groupId, {bool withVideo = false}) async {
    final granted = await _requestPermissions();
    if (!granted) {
      throw Exception('Mikrofon-Berechtigung erforderlich');
    }

    final roomName = 'group-call-$groupId';
    final tokenData = await _requestToken(roomName, isHost: true);

    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultVideoPublishOptions: VideoPublishOptions(
          videoCodec: 'vp8',
          simulcast: true,
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          dtx: true,
        ),
      ),
    );

    _setupListener();

    await _room!.connect(
      tokenData['url'] as String,
      tokenData['token'] as String,
    );

    // Always enable mic for group calls
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(true);
    } catch (e) {
      debugPrint('[LiveKit] Group call mic error: $e');
    }

    // Optionally enable camera
    if (withVideo) {
      try {
        await _room!.localParticipant?.setCameraEnabled(true);
      } catch (e) {
        debugPrint('[LiveKit] Group call camera error: $e');
      }
    }
  }

  /// Get all remote participants in the current room.
  Map<String, RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants ?? {};

  /// Get all remote video tracks (for group video grid).
  List<MapEntry<String, VideoTrack>> get remoteVideoTracks {
    final result = <MapEntry<String, VideoTrack>>[];
    if (_room == null) return result;
    for (final entry in _room!.remoteParticipants.entries) {
      for (final pub in entry.value.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) {
          result.add(MapEntry(entry.key, pub.track as VideoTrack));
        }
      }
    }
    return result;
  }

  /// Check if a specific participant is speaking (audio level > threshold).
  bool isParticipantSpeaking(String participantId) {
    final p = _room?.remoteParticipants[participantId];
    return p?.isSpeaking ?? false;
  }

  // ── Private helpers ───────────────────────────────────────────────────

  void _setupListener() {
    _listener = _room!.createListener();

    _listener!
      ..on<RoomDisconnectedEvent>((_) {
        debugPrint('[LiveKit] Disconnected');
        onDisconnected?.call();
      })
      ..on<RoomReconnectingEvent>((_) {
        debugPrint('[LiveKit] Reconnecting...');
        onConnectionStateChanged?.call(ConnectionState.reconnecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        debugPrint('[LiveKit] Reconnected');
        onConnectionStateChanged?.call(ConnectionState.connected);
      })
      ..on<TrackSubscribedEvent>((event) {
        debugPrint('[LiveKit] Track subscribed: ${event.track.kind}');
        if (event.track is VideoTrack) {
          onRemoteTrackChanged?.call();
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        debugPrint('[LiveKit] Track unsubscribed: ${event.track.kind}');
        if (event.track is VideoTrack) {
          onRemoteTrackChanged?.call();
        }
      })
      ..on<ParticipantConnectedEvent>((_) {
        onParticipantChanged?.call();
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        onParticipantChanged?.call();
      })
      ..on<LocalTrackPublishedEvent>((event) {
        debugPrint('[LiveKit] Local track published: ${event.publication.kind}');
        if (event.publication.kind == TrackType.VIDEO) {
          onRemoteTrackChanged?.call(); // Triggers UI rebuild for local preview
        }
      });
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    return (statuses[Permission.camera]?.isGranted ?? false) &&
        (statuses[Permission.microphone]?.isGranted ?? false);
  }

  // ── LiveKit credentials ──────────────────────────────────────────────
  // TODO: Move to Edge Function for production (API secret should not be in client)
  static const String _livekitUrl = 'wss://motorinu-cb8w94t3.livekit.cloud';
  static const String _livekitApiKey = 'APIpG3wjuC4vgvr';
  static const String _livekitApiSecret = 'LnvQ6RA4P47nbYEhO1ToLpHptDSHEffZHnbn6b4b1qR';

  Future<Map<String, dynamic>> _requestToken(
    String sessionId, {
    required bool isHost,
  }) async {
    // Get current user identity
    final user = Supabase.instance.client.auth.currentUser;
    final identity = user?.id ?? 'anonymous';
    final metadata = user?.userMetadata;
    final displayName = metadata?['display_name'] as String? ??
        metadata?['username'] as String? ??
        'User';

    // Generate LiveKit JWT locally
    final token = _generateLiveKitJwt(
      apiKey: _livekitApiKey,
      apiSecret: _livekitApiSecret,
      roomName: sessionId,
      identity: identity,
      name: displayName,
      canPublish: isHost,
    );

    debugPrint('[LiveKit] Token generated for room=$sessionId, isHost=$isHost, identity=$identity');

    return {
      'token': token,
      'url': _livekitUrl,
    };
  }

  /// Generates a LiveKit-compatible JWT using HMAC-SHA256.
  String _generateLiveKitJwt({
    required String apiKey,
    required String apiSecret,
    required String roomName,
    required String identity,
    required String name,
    required bool canPublish,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + (6 * 3600); // 6 hours

    // LiveKit JWT header
    final header = {'alg': 'HS256', 'typ': 'JWT'};

    // LiveKit JWT payload with video grant
    final payload = {
      'iss': apiKey,
      'sub': identity,
      'name': name,
      'iat': now,
      'nbf': now,
      'exp': exp,
      'jti': identity,
      'video': {
        'room': roomName,
        'roomJoin': true,
        'canPublish': canPublish,
        'canSubscribe': true,
        'canPublishData': true,
      },
    };

    // Base64url encode
    String base64UrlEncode(List<int> bytes) {
      return base64Url.encode(bytes).replaceAll('=', '');
    }

    final headerB64 = base64UrlEncode(utf8.encode(jsonEncode(header)));
    final payloadB64 = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$headerB64.$payloadB64';

    // HMAC-SHA256 signature
    final hmac = Hmac(sha256, utf8.encode(apiSecret));
    final digest = hmac.convert(utf8.encode(signingInput));
    final signatureB64 = base64UrlEncode(digest.bytes);

    return '$signingInput.$signatureB64';
  }
}
