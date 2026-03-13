import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/direct_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.accentColor,
    this.replyToMessage,
    this.otherUsername,
    this.onSwipeReply,
    this.onImageTap,
    this.isGroupChat = false,
  });

  final DirectMessage message;
  final bool isMe;
  final Color accentColor;
  final DirectMessage? replyToMessage;
  final String? otherUsername;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onImageTap;
  final bool isGroupChat;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('swipe_${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipeReply?.call();
        return false; // Don't actually dismiss
      },
      background: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.reply_rounded,
              color: Colors.white.withValues(alpha: 0.5), size: 24),
        ),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            top: 3,
            bottom: 3,
            left: isMe ? 48 : (isGroupChat ? 0 : 0),
            right: isMe ? 0 : 48,
          ),
          child: isGroupChat && !isMe
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sender mini-avatar
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      child: _buildSenderAvatar(),
                    ),
                    Flexible(child: _buildBubbleContent(context)),
                  ],
                )
              : _buildBubbleContent(context),
        ),
      ),
    );
  }

  Widget _buildSenderAvatar() {
    final name = message.senderName ?? '?';
    final avatar = message.senderAvatar;
    return CircleAvatar(
      radius: 14,
      backgroundImage:
          avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
      backgroundColor: accentColor.withValues(alpha: 0.2),
      child: avatar == null || avatar.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            )
          : null,
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    final type = message.messageType;

    if (type == 'image') return _buildImageBubble(context);
    if (type == 'audio') return _buildAudioBubble(context);
    if (type == 'location') return _buildLocationBubble(context);
    return _buildTextBubble(context);
  }

  // ── Text Bubble ──
  Widget _buildTextBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _bubbleDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGroupChat && !isMe && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.senderName!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor.withValues(alpha: 0.9),
                ),
              ),
            ),
          if (replyToMessage != null) _buildReplyQuote(),
          Text(
            message.body,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isMe
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          _buildTimestamp(),
        ],
      ),
    );
  }

  // ── Image Bubble ──
  Widget _buildImageBubble(BuildContext context) {
    return Container(
      decoration: _bubbleDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _buildReplyQuote(),
            ),
          GestureDetector(
            onTap: onImageTap,
            child: ClipRRect(
              borderRadius: replyToMessage != null
                  ? BorderRadius.zero
                  : BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 18 : 4),
                      topRight: Radius.circular(isMe ? 4 : 18),
                    ),
              child: CachedNetworkImage(
                imageUrl: message.imageUrl ?? '',
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: Colors.white.withValues(alpha: 0.06),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.white.withValues(alpha: 0.06),
                  child: const Icon(Icons.broken_image_rounded,
                      color: Colors.white24, size: 48),
                ),
              ),
            ),
          ),
          if (message.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                message.body,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isMe
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: _buildTimestamp(),
          ),
        ],
      ),
    );
  }

  // ── Audio Bubble ──
  Widget _buildAudioBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _bubbleDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToMessage != null) _buildReplyQuote(),
          _AudioPlayer(
            audioUrl: message.audioUrl ?? '',
            durationMs: message.audioDurationMs ?? 0,
            isMe: isMe,
            accentColor: accentColor,
          ),
          const SizedBox(height: 4),
          _buildTimestamp(),
        ],
      ),
    );
  }

  // ── Location Bubble ──
  Widget _buildLocationBubble(BuildContext context) {
    final lat = message.locationLat;
    final lng = message.locationLng;

    return Container(
      decoration: _bubbleDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _buildReplyQuote(),
            ),
          // Map preview placeholder
          Container(
            height: 140,
            color: Colors.white.withValues(alpha: 0.06),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 48,
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lat != null && lng != null
                          ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
                          : 'Standort',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: Colors.red.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message.locationName ?? message.body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isMe
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _buildTimestamp(),
          ),
        ],
      ),
    );
  }

  // ── Reply Quote ──
  Widget _buildReplyQuote() {
    final reply = replyToMessage;
    if (reply == null) return const SizedBox.shrink();

    final replyName =
        reply.senderId == message.senderId ? 'Du' : (otherUsername ?? 'User');
    String replyText = reply.body;
    if (reply.messageType == 'image') {
      replyText = replyText.isEmpty ? 'Bild' : replyText;
    }
    if (reply.messageType == 'audio') replyText = 'Sprachnachricht';
    if (reply.messageType == 'location') {
      replyText = reply.locationName ?? 'Standort';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accentColor,
            width: 3,
          ),
        ),
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyName,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
          Text(
            replyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timestamp + Checkmarks ──
  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isMe
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: message.isRead
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ],
    );
  }

  BoxDecoration _bubbleDecoration() {
    return BoxDecoration(
      color: isMe ? accentColor : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMe ? 18 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 18),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ── Audio Player Widget ──
class _AudioPlayer extends StatefulWidget {
  const _AudioPlayer({
    required this.audioUrl,
    required this.durationMs,
    required this.isMe,
    required this.accentColor,
  });

  final String audioUrl;
  final int durationMs;
  final bool isMe;
  final Color accentColor;

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs);

    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_position == Duration.zero) {
        await _player.play(UrlSource(widget.audioUrl));
      } else {
        await _player.resume();
      }
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs =
        _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final progress = _position.inMilliseconds / totalMs;

    final btnColor = widget.isMe
        ? Colors.white
        : widget.accentColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: btnColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              _isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: btnColor,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(btnColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(
                    _isPlaying ? _position : _duration),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
