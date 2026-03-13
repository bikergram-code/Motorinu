import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/community.dart';
import '../../core/ticket_url_generator.dart';
import '../../domain/models/event.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/core/speed_dial_provider.dart';
import '../../providers/events/events_notifier.dart';
import '../../theme/app_theme.dart';

/// Events screen with "Heute" section, category filters, and event cards.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(eventsNotifierProvider.notifier).loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final eventsState = ref.watch(eventsNotifierProvider);

    final scaffoldBg = community?.scaffoldFor(brightness) ??
        (isDark ? Colors.black : const Color(0xFFF5F5F5));
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFF9E9E9E));
    final cardColor = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    // Re-register Speed-Dial items
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/events') {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(speedDialItemsProvider.notifier).register([
          SpeedDialItem(
            icon: Icons.event_rounded,
            label: 'Neues Event',
            color: Colors.deepOrange,
            onTap: () {
              if (!mounted) return;
              _showCreateEventSheet();
            },
          ),
        ]);
      });
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: RefreshIndicator(
        color: accentColor,
        onRefresh: () => ref.read(eventsNotifierProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // Spacer for global top bar
            SliverToBoxAdapter(
              child:
                  SizedBox(height: MediaQuery.of(context).padding.top + 52),
            ),

            // ── Loading ──
            if (eventsState.isLoading &&
                eventsState.events.isEmpty &&
                eventsState.todayEvents.isEmpty)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )

            // ── Error ──
            else if (eventsState.error != null && eventsState.events.isEmpty)
              SliverFillRemaining(
                child: _buildError(eventsState, accentColor, textColor),
              )

            // ── Content ──
            else ...[
              // ── Heute Section ──
              if (eventsState.todayEvents.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'HEUTE',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${eventsState.todayEvents.length} Event${eventsState.todayEvents.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 170,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: eventsState.todayEvents.length,
                      itemBuilder: (context, index) {
                        return _TodayEventCard(
                          event: eventsState.todayEvents[index],
                          accentColor: accentColor,
                          onTap: () {},
                          onToggle: () => ref
                              .read(eventsNotifierProvider.notifier)
                              .toggleParticipation(
                                  eventsState.todayEvents[index].id),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Cross-Promotion Banner ──
              if (eventsState.crossPromoEvents.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CrossPromoBanner(
                    events: eventsState.crossPromoEvents,
                    currentCommunity: community?.name ?? 'bikergram',
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    cardColor: cardColor,
                    isDark: isDark,
                  ),
                ),

              // ── Category Filter Chips ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Alle',
                          isSelected: eventsState.selectedCategory == null,
                          accentColor: accentColor,
                          textColor: textColor,
                          onTap: () => ref
                              .read(eventsNotifierProvider.notifier)
                              .filterByCategory(null),
                        ),
                        ...EventCategory.all.map((cat) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _FilterChip(
                                label: EventCategory.label(cat),
                                isSelected:
                                    eventsState.selectedCategory == cat,
                                accentColor: accentColor,
                                textColor: textColor,
                                onTap: () => ref
                                    .read(eventsNotifierProvider.notifier)
                                    .filterByCategory(cat),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Upcoming Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        'Kommende Events',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      if (eventsState.events.isNotEmpty)
                        Text(
                          '${eventsState.events.length}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Event List ──
              if (eventsState.events.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmpty(accentColor, textColor, mutedColor),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _EventCard(
                          event: eventsState.events[index],
                          accentColor: accentColor,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          cardColor: cardColor,
                          onToggle: () => ref
                              .read(eventsNotifierProvider.notifier)
                              .toggleParticipation(
                                  eventsState.events[index].id),
                        ),
                      );
                    },
                    childCount: eventsState.events.length,
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(
      EventsState state, Color accentColor, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              color: textColor.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 16),
          Text(
            state.error ?? 'Fehler beim Laden',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                ref.read(eventsNotifierProvider.notifier).loadEvents(),
            child: Text('Erneut versuchen',
                style: GoogleFonts.inter(
                    color: accentColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color accentColor, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.event_rounded,
                  size: 36, color: accentColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            Text(
              'Keine Events geplant',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Erstelle das erste Event!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreateEventSheet,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('Event erstellen',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  CREATE EVENT SHEET
  // ═══════════════════════════════════════════════════

  void _showCreateEventSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final maxParticipantsCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime? selectedEndDate;
    String selectedCategory = 'meetup';
    Uint8List? selectedImageBytes;
    bool isCreating = false;

    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final cardColor = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF6C757D);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            margin: EdgeInsets.only(bottom: bottomInset),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Neues Event',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const SizedBox(height: 24),

                  // ── Image Picker ──
                  _sheetLabel('Bild (optional)', mutedColor),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1200,
                        maxHeight: 800,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setSheetState(
                            () => selectedImageBytes = bytes);
                      }
                    },
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE0E0E0),
                        ),
                        image: selectedImageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(selectedImageBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: selectedImageBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 36, color: mutedColor),
                                const SizedBox(height: 8),
                                Text(
                                  'Bild hinzufuegen',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: mutedColor),
                                ),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: GestureDetector(
                                  onTap: () => setSheetState(
                                      () => selectedImageBytes = null),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Category Chips ──
                  _sheetLabel('Kategorie', mutedColor),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final authState = ref.read(authNotifierProvider);
                    final isPro = authState is Authenticated &&
                        authState.user.isPremium;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: EventCategory.all.map((cat) {
                        final isSelected = selectedCategory == cat;
                        final isLocked =
                            cat == EventCategory.trackday && !isPro;
                        return GestureDetector(
                          onTap: () {
                            if (isLocked) {
                              // Show Pro upsell
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.lock_rounded,
                                          color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Trackday-Events sind nur mit Pro-Abo verfuegbar',
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => selectedCategory = cat);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor
                                  : isLocked
                                      ? (isDark
                                          ? Colors.white.withValues(alpha: 0.03)
                                          : const Color(0xFFF8F8F8))
                                      : (isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.06)
                                          : const Color(0xFFF0F0F0)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : isLocked
                                        ? (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.05)
                                            : const Color(0xFFE8E8E8))
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : const Color(0xFFE0E0E0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLocked) ...[
                                  Icon(Icons.lock_rounded,
                                      size: 13,
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade700),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  EventCategory.label(cat),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : isLocked
                                            ? mutedColor
                                            : textColor,
                                  ),
                                ),
                                if (isLocked) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade700,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'PRO',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── Title ──
                  _sheetLabel('Titel', mutedColor),
                  const SizedBox(height: 8),
                  _sheetInput(titleCtrl, 'z.B. Biker-Treffen Koeln',
                      accentColor: accentColor,
                      textColor: textColor,
                      isDark: isDark),

                  const SizedBox(height: 16),

                  // ── Description ──
                  _sheetLabel('Beschreibung', mutedColor),
                  const SizedBox(height: 8),
                  _sheetInput(
                      descCtrl, 'Was erwartet die Teilnehmer?',
                      maxLines: 3,
                      accentColor: accentColor,
                      textColor: textColor,
                      isDark: isDark),

                  const SizedBox(height: 16),

                  // ── Location ──
                  _sheetLabel('Ort', mutedColor),
                  const SizedBox(height: 8),
                  _sheetInput(
                      locationCtrl, 'z.B. Nuerburgring Nordschleife',
                      accentColor: accentColor,
                      textColor: textColor,
                      isDark: isDark),

                  const SizedBox(height: 16),

                  // ── Start Date ──
                  _sheetLabel('Startdatum & Uhrzeit', mutedColor),
                  const SizedBox(height: 8),
                  _buildDatePicker(
                    ctx,
                    selectedDate,
                    isDark,
                    textColor,
                    mutedColor,
                    onChanged: (d) =>
                        setSheetState(() => selectedDate = d),
                  ),

                  const SizedBox(height: 16),

                  // ── End Date (optional) ──
                  _sheetLabel('Enddatum (optional)', mutedColor),
                  const SizedBox(height: 8),
                  _buildDatePicker(
                    ctx,
                    selectedEndDate,
                    isDark,
                    textColor,
                    mutedColor,
                    placeholder: 'Enddatum waehlen...',
                    onChanged: (d) =>
                        setSheetState(() => selectedEndDate = d),
                  ),

                  const SizedBox(height: 16),

                  // ── Max Participants (optional) ──
                  _sheetLabel('Max. Teilnehmer (optional)', mutedColor),
                  const SizedBox(height: 8),
                  _sheetInput(maxParticipantsCtrl, 'z.B. 50',
                      accentColor: accentColor,
                      textColor: textColor,
                      isDark: isDark,
                      keyboardType: TextInputType.number),

                  const SizedBox(height: 28),

                  // ── Create Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isCreating
                          ? null
                          : () async {
                              if (titleCtrl.text.trim().isEmpty) return;
                              setSheetState(() => isCreating = true);

                              try {
                                final maxP =
                                    int.tryParse(maxParticipantsCtrl.text);
                                await ref
                                    .read(eventsNotifierProvider.notifier)
                                    .createEvent(
                                      title: titleCtrl.text.trim(),
                                      description:
                                          descCtrl.text.trim().isNotEmpty
                                              ? descCtrl.text.trim()
                                              : null,
                                      location:
                                          locationCtrl.text.trim().isNotEmpty
                                              ? locationCtrl.text.trim()
                                              : null,
                                      startsAt: selectedDate,
                                      endsAt: selectedEndDate,
                                      category: selectedCategory,
                                      maxParticipants: maxP,
                                      imageBytes: selectedImageBytes,
                                    );

                                if (ctx.mounted) Navigator.pop(ctx);
                                HapticFeedback.mediumImpact();
                              } catch (e) {
                                setSheetState(() => isCreating = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Fehler: $e'),
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            accentColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isCreating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Event erstellen',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetLabel(String text, Color mutedColor) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor));
  }

  Widget _sheetInput(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    required Color accentColor,
    required Color textColor,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : const Color(0xFFBDBDBD)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDatePicker(
    BuildContext ctx,
    DateTime? date,
    bool isDark,
    Color textColor,
    Color mutedColor, {
    String? placeholder,
    required ValueChanged<DateTime> onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: ctx,
          initialDate: date ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (pickedDate == null) return;

        final pickedTime = await showTimePicker(
          context: ctx,
          initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()),
        );
        if (pickedTime == null) return;

        onChanged(DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: mutedColor, size: 18),
            const SizedBox(width: 10),
            Text(
              date != null
                  ? '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year} um ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                  : (placeholder ?? 'Datum waehlen...'),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: date != null ? textColor : mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  FILTER CHIP
// ═══════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor
              : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : accentColor.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  TODAY EVENT CARD (Horizontal scroll)
// ═══════════════════════════════════════════════════

class _TodayEventCard extends StatelessWidget {
  const _TodayEventCard({
    required this.event,
    required this.accentColor,
    required this.onTap,
    required this.onToggle,
  });

  final BikerEvent event;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isGoing = event.myStatus == 'going';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.deepOrange.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            if (event.imageUrl != null)
              CachedNetworkImage(
                imageUrl: event.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _buildGradientBg(accentColor, event.category),
              )
            else
              _buildGradientBg(accentColor, event.category),

            // Dark overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),

            // Category badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _categoryColor(event.category),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  EventCategory.label(event.category),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Time badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')} Uhr',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Bottom info
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (event.location != null) ...[
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(Icons.people_outline_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 3),
                      Text(
                        '${event.participantCount}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isGoing
                            ? Colors.white.withValues(alpha: 0.15)
                            : accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isGoing ? 'Teilnahme' : 'Teilnehmen',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  EVENT CARD (Vertical list)
// ═══════════════════════════════════════════════════

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.cardColor,
    required this.onToggle,
  });

  final BikerEvent event;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final Color cardColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isGoing = event.myStatus == 'going';
    final creatorName = event.creatorName ?? 'Unbekannt';
    // Auto-resolve ticket URL: DB value or auto-generated from title
    final effectiveTicketUrl =
        TicketUrlGenerator.resolveTicketUrl(event.ticketUrl, event.title);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: 0.04),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Image ──
          Stack(
            children: [
              if (event.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: event.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      _buildGradientBg(accentColor, event.category),
                )
              else
                SizedBox(
                  height: 100,
                  child: _buildGradientBg(accentColor, event.category),
                ),

              // Category badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _categoryColor(event.category),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    EventCategory.label(event.category),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(event.startsAt, event.endsAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),

                // Description
                if (event.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.description!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: mutedColor,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Location + Creator
                Row(
                  children: [
                    if (event.location != null) ...[
                      Icon(Icons.location_on_outlined,
                          size: 16, color: mutedColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.location!,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: mutedColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.person_outline_rounded,
                        size: 16, color: mutedColor),
                    const SizedBox(width: 4),
                    Text(
                      creatorName,
                      style:
                          GoogleFonts.inter(fontSize: 13, color: mutedColor),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Participant info
                Row(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 18, color: mutedColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${event.participantCount} Teilnehmer${event.maxParticipants != null ? ' / ${event.maxParticipants}' : ''}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: mutedColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Action buttons (wrap-safe for small screens)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    // Ticket button (auto-resolved from DB or title)
                    if (effectiveTicketUrl != null)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openTicketLink(effectiveTicketUrl),
                          icon: const Icon(
                              Icons.confirmation_number_outlined,
                              size: 16),
                          label: Text('Tickets',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onToggle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGoing
                              ? textColor.withValues(alpha: 0.08)
                              : accentColor,
                          foregroundColor:
                              isGoing ? textColor : Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                        ),
                        child: Text(
                          isGoing ? 'Dabei' : 'Teilnehmen',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime start, DateTime? end) {
    final weekday = _weekday(start.weekday);
    final startStr =
        '$weekday, ${start.day}.${start.month.toString().padLeft(2, '0')}.${start.year} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} Uhr';
    if (end != null) {
      return '$startStr - ${end.day}.${end.month.toString().padLeft(2, '0')} · ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')} Uhr';
    }
    return startStr;
  }

  String _weekday(int day) {
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return days[(day - 1) % 7];
  }

  void _openTicketLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ═══════════════════════════════════════════════════
//  CROSS-PROMOTION BANNER
// ═══════════════════════════════════════════════════

class _CrossPromoBanner extends StatelessWidget {
  const _CrossPromoBanner({
    required this.events,
    required this.currentCommunity,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.cardColor,
    required this.isDark,
  });

  final List<BikerEvent> events;
  final String currentCommunity;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final Color cardColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isBikeApp = currentCommunity == 'bikergram';
    final bannerIcon = isBikeApp ? '\u{1F3CE}' : '\u{1F3CD}'; // car or motorcycle
    final bannerTitle = isBikeApp ? 'Aus der Auto-Welt' : 'Aus der Bike-Welt';
    final bannerGradient = isBikeApp
        ? [Colors.blue.shade900, Colors.indigo.shade800]
        : [Colors.orange.shade900, Colors.deepOrange.shade800];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bannerGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bannerGradient.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(bannerIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    bannerTitle,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'TIPP',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Event list (max 3)
              ...events.take(3).map((event) {
                final daysUntil =
                    event.startsAt.difference(DateTime.now()).inDays;
                final timeLabel = daysUntil == 0
                    ? 'Heute!'
                    : daysUntil == 1
                        ? 'Morgen'
                        : 'in $daysUntil Tagen';

                // Auto-resolve ticket URL
                final ticketUrl = TicketUrlGenerator.resolveTicketUrl(
                    event.ticketUrl, event.title);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Event image thumbnail
                      if (event.imageUrl != null)
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image:
                                  CachedNetworkImageProvider(event.imageUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: Center(
                            child: Text(
                              EventCategory.icon(event.category),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),

                      // Event info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (event.location != null) ...[
                                  Icon(Icons.location_on_outlined,
                                      size: 11,
                                      color:
                                          Colors.white.withValues(alpha: 0.5)),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      event.location!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: daysUntil <= 3
                                        ? Colors.deepOrange
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    timeLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Ticket button
                      if (ticketUrl != null)
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(ticketUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.confirmation_number_outlined,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Tickets',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════

Widget _buildGradientBg(Color accent, String category) {
  final catColor = _categoryColor(category);
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          catColor.withValues(alpha: 0.3),
          accent.withValues(alpha: 0.1),
        ],
      ),
    ),
    child: Center(
      child: Icon(
        _categoryIcon(category),
        size: 40,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    ),
  );
}

Color _categoryColor(String category) {
  switch (category) {
    case 'meetup':
      return Colors.blue;
    case 'trackday':
      return Colors.orange;
    case 'ride':
      return Colors.green;
    case 'fair':
      return Colors.purple;
    case 'race':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'meetup':
      return Icons.groups_rounded;
    case 'trackday':
      return Icons.timer_rounded;
    case 'ride':
      return Icons.route_rounded;
    case 'fair':
      return Icons.storefront_rounded;
    case 'race':
      return Icons.emoji_events_rounded;
    default:
      return Icons.event_rounded;
  }
}
