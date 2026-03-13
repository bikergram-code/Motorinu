import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../domain/xp_calculator.dart';
import '../../domain/badge_calculator.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../theme/app_theme.dart';
import 'widgets/edit_profile_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  /// If null, shows the current user's own profile.
  /// If set, shows another user's profile.
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _postCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  // For other user's profile
  Map<String, dynamic>? _otherProfile;
  bool _isLoadingProfile = false;

  bool get _isOwnProfile {
    if (widget.userId == null) return true;
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      return authState.user.id == widget.userId;
    }
    return false;
  }

  String get _targetUserId {
    if (widget.userId != null) return widget.userId!;
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) return authState.user.id;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadStats(),
      if (!_isOwnProfile) _loadOtherProfile(),
      if (!_isOwnProfile) _checkFollowing(),
    ]);
  }

  Future<void> _loadStats() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;

    try {
      final repo = ref.read(profileRepositoryProvider);
      final results = await Future.wait([
        repo.getPostCount(userId),
        repo.getFollowerCount(userId),
        repo.getFollowingCount(userId),
      ]);

      if (!mounted) return;
      setState(() {
        _postCount = results[0];
        _followerCount = results[1];
        _followingCount = results[2];
      });
    } catch (e) {
      debugPrint('Stats load error: $e');
    }
  }

  Future<void> _loadOtherProfile() async {
    if (_isOwnProfile) return;

    setState(() => _isLoadingProfile = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final data = await repo.getProfile(widget.userId!);
      if (!mounted) return;
      setState(() {
        _otherProfile = data;
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _checkFollowing() async {
    if (_isOwnProfile) return;
    try {
      final repo = ref.read(profileRepositoryProvider);
      final following = await repo.isFollowing(widget.userId!);
      if (!mounted) return;
      setState(() => _isFollowing = following);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_isOwnProfile) return;
    setState(() => _isLoadingFollow = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = await repo.toggleFollow(widget.userId!);
      if (!mounted) return;
      setState(() {
        _isFollowing = result;
        _isLoadingFollow = false;
        _followerCount += result ? 1 : -1;
      });
      // Create notification when following (not unfollowing)
      if (result) {
        final authState = ref.read(authNotifierProvider);
        final myId = authState is Authenticated ? authState.user.id : '';
        final myName = authState is Authenticated
            ? (authState.user.displayName ?? authState.user.username)
            : '';
        final community = ref.read(communityProvider);
        ref.read(notificationRepositoryProvider).createNotification(
          targetUserId: widget.userId!,
          type: 'follow',
          title: '$myName folgt dir jetzt',
          data: {'follower_id': myId},
          community: community?.name,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  Future<void> _startConversation() async {
    if (_isOwnProfile || widget.userId == null) return;

    try {
      final repo = ref.read(messageRepositoryProvider);
      final community = ref.read(communityProvider);
      final conversationId =
          await repo.getOrCreateConversation(widget.userId!, community: community?.name);
      if (!mounted) return;
      context.push('/messages/$conversationId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final authState = ref.watch(authNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    // Determine profile data source
    String username;
    String? displayName;
    String? avatarUrl;
    String? bio;
    int xp = 0;
    int level = 1;
    List<BadgeInfo> badges = [];

    if (_isOwnProfile) {
      final user = authState is Authenticated ? authState.user : null;
      username = user?.username ?? 'Rider';
      displayName = user?.displayName;
      // Community-spezifisches Avatar
      if (community == Community.cargram) {
        avatarUrl = user?.avatarUrlCargram ?? user?.avatarUrl;
      } else {
        avatarUrl = user?.avatarUrl;
      }
      bio = user?.bio;
      xp = user?.xpTotal ?? 0;
      level = user?.level ?? 1;
      if (user != null) {
        badges = BadgeCalculator.getAllBadges(
          birthYear: user.birthYear,
          motoStartAge: user.motoStartAge,
          carStartAge: user.carStartAge,
          hasTrackExperience: user.hasTrackExperience,
        );
      }
    } else {
      username = _otherProfile?['username'] ?? 'User';
      displayName = _otherProfile?['display_name'];
      // Community-spezifisches Avatar fuer andere User
      if (community == Community.cargram) {
        avatarUrl = _otherProfile?['avatar_url_cargram'] ??
            _otherProfile?['avatar_url'];
      } else {
        avatarUrl = _otherProfile?['avatar_url'];
      }
      bio = _otherProfile?['bio'];
      xp = _otherProfile?['xp_total'] ?? 0;
      level = _otherProfile?['level'] ?? 1;
      badges = BadgeCalculator.getAllBadges(
        birthYear: _otherProfile?['birth_year'] as int?,
        motoStartAge: _otherProfile?['moto_start_age'] as int?,
        carStartAge: _otherProfile?['car_start_age'] as int?,
        hasTrackExperience:
            _otherProfile?['has_track_experience'] ?? false,
      );
    }

    final shownName = displayName ?? username;

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : CustomScrollView(
              slivers: [
                // Own profile: no AppBar needed (Global Top Bar in MainShell handles title + settings)
                // Other user: show AppBar with back button and username
                if (_isOwnProfile)
                  // Spacer to push content below the Global Top Bar
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 48))
                else
                  SliverAppBar(
                    floating: true,
                    backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
                    surfaceTintColor: Colors.transparent,
                    leading: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back_rounded,
                          color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
                    ),
                    title: Text(
                      username,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    actions: [
                      if (!_isOwnProfile)
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            onPressed: _startConversation,
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.chat_bubble_outline_rounded,
                                size: 22,
                                color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
                            tooltip: 'Nachricht senden',
                          ),
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Avatar
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: avatarUrl == null
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor,
                                      accentColor.withValues(alpha: 0.6),
                                    ],
                                  )
                                : null,
                          ),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildInitial(shownName, accentColor),
                                  )
                                : _buildInitial(shownName, accentColor),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Name & bio
                        Text(
                          shownName,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                          ),
                        ),
                        if (bio != null && bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            bio,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D)),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        // ── Badges ──
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 26,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              itemCount: badges.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                final b = badges[i];
                                return GestureDetector(
                                  onTap: () =>
                                      _showBadgeInfo(context, b, accentColor),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          b.color.withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(13),
                                      border: Border.all(
                                        color:
                                            b.color.withValues(alpha: 0.25),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(b.emoji,
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        const SizedBox(width: 3),
                                        Text(
                                          b.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: b.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ProfileStat(
                                value: '$_postCount',
                                label: 'Beitr\u00e4ge'),
                            _ProfileStat(
                                value: '$_followerCount',
                                label: 'Follower'),
                            _ProfileStat(
                                value: '$_followingCount',
                                label: 'Folge ich'),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Own Profile: XP + Edit + Menu ──
                        if (_isOwnProfile) ...[
                          // XP card
                          _XpCard(
                              xp: xp,
                              level: level,
                              accentColor: accentColor),

                          const SizedBox(height: 20),

                          // Edit profile button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () async {
                                await EditProfileSheet.show(context);
                                ref
                                    .read(authNotifierProvider.notifier)
                                    .checkAuth();
                                _loadStats();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.15),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Profil bearbeiten',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Menu items
                          _MenuItem(
                            icon: Icons.emoji_events_rounded,
                            label: 'Achievements',
                            color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.bookmark_rounded,
                            label: 'Gespeicherte Beitr\u00e4ge',
                            color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/saved-posts'),
                          ),
                          _MenuItem(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Premium',
                            color: Colors.amber,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () {},
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PRO',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Logout
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: TextButton(
                              onPressed: () => ref
                                  .read(authNotifierProvider.notifier)
                                  .logout(),
                              child: Text(
                                'Abmelden',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.errorDark,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // ── Other user profile: Follow + Message buttons ──
                        if (!_isOwnProfile) ...[
                          // Action buttons row
                          Builder(builder: (_) {
                            final isDark = brightness == Brightness.dark;
                            final textColor = community?.textColor(brightness) ?? (isDark ? Colors.white : const Color(0xFF1A1A1A));
                            final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.15);

                            return Row(
                              children: [
                                // Follow/Unfollow button
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: _isLoadingFollow
                                          ? null
                                          : _toggleFollow,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing
                                            ? (isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : Colors.black.withValues(alpha: 0.06))
                                            : accentColor,
                                        foregroundColor: _isFollowing
                                            ? textColor
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoadingFollow
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            )
                                          : Text(
                                              _isFollowing
                                                  ? 'Entfolgen'
                                                  : 'Folgen',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Message button
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed: _startConversation,
                                      icon: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 18,
                                          color: textColor),
                                      label: Text(
                                        'Nachricht',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textColor,
                                        side: BorderSide(color: borderColor),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),

                          const SizedBox(height: 20),

                          // XP card for other user
                          _XpCard(
                              xp: xp,
                              level: level,
                              accentColor: accentColor),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showBadgeInfo(
      BuildContext context, BadgeInfo badge, Color accentColor) {
    // Badge-Kategorie in deutschem Text
    final categoryLabel = switch (badge.category) {
      'moto' => 'Motorrad-Erfahrung',
      'car' => 'Auto-Erfahrung',
      'age' => 'Alters-Badge',
      'track' => 'Rennstrecke',
      _ => 'Badge',
    };

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: badge.color.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: badge.color.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grosses Emoji
                Text(badge.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),

                // Label
                Text(
                  badge.label,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: badge.color,
                  ),
                ),
                const SizedBox(height: 4),

                // Kategorie
                Text(
                  categoryLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),

                // Jahre (falls vorhanden)
                if (badge.years != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${badge.years} Jahre Erfahrung',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badge.color,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Schliessen
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Text(
                    'OK',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
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

  Widget _buildInitial(String name, Color accentColor) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({
    required this.xp,
    required this.level,
    required this.accentColor,
  });

  final int xp;
  final int level;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final levelName = XpCalculator.levelName(level);
    final levelClr = XpCalculator.levelColor(level);
    final nextLevelName = XpCalculator.levelName(level + 1);
    final progress = XpCalculator.levelProgress(xp);
    final xpRemaining = XpCalculator.xpToNextLevel(xp);
    final mutedColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF6C757D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            levelClr.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: levelClr.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: levelClr, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    levelName,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: levelClr,
                    ),
                  ),
                  Text(
                    'Level $level',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$xp XP',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Gesamt',
                    style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(levelClr),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Noch $xpRemaining XP bis $nextLevelName',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: mutedColor,
                ),
              ),
              Text(
                '${xp % 100} / 100',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
    this.cardColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        trailing: trailing ??
            Icon(Icons.chevron_right_rounded,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF6C757D), size: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
