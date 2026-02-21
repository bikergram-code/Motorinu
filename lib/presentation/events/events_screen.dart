import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../providers/blitzer/navigation_provider.dart';
import '../../theme/app_theme.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await Supabase.instance.client
          .from('events')
          .select('*, profiles!events_user_id_fkey(username, display_name, avatar_url)')
          .gte('starts_at', DateTime.now().toIso8601String())
          .order('starts_at', ascending: true);

      // Load participant counts
      for (final event in data) {
        final participants = await Supabase.instance.client
            .from('event_participants')
            .select('user_id')
            .eq('event_id', event['id'])
            .eq('status', 'going');
        event['participant_count'] = participants.length;

        // Check if current user is participating
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          final myParticipation = await Supabase.instance.client
              .from('event_participants')
              .select('status')
              .eq('event_id', event['id'])
              .eq('user_id', currentUserId)
              .maybeSingle();
          event['my_status'] = myParticipation?['status'];
        }
      }

      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleParticipation(int eventId, String? currentStatus) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (currentStatus == 'going') {
        // Leave event
        await Supabase.instance.client
            .from('event_participants')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', currentUserId);
      } else {
        // Join event
        await Supabase.instance.client
            .from('event_participants')
            .upsert({
          'event_id': eventId,
          'user_id': currentUserId,
          'status': 'going',
        });
      }
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    // Re-register Speed-Dial items every build (ensures they persist after tab switches)
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/events') {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(speedDialItemsProvider.notifier).register([
          SpeedDialItem(
            icon: Icons.event_rounded,
            label: 'Neues Event',
            color: Colors.deepOrange,
            onTap: () { if (!mounted) return; _showCreateEventSheet(); },
          ),
        ]);
      });
    }

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      body: CustomScrollView(
        slivers: [
          // Spacer for global top bar (icons are now in MainShell)
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 52),
          ),
          SliverToBoxAdapter(
            child: _buildContent(accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color accentColor) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 100),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 16),
              Text(
                'Fehler beim Laden',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadEvents,
                child: Text('Erneut versuchen',
                    style: GoogleFonts.inter(
                        color: accentColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                child: Icon(Icons.event_rounded,
                    size: 36, color: Colors.white.withValues(alpha: 0.15)),
              ),
              const SizedBox(height: 20),
              Text(
                'Keine Events geplant',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Erstelle das erste Event!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6C757D),
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

    return RefreshIndicator(
      color: accentColor,
      onRefresh: _loadEvents,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _events.length,
        itemBuilder: (context, index) =>
            _EventCard(
              event: _events[index],
              accentColor: accentColor,
              cardColor: community?.cardFor(brightness),
              onToggle: () => _toggleParticipation(
                _events[index]['id'] as int,
                _events[index]['my_status'] as String?,
              ),
            ),
      ),
    );
  }

  void _showCreateEventSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

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
                maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: BoxDecoration(
              color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Neues Event',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
                  const SizedBox(height: 24),

                  _sheetLabel('Titel'),
                  const SizedBox(height: 8),
                  _sheetInput(titleCtrl, 'z.B. Biker-Treffen Köln', accentColor: accentColor),

                  const SizedBox(height: 16),
                  _sheetLabel('Beschreibung'),
                  const SizedBox(height: 8),
                  _sheetInput(descCtrl, 'Was erwartet die Teilnehmer?',
                      maxLines: 3, accentColor: accentColor),

                  const SizedBox(height: 16),
                  _sheetLabel('Ort'),
                  const SizedBox(height: 8),
                  _sheetInput(locationCtrl, 'z.B. Köln Deutzer Brücke', accentColor: accentColor),

                  const SizedBox(height: 16),
                  _sheetLabel('Datum & Uhrzeit'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time == null) return;
                      setSheetState(() {
                        selectedDate = DateTime(
                          date.year, date.month, date.day,
                          time.hour, time.minute,
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.day}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year} um ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.inter(
                                fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        try {
                          final userId = Supabase
                              .instance.client.auth.currentUser?.id;
                          if (userId == null) return;

                          await Supabase.instance.client
                              .from('events')
                              .insert({
                            'user_id': userId,
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim().isNotEmpty
                                ? descCtrl.text.trim()
                                : null,
                            'location_text':
                                locationCtrl.text.trim().isNotEmpty
                                    ? locationCtrl.text.trim()
                                    : null,
                            'starts_at':
                                selectedDate.toIso8601String(),
                            'community':
                                community?.name ?? 'bikergram',
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadEvents();
                        } catch (e) {
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Event erstellen',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _sheetLabel(String text) {
    final brightness = Theme.of(context).brightness;
    return Text(text,
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D)));
  }

  Widget _sheetInput(TextEditingController controller, String hint,
      {int maxLines = 1, required Color accentColor}) {
    final brightness = Theme.of(context).brightness;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 15, color: Colors.white.withValues(alpha: 0.2)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.accentColor,
    required this.onToggle,
    this.cardColor,
  });

  final Map<String, dynamic> event;
  final Color accentColor;
  final VoidCallback onToggle;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final profile = event['profiles'] as Map<String, dynamic>?;
    final creatorName =
        profile?['display_name'] ?? profile?['username'] ?? 'Unbekannt';
    final startsAt = DateTime.tryParse(event['starts_at'] ?? '');
    final isGoing = event['my_status'] == 'going';
    final participantCount = event['participant_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          if (event['image_url'] != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                event['image_url'],
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              ),
            )
          else
            _buildImagePlaceholder(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge
                if (startsAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_weekday(startsAt.weekday)}, ${startsAt.day}.${startsAt.month.toString().padLeft(2, '0')}.${startsAt.year} · ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')} Uhr',
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
                  event['title'] ?? 'Event',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),

                if (event['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    event['description'],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Location + organizer
                Row(
                  children: [
                    if (event['location_text'] != null) ...[
                      Icon(Icons.location_on_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event['location_text'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.person_outline_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 4),
                    Text(
                      creatorName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Action row
                Row(
                  children: [
                    // Participant count
                    Icon(Icons.people_outline_rounded,
                        size: 18,
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D)),
                    const SizedBox(width: 6),
                    Text(
                      '$participantCount Teilnehmer',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D),
                      ),
                    ),
                    const Spacer(),
                    // Join/Leave button
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onToggle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGoing
                              ? Colors.white.withValues(alpha: 0.08)
                              : accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          isGoing ? 'Teilnahme zurücknehmen' : 'Teilnehmen',
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

  Widget _buildImagePlaceholder() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.event_rounded,
            size: 40, color: accentColor.withValues(alpha: 0.3)),
      ),
    );
  }

  String _weekday(int day) {
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return days[(day - 1) % 7];
  }
}
