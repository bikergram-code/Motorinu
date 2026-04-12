import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/voice_recorder_helper.dart' as voice;
import '../../services/vosk_wake_word_service.dart';

import '../../core/community.dart';
import '../widgets/online_status_avatar.dart';
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

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  String? _currentUserId;
  String? _audioPath;

  /// Track which conversations already showed the match heart rain this session
  static final _shownMatchRain = <int>{};

  bool _voskWasListening = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    WidgetsBinding.instance.addObserver(this);
    // Pause Vosk so Gboard voice input can use the microphone
    if (VoskWakeWordService.instance.isListening) {
      _voskWasListening = true;
      VoskWakeWordService.instance.stopListening();
      debugPrint('[Chat] Vosk paused for chat');
    }
    // Cancel Android Auto notification for this conversation
    IncomingMessageBus.instance.cancelNotification(widget.conversationId);
    // Check if this chat is from a recent match → heart rain
    _checkRecentMatch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recover from dropped Realtime (Samsung Battery-Manager pauses WebSockets)
      ref
          .read(chatNotifierProvider(widget.conversationId).notifier)
          .reconnect();
    }
  }

  Future<void> _checkRecentMatch() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;
      final sb = Supabase.instance.client;
      final match = await sb
          .from('matches')
          .select('id, created_at')
          .eq('conversation_id', widget.conversationId)
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (match == null || !mounted) return;
      final createdAt = DateTime.tryParse(match['created_at'] as String? ?? '');
      if (createdAt == null) return;
      // Show heart rain if match was within the last 5 minutes (only once per session)
      if (DateTime.now().toUtc().difference(createdAt).inMinutes <= 5 &&
          !_shownMatchRain.contains(widget.conversationId)) {
        _shownMatchRain.add(widget.conversationId);
        _showMatchHeartRain();
      }
    } catch (_) {}
  }

  void _showEditDialog(DirectMessage message) {
    final controller = TextEditingController(text: message.body);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text('Nachricht bearbeiten',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Nachricht...',
            hintStyle: GoogleFonts.inter(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen',
                style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != message.body) {
                ref.read(chatNotifierProvider(widget.conversationId).notifier)
                    .editMessage(message.id, newText);
              }
              Navigator.pop(ctx);
            },
            child: Text('Speichern',
                style: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(DirectMessage message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : Colors.white,
        title: const Text('Nachricht löschen?'),
        content: const Text('Diese Nachricht wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatNotifierProvider(widget.conversationId).notifier)
                  .deleteMessage(message.id);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Handle offer actions from vehicle_offer messages ──
  void _handleOfferAction(String action, Map<String, dynamic> offerData) async {
    final vehicleId = offerData['vehicle_id'] as int? ?? 0;
    final vehicleName = offerData['vehicle_name'] as String? ?? '';
    final amount = (offerData['amount'] as num?)?.toDouble() ?? 0;
    final ownerId = offerData['owner_id'] as String? ?? '';
    final offerId = offerData['offer_id'] as int? ?? 0;
    final community = ref.read(communityProvider)?.name;
    final accentColor = ref.read(communityProvider)?.accentColor ?? AppTheme.accentDark;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final notifRepo = ref.read(notificationRepositoryProvider);
    // Figure out who to notify — the OTHER user in this conversation
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final targetId = ownerId == myId ? (offerData['sender_id'] as String? ?? '') : ownerId;

    if (action == 'accept') {
      // Accept the offer
      final repo = ref.read(vehicleRepositoryProvider);
      if (offerId > 0) {
        repo.acceptOffer(offerId);
      }
      final msgRepo = ref.read(messageRepositoryProvider);
      final jsonBody = '{"type":"accepted","vehicle_id":$vehicleId,"vehicle_name":"$vehicleName","owner_id":"$ownerId","amount":$amount,"offer_id":$offerId,"title":"Angebot angenommen","body":"Angebot angenommen!"}';
      msgRepo.sendMessage(widget.conversationId, jsonBody, messageType: 'vehicle_offer');

      // Bell notification
      if (targetId.isNotEmpty) {
        notifRepo.createNotification(
          targetUserId: targetId,
          type: 'vehicle_offer',
          title: '✅ Angebot angenommen!',
          body: '$vehicleName für ${amount.toStringAsFixed(0)} €',
          community: community,
        );
      }

      // Post to feed for followers — include vehicle image
      final supabase = Supabase.instance.client;
      if (myId.isNotEmpty) {
        try {
          // Fetch vehicle image from DB
          String? vehicleImageUrl;
          if (vehicleId > 0) {
            final vData = await supabase.from('vehicles').select('image_url').eq('id', vehicleId).maybeSingle();
            vehicleImageUrl = vData?['image_url'] as String?;
          }
          await supabase.from('posts').insert({
            'user_id': myId,
            'body': '🎉 $vehicleName wurde erfolgreich verkauft! 🏍️💨',
            if (vehicleImageUrl != null) 'image_url': vehicleImageUrl,
            'community': community ?? 'bikergram',
          });
        } catch (_) {}
      }

      // Show confetti celebration dialog
      _showSaleConfetti(vehicleName, amount);
    } else if (action == 'decline') {
      final repo = ref.read(vehicleRepositoryProvider);
      if (offerId > 0) {
        repo.declineOffer(offerId);
      }
      final msgRepo = ref.read(messageRepositoryProvider);
      final jsonBody = '{"type":"declined","vehicle_id":$vehicleId,"vehicle_name":"$vehicleName","owner_id":"$ownerId","amount":$amount,"offer_id":$offerId,"title":"Angebot abgelehnt","body":"Nein danke."}';
      msgRepo.sendMessage(widget.conversationId, jsonBody, messageType: 'vehicle_offer');

      // Bell notification
      if (targetId.isNotEmpty) {
        notifRepo.createNotification(
          targetUserId: targetId,
          type: 'vehicle_offer',
          title: '❌ Angebot abgelehnt',
          body: '$vehicleName – ${amount.toStringAsFixed(0)} €',
          community: community,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Angebot abgelehnt')),
      );
    } else if (action == 'counter') {
      // Show counter-offer dialog
      _showCounterOfferDialog(offerData, accentColor, isDark);
    }
  }

  // ── Seller confetti: "Du hast verkauft!" + Kontaktdaten senden ──
  void _showSaleConfetti(String vehicleName, double amount) {
    final confettiCtrl = ConfettiController(duration: const Duration(seconds: 8));
    confettiCtrl.play();
    final amountStr = amount.toStringAsFixed(0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Stack(
        children: [
          AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('🎉 Herzlichen Glückwunsch!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏍️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Du hast dein Fahrzeug erfolgreich verkauft!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(vehicleName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$amountStr €',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green)),
              ],
            ),
            actions: [
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        confettiCtrl.dispose();
                        _showSendContactSheet();
                      },
                      icon: const Icon(Icons.contact_phone_rounded, size: 18),
                      label: Text('Kontaktdaten senden', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () { Navigator.pop(ctx); confettiCtrl.dispose(); },
                    child: Text('Super! 🎉', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: true,
              numberOfParticles: 50,
              maxBlastForce: 30,
              minBlastForce: 8,
              emissionFrequency: 0.08,
              gravity: 0.15,
              colors: const [Colors.green, Colors.orange, Colors.red, Colors.blue, Colors.yellow, Colors.purple, Colors.pink, Colors.teal],
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirection: -1.0,
              shouldLoop: true,
              numberOfParticles: 20,
              maxBlastForce: 25,
              minBlastForce: 5,
              emissionFrequency: 0.06,
              gravity: 0.1,
              colors: const [Colors.amber, Colors.greenAccent, Colors.deepOrange, Colors.lightBlue, Colors.pinkAccent],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirection: -2.1,
              shouldLoop: true,
              numberOfParticles: 20,
              maxBlastForce: 25,
              minBlastForce: 5,
              emissionFrequency: 0.06,
              gravity: 0.1,
              colors: const [Colors.lime, Colors.cyan, Colors.redAccent, Colors.indigoAccent, Colors.orangeAccent],
            ),
          ),
        ],
      ),
    ).then((_) { try { confettiCtrl.dispose(); } catch (_) {} });
  }

  // ── Seller sends contact info to buyer ──
  void _showSendContactSheet() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    // Pre-fill PLZ from profile
    String prefillPlz = '';
    if (userId != null) {
      try {
        final profile = await supabase.from('profiles').select('postal_code').eq('id', userId).maybeSingle();
        prefillPlz = (profile?['postal_code'] as String?) ?? '';
      } catch (_) {}
    }
    if (!mounted) return;
    final addrCtrl = TextEditingController(text: prefillPlz.isNotEmpty ? '$prefillPlz ' : '');
    final phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = ref.read(communityProvider)?.accentColor ?? AppTheme.accentDark;
    final community = ref.read(communityProvider)?.name;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kontaktdaten senden',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Adresse (Straße, PLZ, Ort)',
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefonnummer',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final parts = <String>[];
                      if (addrCtrl.text.trim().isNotEmpty) parts.add('📍 ${addrCtrl.text.trim()}');
                      if (phoneCtrl.text.trim().isNotEmpty) parts.add('📞 ${phoneCtrl.text.trim()}');
                      if (parts.isNotEmpty) {
                        final msg = 'Meine Kontaktdaten:\n${parts.join('\n')}';
                        ref.read(messageRepositoryProvider).sendMessage(widget.conversationId, msg);
                        // Also send bell notification to buyer
                        final chatState = ref.read(chatNotifierProvider(widget.conversationId));
                        final otherUserId = chatState.otherUserId;
                        if (otherUserId != null && otherUserId.isNotEmpty) {
                          ref.read(notificationRepositoryProvider).createNotification(
                            targetUserId: otherUserId,
                            type: 'vehicle_offer',
                            title: '📬 Kontaktdaten erhalten',
                            body: 'Der Verkäufer hat dir seine Adresse und Telefonnummer gesendet.',
                            community: community,
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('Senden', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Buyer confetti: "Du hast gekauft!" ──
  void _showBuyerConfetti(String vehicleName, double amount) {
    final confettiCtrl = ConfettiController(duration: const Duration(seconds: 8));
    confettiCtrl.play();
    final amountStr = amount.toStringAsFixed(0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Stack(
        children: [
          AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('🎉 Herzlichen Glückwunsch!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏍️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Du hast das Fahrzeug erfolgreich gekauft!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(vehicleName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$amountStr €',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green)),
              ],
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () { Navigator.pop(ctx); confettiCtrl.dispose(); },
                  child: Text('Super! 🎉', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: true,
              numberOfParticles: 50,
              maxBlastForce: 30,
              minBlastForce: 8,
              emissionFrequency: 0.08,
              gravity: 0.15,
              colors: const [Colors.green, Colors.orange, Colors.red, Colors.blue, Colors.yellow, Colors.purple, Colors.pink, Colors.teal],
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirection: -1.0,
              shouldLoop: true,
              numberOfParticles: 20,
              maxBlastForce: 25,
              minBlastForce: 5,
              emissionFrequency: 0.06,
              gravity: 0.1,
              colors: const [Colors.amber, Colors.greenAccent, Colors.deepOrange, Colors.lightBlue, Colors.pinkAccent],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirection: -2.1,
              shouldLoop: true,
              numberOfParticles: 20,
              maxBlastForce: 25,
              minBlastForce: 5,
              emissionFrequency: 0.06,
              gravity: 0.1,
              colors: const [Colors.lime, Colors.cyan, Colors.redAccent, Colors.indigoAccent, Colors.orangeAccent],
            ),
          ),
        ],
      ),
    ).then((_) { try { confettiCtrl.dispose(); } catch (_) {} });
  }

  /// Heart-shaped particle path for match celebrations
  Path _heartPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w / 2, h * 0.35);
    path.cubicTo(w * 0.15, 0, 0, h * 0.4, w / 2, h);
    path.moveTo(w / 2, h * 0.35);
    path.cubicTo(w * 0.85, 0, w, h * 0.4, w / 2, h);
    path.close();
    return path;
  }

  static const _heartColors = [
    Color(0xFFE91E63), Color(0xFFF44336), Color(0xFFFF4081),
    Color(0xFFFF1744), Color(0xFFE040FB), Color(0xFFFF6090),
    Color(0xFFD50000), Color(0xFFFF80AB),
  ];

  void _showMatchHeartRain() {
    final confettiCtrl = ConfettiController(duration: const Duration(seconds: 12));
    confettiCtrl.play();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msgCtrl = TextEditingController();

    void sendEmoji(String text, BuildContext ctx) async {
      try {
        await ref.read(messageRepositoryProvider).sendMessage(widget.conversationId, text);
        if (ctx.mounted) Navigator.pop(ctx);
        try { confettiCtrl.dispose(); } catch (_) {}
      } catch (e) {
        debugPrint('[Match] Send error: $e');
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Stack(
        children: [
          AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text('💕 Es ist ein Match!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.pinkAccent)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🥰', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('Ihr mögt euch beide!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Sende eine Nachricht oder ein Herz 💌',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
                  const SizedBox(height: 14),
                  Text('Schnell-Herzen', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final emoji in ['🌹', '💕', '💐', '😘', '🥰', '❤️‍🔥', '💋', '🌸', '💖', '😍', '🫶', '🌷'])
                        GestureDetector(
                          onTap: () {
                            final text = msgCtrl.text;
                            final sel = msgCtrl.selection;
                            final pos = sel.isValid ? sel.baseOffset : text.length;
                            msgCtrl.text = text.substring(0, pos) + emoji + text.substring(pos);
                            msgCtrl.selection = TextSelection.collapsed(offset: pos + emoji.length);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: msgCtrl,
                          style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Hey, schön dich zu sehen! 💕',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white30 : Colors.black26),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) sendEmoji(text.trim(), ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final text = msgCtrl.text.trim();
                          if (text.isNotEmpty) sendEmoji(text, ctx);
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () { Navigator.pop(ctx); try { confettiCtrl.dispose(); } catch (_) {} },
                      child: Text('Später', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                  ),
                ],
              ),
            ),
            actions: const [],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: true,
              numberOfParticles: 50,
              maxBlastForce: 15,
              minBlastForce: 5,
              emissionFrequency: 0.06,
              gravity: 0.15,
              createParticlePath: _heartPath,
              colors: _heartColors,
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirection: -1.0,
              shouldLoop: true,
              numberOfParticles: 25,
              maxBlastForce: 12,
              minBlastForce: 4,
              emissionFrequency: 0.05,
              gravity: 0.12,
              createParticlePath: _heartPath,
              colors: _heartColors,
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: confettiCtrl,
              blastDirection: -2.1,
              shouldLoop: true,
              numberOfParticles: 25,
              maxBlastForce: 12,
              minBlastForce: 4,
              emissionFrequency: 0.05,
              gravity: 0.12,
              createParticlePath: _heartPath,
              colors: _heartColors,
            ),
          ),
        ],
      ),
    ).then((_) { try { confettiCtrl.dispose(); } catch (_) {} });
  }

  void _showCounterOfferDialog(Map<String, dynamic> offerData, Color accentColor, bool isDark) {
    final vehicleId = offerData['vehicle_id'] as int? ?? 0;
    final vehicleName = offerData['vehicle_name'] as String? ?? '';
    final amount = (offerData['amount'] as num?)?.toDouble() ?? 0;
    final ownerId = offerData['owner_id'] as String? ?? '';
    final offerId = offerData['offer_id'] as int? ?? 0;
    final amountCtrl = TextEditingController(text: amount.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Gegenangebot', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text('$vehicleName \u2022 Vorheriges: ${amount.toStringAsFixed(2)} \u20ac',
              style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D))),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                prefixText: '\u20ac ',
                prefixStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: accentColor),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final newAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.').trim());
                  if (newAmount == null || newAmount <= 0) return;
                  Navigator.pop(ctx);

                  // Mark old offer as countered
                  if (offerId > 0) {
                    final repo = ref.read(vehicleRepositoryProvider);
                    repo.counterOffer(
                      originalOfferId: offerId,
                      vehicleId: vehicleId,
                      recipientId: ownerId,
                      amount: newAmount,
                    );
                  }

                  // Send counter-offer via chat
                  final msgRepo = ref.read(messageRepositoryProvider);
                  final jsonBody = '{"type":"counter","vehicle_id":$vehicleId,"vehicle_name":"$vehicleName","owner_id":"$ownerId","amount":$newAmount,"offer_id":$offerId,"title":"Gegenangebot","body":"${newAmount.toStringAsFixed(2)} \u20ac"}';
                  msgRepo.sendMessage(widget.conversationId, jsonBody, messageType: 'vehicle_offer');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gegenangebot: ${newAmount.toStringAsFixed(2)} \u20ac'), backgroundColor: accentColor),
                  );
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text('Gegenangebot senden', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _audioRecorder.dispose();
    // Resume Vosk if it was running before
    if (_voskWasListening) {
      VoskWakeWordService.instance.startListening();
      debugPrint('[Chat] Vosk resumed after chat');
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // reverse: true → position 0 = newest (bottom)
        _scrollController.animateTo(
          0,
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
    debugPrint('[Mic] _startRecording() → calling voice.startRecording');
    try {
      await voice.startRecording(_audioRecorder, (p) {
        _audioPath = p;
        debugPrint('[Mic] audioPath set: $p');
      });
      debugPrint('[Mic] startRecording() completed');
    } catch (e, st) {
      debugPrint('[Mic] startRecording ERROR: $e\n$st');
    }
  }

  Future<void> _stopRecording(int durationMs) async {
    debugPrint('[Mic] _stopRecording(${durationMs}ms)');
    try {
      final path = await _audioRecorder.stop();
      debugPrint('[Mic] recorder.stop() returned: $path');
      if (path != null && durationMs > 500) {
        debugPrint('[Mic] Sending audio message...');
        ref
            .read(chatNotifierProvider(widget.conversationId).notifier)
            .sendAudioMessage(path, durationMs);
        ref.read(messagesNotifierProvider.notifier).refresh();
        _scrollToBottom();
      }
    } catch (e, st) {
      debugPrint('[Mic] stopRecording ERROR: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final chatState = ref.watch(chatNotifierProvider(widget.conversationId));

    // Auto-scroll when new messages arrive + buyer confetti on accepted
    ref.listen(chatNotifierProvider(widget.conversationId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        _scrollToBottom();
        // Check newest incoming vehicle_offer for confetti
        final newest = next.messages.last;
        if (newest.messageType == 'vehicle_offer' &&
            newest.senderId != Supabase.instance.client.auth.currentUser?.id) {
          try {
            final data = json.decode(newest.body) as Map<String, dynamic>;
            final vName = data['vehicle_name'] as String? ?? '';
            final amt = (data['amount'] as num?)?.toDouble() ??
                        (data['price'] as num?)?.toDouble() ?? 0;
            if (data['type'] == 'accepted') {
              // Buyer sees "accepted" → buyer confetti
              _showBuyerConfetti(vName, amt);
            } else if (data['type'] == 'direct_buy') {
              // Seller sees incoming "direct_buy" → sale confetti!
              _showSaleConfetti(vName, amt);
            }
          } catch (_) {}
        }
        // Heart rain when receiving contact details from match (once per session)
        if (newest.senderId != Supabase.instance.client.auth.currentUser?.id &&
            newest.body.contains('💌 Kontaktdaten:') &&
            !_shownMatchRain.contains(widget.conversationId)) {
          _shownMatchRain.add(widget.conversationId);
          _showMatchHeartRain();
        }
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
                    // Avatar with online status
                    if (chatState.isGroupChat)
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.6)]),
                        ),
                        child: const Center(child: Icon(Icons.groups_rounded, size: 18, color: Colors.white)),
                      )
                    else
                      OnlineStatusAvatar(
                        userId: chatState.otherUserId ?? '',
                        avatarUrl: chatState.otherAvatarUrl,
                        size: 34,
                        borderWidth: 2.0,
                        fallbackIcon: Center(
                          child: Text(
                            (chatState.otherUsername ?? '?')[0].toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
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
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          // reverse: true flips the list so index 0 = newest
                          final reversedIndex =
                              chatState.messages.length - 1 - index;
                          final message = chatState.messages[reversedIndex];
                          final isMe = message.senderId == _currentUserId;
                          final showDate = reversedIndex == 0 ||
                              _shouldShowDate(
                                chatState.messages[reversedIndex - 1],
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
                                onDelete: isMe ? () => _confirmDeleteMessage(message) : null,
                                onEdit: isMe && message.messageType == 'text' ? () => _showEditDialog(message) : null,
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
                                onOfferAction: message.messageType == 'vehicle_offer'
                                    ? (action, data) => _handleOfferAction(action, data)
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
