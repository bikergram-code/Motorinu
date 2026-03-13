import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../domain/models/direct_message.dart';
import '../../providers/core/providers.dart';
import '../../providers/messages/chat_notifier.dart';
import '../../providers/messages/incoming_message_provider.dart';
import '../../providers/messages/messages_notifier.dart';
import '../../providers/messages/unread_messages_notifier.dart';
import '../../theme/app_theme.dart';
import 'widgets/attachment_picker.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/image_preview_page.dart';
import 'widgets/message_bubble.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  String? _currentUserId;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    // Cancel Android Auto notification for this conversation
    IncomingMessageBus.instance.cancelNotification(widget.conversationId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send text ──
  void _sendText(String body) {
    ref
        .read(chatNotifierProvider(widget.conversationId).notifier)
        .sendMessage(body);
    ref.read(messagesNotifierProvider.notifier).refresh();
    _scrollToBottom();
  }

  // ── Typing indicator ──
  void _onTypingChanged(bool isTyping) {
    ref
        .read(chatNotifierProvider(widget.conversationId).notifier)
        .setTyping(isTyping);
  }

  // ── Attachment actions ──
  void _showAttachmentPicker() {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    AttachmentPicker.show(
      context,
      accentColor: accentColor,
      onGallery: _pickGalleryImage,
      onCamera: _pickCameraImage,
      onLocation: _sendLocation,
    );
  }

  Future<void> _pickGalleryImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (image != null) _showImagePreview(image);
  }

  Future<void> _pickCameraImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (image != null) _showImagePreview(image);
  }

  void _showImagePreview(XFile image) {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          image: image,
          accentColor: accentColor,
          onSend: (img, caption) {
            ref
                .read(chatNotifierProvider(widget.conversationId).notifier)
                .sendImageMessage(img, caption: caption);
            ref.read(messagesNotifierProvider.notifier).refresh();
            _scrollToBottom();
          },
        ),
      ),
    );
  }

  Future<void> _sendLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Standort-Berechtigung verweigert')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final name =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      ref
          .read(chatNotifierProvider(widget.conversationId).notifier)
          .sendLocationMessage(position.latitude, position.longitude, name);
      ref.read(messagesNotifierProvider.notifier).refresh();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Standort konnte nicht ermittelt werden: $e')),
        );
      }
    }
  }

  // ── Voice recording ──
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _audioPath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _audioPath!,
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording(int durationMs) async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null && durationMs > 500) {
        ref
            .read(chatNotifierProvider(widget.conversationId).notifier)
            .sendAudioMessage(path, durationMs);
        ref.read(messagesNotifierProvider.notifier).refresh();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final chatState = ref.watch(chatNotifierProvider(widget.conversationId));

    // Auto-scroll when new messages arrive
    ref.listen(chatNotifierProvider(widget.conversationId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            // Refresh both the conversation list AND the global unread badge
            ref.read(messagesNotifierProvider.notifier).refresh();
            ref.read(unreadMessagesProvider.notifier).refresh();
            context.pop();
          },
          icon: Icon(Icons.arrow_back_rounded, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        ),
        title: chatState.isLoading
            ? Text(
                'Chat',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                  letterSpacing: -0.3,
                ),
              )
            : GestureDetector(
                onTap: () {
                  if (chatState.isGroupChat && chatState.groupId != null) {
                    context.push('/group/${chatState.groupId}');
                  } else if (chatState.otherUserId != null) {
                    context.push('/profile/${chatState.otherUserId}');
                  }
                },
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: chatState.isGroupChat || chatState.otherAvatarUrl == null
                            ? LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.6),
                                ],
                              )
                            : null,
                      ),
                      child: ClipOval(
                        child: chatState.isGroupChat
                            ? Center(
                                child: Icon(Icons.groups_rounded,
                                    size: 18, color: Colors.white),
                              )
                            : chatState.otherAvatarUrl != null &&
                                chatState.otherAvatarUrl!.isNotEmpty
                            ? Image.network(
                                chatState.otherAvatarUrl!,
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    (chatState.otherUsername ?? '?')[0]
                                        .toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  (chatState.otherUsername ?? '?')[0]
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chatState.isGroupChat
                                ? (chatState.groupName ?? 'Gruppe')
                                : (chatState.otherUsername ?? 'Chat'),
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (chatState.isOtherTyping)
                            Text(
                              'schreibt...',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : chatState.messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          final isMe = message.senderId == _currentUserId;
                          final showDate = index == 0 ||
                              _shouldShowDate(
                                chatState.messages[index - 1],
                                message,
                              );

                          // Find reply-to message
                          DirectMessage? replyToMsg;
                          if (message.replyToId != null) {
                            replyToMsg = ref
                                .read(chatNotifierProvider(
                                        widget.conversationId)
                                    .notifier)
                                .findMessageById(message.replyToId!);
                          }

                          return Column(
                            children: [
                              if (showDate) _buildDateDivider(message),
                              MessageBubble(
                                message: message,
                                isMe: isMe,
                                accentColor: accentColor,
                                replyToMessage: replyToMsg,
                                otherUsername: chatState.otherUsername,
                                isGroupChat: chatState.isGroupChat,
                                onSwipeReply: () {
                                  ref
                                      .read(chatNotifierProvider(
                                              widget.conversationId)
                                          .notifier)
                                      .setReplyTo(message);
                                },
                                onImageTap: message.imageUrl != null
                                    ? () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => FullImageViewer(
                                              imageUrl: message.imageUrl!,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // WhatsApp-style input bar
          ChatInputBar(
            accentColor: accentColor,
            onSendText: _sendText,
            onAttachmentTap: _showAttachmentPicker,
            onMicStart: _startRecording,
            onMicStop: _stopRecording,
            onTypingChanged: _onTypingChanged,
            replyTo: chatState.replyTo,
            otherUsername: chatState.otherUsername,
            isSending: chatState.isSending,
            onCancelReply: () {
              ref
                  .read(
                      chatNotifierProvider(widget.conversationId).notifier)
                  .clearReplyTo();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Schreibe die erste Nachricht!',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF6C757D)),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDate(DirectMessage prev, DirectMessage current) {
    if (prev.createdAt == null || current.createdAt == null) return false;
    return prev.createdAt!.day != current.createdAt!.day ||
        prev.createdAt!.month != current.createdAt!.month ||
        prev.createdAt!.year != current.createdAt!.year;
  }

  Widget _buildDateDivider(DirectMessage message) {
    final date = message.createdAt;
    if (date == null) return const SizedBox.shrink();

    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Heute';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Gestern';
    } else {
      label =
          '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
