import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/direct_message.dart';
import '../../../services/geocoding_service.dart';
import '../../navigation/mapbox_ride_screen.dart';

/// Callback for offer actions in vehicle_offer messages.
/// [action] is 'accept', 'decline', or 'counter'.
/// [offerData] contains the parsed offer JSON.
typedef OfferActionCallback = void Function(String action, Map<String, dynamic> offerData);

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
    this.onDelete,
    this.onEdit,
    this.isGroupChat = false,
    this.onOfferAction,
  });

  final DirectMessage message;
  final bool isMe;
  final Color accentColor;
  final DirectMessage? replyToMessage;
  final String? otherUsername;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onImageTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isGroupChat;
  final OfferActionCallback? onOfferAction;

  @override
  Widget build(BuildContext context) {
    return Align(
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
        child: InkWell(
          onLongPress: () => _showMessageActions(context),
          splashColor: Colors.transparent,
          highlightColor: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          child: isGroupChat && !isMe
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

  void _showMessageActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTextMessage = message.messageType == 'text' || message.messageType == null;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Antworten
              if (onSwipeReply != null)
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: accentColor),
                  title: Text('Antworten', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSwipeReply?.call();
                  },
                ),
              // Kopieren (nur Text-Nachrichten)
              if (isTextMessage && message.body.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: accentColor),
                  title: Text('Kopieren', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.body));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kopiert'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              // Bearbeiten (nur eigene Text-Nachrichten)
              if (isMe && isTextMessage && onEdit != null)
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: accentColor),
                  title: Text('Bearbeiten', style: GoogleFonts.inter(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                ),
              // Löschen (nur eigene)
              if (isMe && onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: Text('Löschen', style: GoogleFonts.inter(fontSize: 15, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
            ],
          ),
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

    Widget bubble;
    if (type == 'vehicle_offer') {
      bubble = _buildOfferBubble(context);
    } else if (type == 'image') {
      bubble = _buildImageBubble(context);
    } else if (type == 'audio') {
      bubble = _buildAudioBubble(context);
    } else if (type == 'location') {
      bubble = _buildLocationBubble(context);
    } else {
      bubble = _buildTextBubble(context);
    }

    // Add ⋮ menu button for own messages
    if (isMe && (onDelete != null || onEdit != null)) {
      bubble = Stack(
        children: [
          bubble,
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _showMessageActions(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return bubble;
  }

  // ── Vehicle Offer Bubble (Kleinanzeigen-style) ──
  Widget _buildOfferBubble(BuildContext context) {
    Map<String, dynamic> offerData = {};
    try {
      offerData = json.decode(message.body) as Map<String, dynamic>;
    } catch (_) {
      // Fallback to text bubble if JSON parsing fails
      return _buildTextBubble(context);
    }

    final offerType = offerData['type'] as String? ?? 'offer';
    final vehicleName = offerData['vehicle_name'] as String? ?? '';
    final amount = (offerData['price'] as num?)?.toDouble() ?? (offerData['amount'] as num?)?.toDouble() ?? 0;
    final title = offerData['title'] as String? ?? '';
    final body = offerData['body'] as String? ?? '';

    // Icon + color based on offer type
    final (IconData icon, Color color, String label) = switch (offerType) {
      'like' => (Icons.favorite_rounded, Colors.red, 'Gefällt mir'),
      'offer' => (Icons.local_offer_rounded, accentColor, 'Angebot'),
      'counter' => (Icons.swap_horiz_rounded, Colors.orange, 'Gegenangebot'),
      'accepted' => (Icons.check_circle_rounded, Colors.green, 'Angenommen'),
      'declined' => (Icons.cancel_rounded, Colors.red, 'Abgelehnt'),
      _ => (Icons.local_offer_rounded, accentColor, 'Angebot'),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? accentColor.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon + label
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              const Spacer(),
              if (vehicleName.isNotEmpty)
                Flexible(
                  child: Text(vehicleName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11,
                      color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D))),
                ),
            ],
          ),

          // Amount (if not a like)
          if (offerType != 'like' && amount > 0) ...[
            const SizedBox(height: 8),
            Text('${amount.toStringAsFixed(2)} \u20ac',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],

          // Title / Body
          if (title.isNotEmpty && offerType == 'like') ...[
            const SizedBox(height: 4),
            Text(title,
              style: GoogleFonts.inter(fontSize: 13,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1A1A1A))),
          ],

          // Action buttons (only for incoming pending offers/counter-offers)
          if (!isMe && (offerType == 'offer' || offerType == 'counter') && onOfferAction != null) ...[
            const SizedBox(height: 12),
            // Annehmen button (full width)
            SizedBox(
              width: double.infinity,
              height: 34,
              child: OutlinedButton.icon(
                onPressed: () => onOfferAction?.call('accept', offerData),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: Text('Annehmen',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: () => onOfferAction?.call('counter', offerData),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text('Gegenangebot',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      onPressed: () => onOfferAction?.call('decline', offerData),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text('Nein danke',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Accepted: show body (PLZ info) + Navigate button
          if (offerType == 'accepted' && body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body,
              style: GoogleFonts.inter(fontSize: 13,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1A1A1A))),
          ],
          // Navigate button removed — navigation only available after contact data is sent

          // Timestamp
          const SizedBox(height: 4),
          _buildTimestamp(context),
        ],
      ),
    );
  }

  // ── Text Bubble ──
  Widget _buildTextBubble(BuildContext context) {
    final isContactData = message.body.contains('Meine Kontaktdaten:') && message.body.contains('📍');
    // Extract address from contact data for navigation
    String? contactAddress;
    if (isContactData) {
      final addrMatch = RegExp(r'📍\s*(.+)', multiLine: true).firstMatch(message.body);
      if (addrMatch != null) contactAddress = addrMatch.group(1)?.trim();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isContactData
          ? BoxDecoration(
              color: isMe
                  ? accentColor.withValues(alpha: 0.25)
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF0F5F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isMe ? 18 : 4),
                topRight: Radius.circular(isMe ? 4 : 18),
                bottomLeft: const Radius.circular(18),
                bottomRight: const Radius.circular(18),
              ),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.2),
            )
          : _bubbleDecoration(context),
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
          if (isContactData) ...[
            Row(
              children: [
                const Icon(Icons.contact_phone_rounded, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text('Kontaktdaten', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message.body,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isMe
                  ? Colors.white
                  : _receivedTextColor(context),
              height: 1.4,
            ),
          ),
          // Navigate button for contact data messages (only for receiver)
          if (isContactData && !isMe && contactAddress != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Geocode address and start our own navigation
                  try {
                    final results = await GeocodingService().searchPlace(contactAddress!, limit: 1);
                    if (results.isNotEmpty && context.mounted) {
                      final r = results.first;
                      context.push('/mapbox-nav', extra: {
                        'destLat': r.location.latitude,
                        'destLng': r.location.longitude,
                        'destName': contactAddress,
                      });
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse konnte nicht gefunden werden')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: Text('Zum Verkäufer navigieren',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          _buildTimestamp(context),
        ],
      ),
    );
  }

  // ── Image Bubble ──
  Widget _buildImageBubble(BuildContext context) {
    return Container(
      decoration: _bubbleDecoration(context),
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
                      : _receivedTextColor(context),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: _buildTimestamp(context),
          ),
        ],
      ),
    );
  }

  // ── Audio Bubble ──
  Widget _buildAudioBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _bubbleDecoration(context),
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
          _buildTimestamp(context),
        ],
      ),
    );
  }

  // ── Location Bubble ──
  Widget _buildLocationBubble(BuildContext context) {
    final lat = message.locationLat;
    final lng = message.locationLng;
    final name = message.locationName ?? message.body;

    return GestureDetector(
      onTap: () {
        if (lat != null && lng != null) {
          // POI auf unserer Karte öffnen (FlyTo + blinkender Ring)
          MapboxRideScreen.pendingPoiFlyTo.value = (
            lat: lat, lon: lng, name: name, type: '',
          );
          context.go('/map');
        }
      },
      child: Container(
        decoration: _bubbleDecoration(context),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 48,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.map_rounded, size: 14, color: Colors.red.withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text('Auf Karte zeigen',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                                color: Colors.red.withValues(alpha: 0.9)),
                            ),
                          ]),
                        ),
                      ],
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
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isMe
                            ? Colors.white
                            : _receivedTextColor(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Body text (Kategorie, Adresse)
            if (message.body.isNotEmpty && message.body != name)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Text(
                  message.body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: (isMe ? Colors.white : _receivedTextColor(context)).withValues(alpha: 0.7),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: _buildTimestamp(context),
            ),
          ],
        ),
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
  Widget _buildTimestamp([BuildContext? context]) {
    final isDark = context != null
        ? Theme.of(context).brightness == Brightness.dark
        : true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null)
          Text(
            'bearbeitet  ',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.5)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.35),
            ),
          ),
        Text(
          _formatTime(message.createdAt),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isMe
                ? Colors.white.withValues(alpha: 0.6)
                : isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.4),
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead
                ? Icons.done_all_rounded      // ✓✓ gelesen
                : Icons.done_rounded,          // ✓  gesendet / zugestellt
            size: 14,
            color: message.isRead
                ? const Color(0xFF4ADE80)      // grün = gelesen
                : message.isDelivered
                    ? const Color(0xFF4ADE80)  // grün = zugestellt
                    : Colors.white.withValues(alpha: 0.5), // grau = gesendet
          ),
        ],
      ],
    );
  }

  BoxDecoration _bubbleDecoration([BuildContext? context]) {
    final isDark = context != null
        ? Theme.of(context).brightness == Brightness.dark
        : true;
    return BoxDecoration(
      color: isMe
          ? accentColor
          : isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8E8ED),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMe ? 18 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 18),
      ),
    );
  }

  Color _receivedTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1A1A1A);
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
