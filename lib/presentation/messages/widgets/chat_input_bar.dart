import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'
    as emoji_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/direct_message.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.accentColor,
    required this.onSendText,
    required this.onAttachmentTap,
    required this.onMicStart,
    required this.onMicStop,
    required this.onTypingChanged,
    this.replyTo,
    this.onCancelReply,
    this.otherUsername,
    this.isSending = false,
  });

  final Color accentColor;
  final ValueChanged<String> onSendText;
  final VoidCallback onAttachmentTap;
  final VoidCallback onMicStart;
  final ValueChanged<int> onMicStop; // duration in ms
  final ValueChanged<bool> onTypingChanged;
  final DirectMessage? replyTo;
  final VoidCallback? onCancelReply;
  final String? otherUsername;
  final bool isSending;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _showEmoji = false;
  bool _isRecording = false;
  DateTime? _recordStart;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
      // Typing indicator
      if (hasText) {
        widget.onTypingChanged(true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          widget.onTypingChanged(false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
    setState(() => _hasText = false);
    widget.onTypingChanged(false);
  }

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      if (_showEmoji) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _startRecording() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _recordStart = DateTime.now();
    });
    widget.onMicStart();
  }

  void _stopRecording() {
    final duration = _recordStart != null
        ? DateTime.now().difference(_recordStart!).inMilliseconds
        : 0;
    setState(() => _isRecording = false);
    if (duration > 500) {
      widget.onMicStop(duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply-to preview
        if (widget.replyTo != null) _buildReplyPreview(),

        // Input row
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE0E0E0),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: _isRecording
                  ? _buildRecordingBar()
                  : _buildInputRow(),
            ),
          ),
        ),

        // Emoji picker
        if (_showEmoji)
          SizedBox(
            height: 280,
            child: emoji_picker.EmojiPicker(
              onEmojiSelected: (_, emoji) {
                _controller.text += emoji.emoji;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              },
              config: emoji_picker.Config(
                height: 280,
                emojiViewConfig: const emoji_picker.EmojiViewConfig(
                  backgroundColor: Color(0xFF0D0D0D),
                  columns: 8,
                  emojiSizeMax: 28,
                ),
                categoryViewConfig: const emoji_picker.CategoryViewConfig(
                  backgroundColor: Color(0xFF0D0D0D),
                  indicatorColor: Colors.white24,
                  iconColor: Colors.white30,
                  iconColorSelected: Colors.white,
                  dividerColor: Colors.transparent,
                ),
                searchViewConfig: const emoji_picker.SearchViewConfig(
                  backgroundColor: Color(0xFF0D0D0D),
                  buttonIconColor: Colors.white54,
                  hintText: 'Suche...',
                ),
                bottomActionBarConfig:
                    const emoji_picker.BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment button
        IconButton(
          onPressed: widget.onAttachmentTap,
          icon: Icon(
            Icons.add_rounded,
            color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF9E9E9E),
            size: 26,
          ),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        ),

        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onTap: () {
                      if (_showEmoji) setState(() => _showEmoji = false);
                    },
                    decoration: InputDecoration(
                      hintText: 'Nachricht...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF9E9E9E),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                // Emoji button
                IconButton(
                  onPressed: _toggleEmoji,
                  icon: Icon(
                    _showEmoji
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_outlined,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF9E9E9E),
                    size: 22,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Send or Mic button
        if (_hasText || widget.isSending)
          GestureDetector(
            onTap: widget.isSending ? null : _send,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.accentColor,
                shape: BoxShape.circle,
              ),
              child: widget.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          )
        else
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                color: widget.accentColor,
                size: 22,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        // Red pulsing dot
        _RecordingDot(color: Colors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Aufnahme...',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          'Loslassen zum Senden',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.red, size: 22),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    final reply = widget.replyTo!;
    String replyText = reply.body;
    if (reply.messageType == 'image') {
      replyText = replyText.isEmpty ? 'Bild' : replyText;
    }
    if (reply.messageType == 'audio') replyText = 'Sprachnachricht';
    if (reply.messageType == 'location') {
      replyText = reply.locationName ?? 'Standort';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
          left: BorderSide(
            color: widget.accentColor,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUsername ?? 'User',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
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
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 20),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  const _RecordingDot({required this.color});
  final Color color;

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.4 + _controller.value * 0.6),
        ),
      ),
    );
  }
}
