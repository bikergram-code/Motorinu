import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../data/repositories/profile_repository.dart';
import '../../providers/core/providers.dart';
import '../../providers/dating/dating_notifier.dart';
import 'widgets/edit_dating_profile_sheet.dart';
import 'widgets/match_overlay.dart';
import 'widgets/swipe_card.dart';

class DatingScreen extends ConsumerStatefulWidget {
  const DatingScreen({super.key});

  @override
  ConsumerState<DatingScreen> createState() => _DatingScreenState();
}

class _DatingScreenState extends ConsumerState<DatingScreen>
    with TickerProviderStateMixin {
  // Swipe animation
  Offset _dragStart = Offset.zero;
  Offset _dragOffset = Offset.zero;
  late AnimationController _flyController;
  late AnimationController _springController;
  late Animation<Offset> _flyAnimation;
  late Animation<Offset> _springAnimation;
  bool _isDragging = false;
  bool _isFlying = false;

  // Filters
  String _showGender = 'all'; // all, male, female, other
  int _minAge = 18;
  int _maxAge = 80;
  int _maxDistKm = 0; // 0 = unbegrenzt

  // My location (for distance calc)
  double? _myLat;
  double? _myLng;
  String? _myAvatarUrl;

  @override
  void initState() {
    super.initState();

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _flyAnimation = _flyController.drive(Tween(begin: Offset.zero, end: Offset.zero));
    _springAnimation = _springController.drive(Tween(begin: Offset.zero, end: Offset.zero));

    _flyController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isFlying = false;
          _dragOffset = Offset.zero;
        });
      }
    });

    _springController.addListener(() {
      setState(() {
        _dragOffset = _springAnimation.value;
      });
    });

    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final community = ref.read(communityProvider);
    if (community == null) return;

    // Load my profile for location + avatar + gender pref
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final profile = await ProfileRepository().getProfile(userId);
        if (mounted) {
          setState(() {
            _myLat = profile['home_lat'] as double?;
            _myLng = profile['home_lng'] as double?;
            _myAvatarUrl = community == Community.cargram
                ? (profile['avatar_url_cargram'] ?? profile['avatar_url']) as String?
                : profile['avatar_url'] as String?;
            _showGender = profile['show_gender'] as String? ?? 'all';
          });
        }
      }
    } catch (_) {}

    ref.read(datingNotifierProvider.notifier).loadCandidates(community.name);
  }

  @override
  void dispose() {
    _flyController.dispose();
    _springController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isFlying) return;
    _springController.stop();
    _isDragging = true;
    _dragStart = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final dx = _dragOffset.dx;
    if (dx.abs() > 100) {
      // Fly off screen
      _flyOff(isLike: dx > 0);
    } else {
      // Spring back
      _springBack();
    }
  }

  void _flyOff({required bool isLike}) {
    final community = ref.read(communityProvider);
    if (community == null) return;

    final datingState = ref.read(datingNotifierProvider);
    if (datingState.candidates.isEmpty) return;

    final candidate = datingState.candidates.first;
    final targetX = isLike ? 500.0 : -500.0;

    setState(() => _isFlying = true);

    _flyAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, _dragOffset.dy - 50),
    ).animate(CurvedAnimation(parent: _flyController, curve: Curves.easeIn));

    _flyController.forward(from: 0).then((_) {
      // Store avatar before swiping (for match overlay)
      final avatarUrl = community == Community.cargram
          ? (candidate['avatar_url_cargram'] ?? candidate['avatar_url'])
          : candidate['avatar_url'];

      ref.read(datingNotifierProvider.notifier).swipe(
        swipedId: candidate['id'],
        isLike: isLike,
        community: community.name,
        matchedAvatarUrl: avatarUrl as String?,
      );
    });
  }

  void _springBack() {
    _springAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _springController, curve: Curves.elasticOut));
    _springController.forward(from: 0);
  }

  void _onLikeButton() {
    if (_isFlying || _isDragging) return;
    setState(() => _dragOffset = const Offset(20, 0));
    _flyOff(isLike: true);
  }

  void _onNopeButton() {
    if (_isFlying || _isDragging) return;
    setState(() => _dragOffset = const Offset(-20, 0));
    _flyOff(isLike: false);
  }

  void _onGenderChanged(String gender) {
    setState(() => _showGender = gender);
    // Persist preference in background
    ProfileRepository().updateProfile(showGender: gender).catchError((_) {});
  }

  /// Filter candidates locally based on gender, age, distance
  List<Map<String, dynamic>> _filterCandidates(List<Map<String, dynamic>> raw) {
    final now = DateTime.now().year;
    return raw.where((c) {
      // Gender filter
      if (_showGender != 'all') {
        final g = c['gender'] as String?;
        if (g != _showGender) return false;
      }
      // Age filter — Minderjährige IMMER ausschließen
      final birthYear = c['birth_year'] as int?;
      if (birthYear != null) {
        final age = now - birthYear;
        if (age < 18) return false; // Minderjährigenschutz
        if (age < _minAge || age > _maxAge) return false;
      } else {
        return false; // Kein Geburtsjahr = kein Dating
      }
      // Distance filter
      if (_maxDistKm > 0 && _myLat != null && _myLng != null) {
        final lat2 = c['home_lat'] as double?;
        final lng2 = c['home_lng'] as double?;
        if (lat2 != null && lng2 != null) {
          final dist = _haversineKm(_myLat!, _myLng!, lat2, lng2);
          if (dist > _maxDistKm) return false;
        }
      }
      return true;
    }).toList();
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _openFilterSheet() {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? const Color(0xFFCC0000);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);

    int tmpMinAge = _minAge;
    int tmpMaxAge = _maxAge;
    int tmpMaxDist = _maxDistKm;
    String tmpGender = _showGender;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Filter', style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w800, color: textColor,
                    )),
                    const SizedBox(height: 20),

                    // ── Geschlecht ──
                    Text('Geschlecht', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.7),
                    )),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _filterChip('Alle', 'all', tmpGender, accentColor, isDark, (v) => setSheetState(() => tmpGender = v)),
                        const SizedBox(width: 6),
                        _filterChip('Männer', 'male', tmpGender, accentColor, isDark, (v) => setSheetState(() => tmpGender = v)),
                        const SizedBox(width: 6),
                        _filterChip('Frauen', 'female', tmpGender, accentColor, isDark, (v) => setSheetState(() => tmpGender = v)),
                        const SizedBox(width: 6),
                        _filterChip('Divers', 'other', tmpGender, accentColor, isDark, (v) => setSheetState(() => tmpGender = v)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Alter ──
                    Row(
                      children: [
                        Text('Alter', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.7),
                        )),
                        const Spacer(),
                        Text('${tmpMinAge} – ${tmpMaxAge} Jahre', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700, color: accentColor,
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: RangeValues(tmpMinAge.toDouble(), tmpMaxAge.toDouble()),
                      min: 18,
                      max: 80,
                      divisions: 62,
                      activeColor: accentColor,
                      inactiveColor: accentColor.withValues(alpha: 0.15),
                      labels: RangeLabels('$tmpMinAge', '$tmpMaxAge'),
                      onChanged: (v) => setSheetState(() {
                        tmpMinAge = v.start.round();
                        tmpMaxAge = v.end.round();
                      }),
                    ),
                    const SizedBox(height: 16),

                    // ── Umkreis ──
                    Row(
                      children: [
                        Text('Umkreis', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.7),
                        )),
                        const Spacer(),
                        Text(
                          tmpMaxDist == 0 ? 'Unbegrenzt' : '$tmpMaxDist km',
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: tmpMaxDist.toDouble(),
                      min: 0,
                      max: 500,
                      divisions: 50,
                      activeColor: accentColor,
                      inactiveColor: accentColor.withValues(alpha: 0.15),
                      label: tmpMaxDist == 0 ? 'Unbegrenzt' : '$tmpMaxDist km',
                      onChanged: (v) => setSheetState(() => tmpMaxDist = v.round()),
                    ),
                    if (_myLat == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠ Standort nicht verfügbar — setze deinen Standort im Profil',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.orange),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Anwenden ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _showGender = tmpGender;
                            _minAge = tmpMinAge;
                            _maxAge = tmpMaxAge;
                            _maxDistKm = tmpMaxDist;
                          });
                          // Persist gender preference
                          ProfileRepository().updateProfile(showGender: tmpGender).catchError((_) {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Filter anwenden', style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String value, String current, Color accent, bool isDark, ValueChanged<String> onTap) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(label, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : (isDark ? Colors.white60 : Colors.black54),
            )),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final rawDatingState = ref.watch(datingNotifierProvider);
    final accentColor = community?.accentColor ?? const Color(0xFFCC0000);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Apply local filters on top of server-returned candidates
    final filteredCandidates = _filterCandidates(rawDatingState.candidates);
    final datingState = DatingState(
      candidates: filteredCandidates,
      isLoading: rawDatingState.isLoading,
      error: rawDatingState.error,
      lastMatch: rawDatingState.lastMatch,
    );

    // Active filter count for badge
    int activeFilters = 0;
    if (_showGender != 'all') activeFilters++;
    if (_minAge != 18 || _maxAge != 99) activeFilters++;
    if (_maxDistKm > 0) activeFilters++;

    return Stack(
      children: [
        // Main content column
        Column(
              children: [
                // ── Filter bar: Edit + Filter button + active gender chips ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
                  child: Row(
                    children: [
                      // Edit profile button
                      GestureDetector(
                        onTap: () async {
                          final changed = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const EditDatingProfileSheet(),
                          );
                          if (changed == true && community != null) {
                            _loadInitialData();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit_rounded,
                              size: 18, color: accentColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter button with badge
                      GestureDetector(
                        onTap: _openFilterSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: activeFilters > 0
                                ? accentColor.withValues(alpha: 0.15)
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: activeFilters > 0 ? accentColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 16,
                                color: activeFilters > 0 ? accentColor : (isDark ? Colors.white60 : Colors.black54)),
                              const SizedBox(width: 4),
                              Text('Filter', style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: activeFilters > 0 ? FontWeight.w700 : FontWeight.w500,
                                color: activeFilters > 0 ? accentColor : (isDark ? Colors.white60 : Colors.black54),
                              )),
                              if (activeFilters > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('$activeFilters', style: GoogleFonts.inter(
                                    fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white,
                                  )),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Quick gender icons — compact & colorful
                      for (final g in [
                        ('Alle', 'all', Icons.people_rounded, accentColor),
                        ('♂', 'male', Icons.male_rounded, Colors.blue),
                        ('♀', 'female', Icons.female_rounded, Colors.pink),
                        ('⚧', 'other', Icons.transgender_rounded, Colors.purple),
                      ]) ...[
                        _GenderIcon(
                          value: g.$2 as String,
                          icon: g.$3 as IconData,
                          color: g.$4 as Color,
                          selected: _showGender == g.$2,
                          isDark: isDark,
                          onTap: () => _onGenderChanged(g.$2 as String),
                        ),
                        const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ),

                // ── Card stack ──
                Expanded(
                  child: datingState.isLoading && datingState.candidates.isEmpty
                      ? _buildLoading(accentColor, community)
                      : datingState.candidates.isEmpty
                          ? _buildEmpty(accentColor)
                          : _buildCardStack(datingState, community!, accentColor),
                ),

                // ── Action buttons ──
                if (datingState.candidates.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 60, top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionButton(
                          icon: Icons.close_rounded,
                          color: Colors.red.shade400,
                          size: 52,
                          iconSize: 26,
                          onTap: _onNopeButton,
                        ),
                        const SizedBox(width: 28),
                        _ActionButton(
                          icon: Icons.favorite_rounded,
                          color: accentColor,
                          size: 52,
                          iconSize: 26,
                          onTap: _onLikeButton,
                          filled: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // ── Match overlay (above everything) ──
            if (datingState.lastMatch != null)
              Positioned.fill(
                child: MatchOverlay(
                  matchData: datingState.lastMatch!,
                  myAvatarUrl: _myAvatarUrl,
                  community: community!,
                  onMessage: () {
                    final convId = datingState.lastMatch!['conversation_id'];
                    ref.read(datingNotifierProvider.notifier).clearMatch();
                    if (convId != null) {
                      context.push('/messages/$convId');
                    }
                  },
                  onContinue: () {
                    ref.read(datingNotifierProvider.notifier).clearMatch();
                  },
                ),
              ),
          ],
    );
  }

  Widget _buildCardStack(DatingState state, Community community, Color accentColor) {
    final candidates = state.candidates;
    // Show up to 3 cards in stack
    final visibleCount = min(3, candidates.length);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background cards (non-draggable)
        for (int i = visibleCount - 1; i >= 1; i--)
          Positioned(
            top: 4.0 + (i * 5),
            left: 20.0 + (i * 4),
            right: 20.0 + (i * 4),
            bottom: 4.0 + (i * 5),
            child: Opacity(
              opacity: 1.0 - (i * 0.15),
              child: SwipeCard(
                candidate: candidates[i],
                community: community,
                myLat: _myLat,
                myLng: _myLng,
              ),
            ),
          ),

        // Top card (draggable)
        Positioned(
          top: 4,
          left: 20,
          right: 20,
          bottom: 4,
          child: GestureDetector(
            onHorizontalDragStart: _onPanStart,
            onHorizontalDragUpdate: _onPanUpdate,
            onHorizontalDragEnd: _onPanEnd,
            child: ListenableBuilder(
              listenable: _isFlying ? _flyController : _springController,
              builder: (context, child) {
                final offset = _isFlying ? _flyAnimation.value : _dragOffset;
                final rotation = offset.dx * 0.0005;
                final likeOpacity = (offset.dx / 150).clamp(0.0, 1.0);
                final nopeOpacity = (-offset.dx / 150).clamp(0.0, 1.0);

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(offset.dx, offset.dy)
                    ..rotateZ(rotation),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SwipeCard(
                        candidate: candidates.first,
                        community: community,
                        myLat: _myLat,
                        myLng: _myLng,
                      ),
                      // LIKE overlay
                      if (likeOpacity > 0)
                        Positioned(
                          top: 40, left: 24,
                          child: Opacity(
                            opacity: likeOpacity,
                            child: Transform.rotate(
                              angle: -0.3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green, width: 3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'LIKE',
                                  style: GoogleFonts.inter(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // NOPE overlay
                      if (nopeOpacity > 0)
                        Positioned(
                          top: 40, right: 24,
                          child: Opacity(
                            opacity: nopeOpacity,
                            child: Transform.rotate(
                              angle: 0.3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.red, width: 3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NOPE',
                                  style: GoogleFonts.inter(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(Color accentColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            size: 80,
            color: accentColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Keine weiteren Profile',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schau später wieder vorbei!',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(Color accentColor, Community? community) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: community?.cardColor ?? const Color(0xFF1E1814),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(
                    color: accentColor,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile werden geladen...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gender Filter Chip ──────────────────────────────────────────────────────

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.2)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? accentColor
                : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54),
          ),
        ),
      ),
    );
  }
}

// ── Gender Icon (compact, colorful) ─────────────────────────────────────────

class _GenderIcon extends StatelessWidget {
  const _GenderIcon({
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: selected ? color : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ),
    );
  }
}

// ── Action Button (Like / Nope) ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (_) => onTap(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2.5),
            boxShadow: filled
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
