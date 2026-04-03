import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../domain/xp_calculator.dart';
import '../../domain/badge_calculator.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/ride_repository.dart';
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

  // Garage summary
  int _bikeCount = 0;
  int _autoCount = 0;
  int _totalPs = 0;
  int _totalCcm = 0;

  // Erfolge stats
  int _totalLikes = 0;
  double _totalKm = 0;
  int _soldCount = 0;

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
      _loadGarageSummary(),
      _loadAchievementStats(),
      if (!_isOwnProfile) _loadOtherProfile(),
      if (!_isOwnProfile) _checkFollowing(),
    ]);
  }

  Future<void> _loadAchievementStats() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final results = await Future.wait([
        profileRepo.getTotalLikes(userId),
        RideRepository().getRideStats(),
        MarketplaceRepository().getSoldCount(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _totalLikes = results[0] as int;
        final rideStats = results[1] as Map<String, dynamic>;
        _totalKm = (rideStats['totalKm'] as num?)?.toDouble() ?? 0;
        _soldCount = results[2] as int;
      });
    } catch (_) {}
  }

  Future<void> _loadGarageSummary() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('vehicles')
          .select('brand, model, horsepower, displacement_cc, community')
          .eq('user_id', userId);
      if (!mounted) return;
      final vehicles = data as List;
      int ps = 0, ccm = 0, bikes = 0, autos = 0;
      for (final v in vehicles) {
        ps += (v['horsepower'] as num?)?.toInt() ?? 0;
        ccm += (v['displacement_cc'] as num?)?.toInt() ?? 0;
        final comm = v['community'] as String? ?? 'bikergram';
        if (comm == 'motorgram' || comm == 'cargram') {
          autos++;
        } else {
          bikes++;
        }
      }
      setState(() {
        _bikeCount = bikes;
        _autoCount = autos;
        _totalPs = ps;
        _totalCcm = ccm;
      });
    } catch (_) {}
  }

  String get _levelTitle {
    if (_isOwnProfile) {
      final authState = ref.read(authNotifierProvider);
      final level = authState is Authenticated ? authState.user.level : 1;
      return _levelName(level);
    }
    final level = _otherProfile?['level'] ?? 1;
    return _levelName(level);
  }

  static String _levelName(int level) {
    if (level >= 20) return 'Legend';
    if (level >= 15) return 'Veteran';
    if (level >= 10) return 'Pro';
    if (level >= 5) return 'Rider';
    return 'Rookie';
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
      // Refresh following feed so unfollowed user's posts disappear
      if (!result) {
        ref.invalidate(followingFeedProvider);
      }
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

  // ── Tap on stats → show list ──

  void _showUserPosts() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;

    final supabase = Supabase.instance.client;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('posts')
                .select('id, image_url, body, created_at')
                .eq('user_id', userId)
                .order('created_at', ascending: false),
            builder: (ctx, snap) {
              final textCol = isDark ? Colors.white : Colors.black87;
              final subCol = isDark ? Colors.white54 : Colors.black54;

              return Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Beitr\u00e4ge', style: TextStyle(color: textCol, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$_postCount Beitr\u00e4ge', style: TextStyle(color: subCol, fontSize: 13)),
                const SizedBox(height: 12),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                else if (snap.hasError)
                  Padding(padding: const EdgeInsets.all(40), child: Text('Fehler: ${snap.error}', style: TextStyle(color: subCol)))
                else if (!snap.hasData || snap.data!.isEmpty)
                  Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                    Icon(Icons.photo_library_outlined, size: 48, color: subCol),
                    const SizedBox(height: 12),
                    Text('Noch keine Beitr\u00e4ge', style: TextStyle(color: subCol, fontSize: 15)),
                  ]))
                else
                  Expanded(
                    child: GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(2),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: snap.data!.length,
                      itemBuilder: (_, i) {
                        final post = snap.data![i];
                        final imageUrl = post['image_url'] as String?;
                        final caption = post['body'] as String? ?? '';

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            // Navigate to post detail if we have a route
                          },
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                    child: Icon(Icons.broken_image, color: subCol),
                                  ),
                                )
                              : Container(
                                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        caption.length > 60 ? '${caption.substring(0, 60)}...' : caption,
                                        style: TextStyle(color: subCol, fontSize: 11),
                                        textAlign: TextAlign.center,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }

  void _showFollowerList({required bool isFollowers}) async {
    final authState = ref.read(authNotifierProvider);
    final userId = widget.userId ?? (authState is Authenticated ? authState.user.id : null);
    if (userId == null) return;

    final supabase = Supabase.instance.client;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: () async {
              if (isFollowers) {
                // Get followers
                final data = await supabase
                    .from('follows')
                    .select('follower_id, profiles!follows_follower_id_fkey(id, username, avatar_url)')
                    .eq('following_id', userId);
                return (data as List).map((e) => e['profiles'] as Map<String, dynamic>).toList();
              } else {
                // Get following
                final data = await supabase
                    .from('follows')
                    .select('following_id, profiles!follows_following_id_fkey(id, username, avatar_url)')
                    .eq('follower_id', userId);
                return (data as List).map((e) => e['profiles'] as Map<String, dynamic>).toList();
              }
            }(),
            builder: (ctx, snap) {
              final title = isFollowers ? 'Follower' : 'Folge ich';
              final textCol = isDark ? Colors.white : Colors.black87;
              final subCol = isDark ? Colors.white54 : Colors.black54;

              return Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(color: textCol, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                else if (snap.hasError)
                  Padding(padding: const EdgeInsets.all(40), child: Text('Fehler: ${snap.error}', style: TextStyle(color: subCol)))
                else if (!snap.hasData || snap.data!.isEmpty)
                  Padding(padding: const EdgeInsets.all(40), child: Text('Keine $title', style: TextStyle(color: subCol)))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: snap.data!.length,
                      itemBuilder: (_, i) {
                        final user = snap.data![i];
                        final username = user['username'] ?? 'Unbekannt';
                        final avatar = user['avatar_url'] as String?;
                        final uid = user['id'] as String?;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: accentColor.withValues(alpha: 0.2),
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null ? Icon(Icons.person, color: accentColor, size: 22) : null,
                          ),
                          title: Text(username, style: TextStyle(color: textCol, fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.chevron_right, color: subCol),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (uid != null) context.push('/profile/$uid');
                          },
                        );
                      },
                    ),
                  ),
              ]);
            },
          );
        },
      ),
    );
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
    String? postalCode;
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
      postalCode = user?.postalCode;
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
      postalCode = _otherProfile?['postal_code'] as String?;
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
                if (_isOwnProfile && !Navigator.of(context).canPop())
                  // Spacer to push content below the Global Top Bar (tab navigation)
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 48))
                else if (_isOwnProfile && Navigator.of(context).canPop())
                  // Pushed from map/puck: show back button
                  SliverAppBar(
                    floating: true,
                    backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
                    surfaceTintColor: Colors.transparent,
                    leading: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back_rounded,
                          color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
                    ),
                    title: Text('Profil', style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
                      letterSpacing: -0.5,
                    )),
                  )
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
                    actions: const [SizedBox(width: 4)],
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Visitenkarte: Avatar links, Info rechts ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar with accent ring
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: accentColor, width: 2),
                              ),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: avatarUrl == null
                                      ? LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.6)])
                                      : null,
                                ),
                                child: ClipOval(
                                  child: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? Image.network(avatarUrl, width: 80, height: 80, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildInitial(shownName, accentColor))
                                      : _buildInitial(shownName, accentColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Name + Level + Garage
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  // Username
                                  Text(
                                    username,
                                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700,
                                      color: brightness == Brightness.dark ? Colors.white : const Color(0xFF202124)),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  // Spitzname
                                  if (displayName != null && displayName!.isNotEmpty && displayName != username)
                                    Text(
                                      '@$displayName',
                                      style: GoogleFonts.inter(fontSize: 13,
                                        color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6C757D))),
                                    ),
                                  // PLZ
                                  if (postalCode != null && postalCode!.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_rounded, size: 12,
                                          color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white38 : const Color(0xFF9E9E9E))),
                                        const SizedBox(width: 3),
                                        Text(
                                          postalCode!,
                                          style: GoogleFonts.inter(fontSize: 12,
                                            color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white38 : const Color(0xFF9E9E9E))),
                                        ),
                                      ],
                                    ),
                                  // Info (Bio)
                                  if (bio != null && bio!.isNotEmpty)
                                    Text(
                                      bio!,
                                      style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic,
                                        color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white38 : const Color(0xFF9E9E9E))),
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 4),
                                  // Level badge + Badges — compact horizontal row
                                  GestureDetector(
                                    onTap: () => _showLevelAndBadgesSheet(context, level, xp, badges, accentColor),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${community == Community.cargram ? "\u{1F697}" : "\u{1F3CD}"} $_levelTitle \u00b7 Lv.$level',
                                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor),
                                          ),
                                        ),
                                        if (badges.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          ...badges.take(3).map((b) => Padding(
                                            padding: const EdgeInsets.only(right: 1),
                                            child: Text(b.emoji, style: const TextStyle(fontSize: 10)),
                                          )),
                                          if (badges.length > 3)
                                            Text('+${badges.length - 3}', style: GoogleFonts.inter(fontSize: 9, color: accentColor)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // XP + Garage stats as accent chips
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showXpInfoSheet(context, xp, level, accentColor),
                                        child: _miniChip('$xp XP', accentColor, brightness),
                                      ),
                                      GestureDetector(
                                        onTap: () => context.push(_isOwnProfile ? '/garage' : '/garage/${_targetUserId}'),
                                        child: Wrap(
                                          spacing: 4,
                                          children: [
                                            if (_bikeCount > 0)
                                              _miniChip('$_bikeCount ${_bikeCount == 1 ? "Bike" : "Bikes"}', accentColor, brightness),
                                            if (_autoCount > 0)
                                              _miniChip('$_autoCount ${_autoCount == 1 ? "Auto" : "Autos"}', accentColor, brightness),
                                            if (_totalPs > 0)
                                              _miniChip('$_totalPs PS', accentColor, brightness),
                                            if (_totalCcm > 0)
                                              _miniChip('$_totalCcm ccm', accentColor, brightness),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Removed — message button now below as full-width button
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Stats row — flat, Instagram-style ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(child: _ProfileStatBadge(value: '$_postCount', label: 'Beitr\u00e4ge', accentColor: accentColor, onTap: () => _showUserPosts())),
                            Container(width: 1, height: 28, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8EAED)),
                            Expanded(child: _ProfileStatBadge(value: '$_followerCount', label: 'Follower', accentColor: accentColor, onTap: () => _showFollowerList(isFollowers: true))),
                            Container(width: 1, height: 28, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8EAED)),
                            Expanded(child: _ProfileStatBadge(value: '$_followingCount', label: 'Folge ich', accentColor: accentColor, onTap: () => _showFollowerList(isFollowers: false))),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Own Profile ──
                        if (_isOwnProfile) ...[
                          // Edit + Settings row
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                await EditProfileSheet.show(context);
                                ref.read(authNotifierProvider.notifier).checkAuth();
                                _loadStats();
                                _loadGarageSummary();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: accentColor.withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.06),
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text('Profil bearbeiten', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                color: accentColor)),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Quick links
                          _MenuItem(icon: Icons.garage_rounded, label: 'Meine Garage', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/garage')),
                          _MenuItem(icon: Icons.storefront_rounded, label: 'Marktplatz', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/market')),
                          // ── Erfolge (opens fullscreen) ──
                          _MenuItem(icon: Icons.emoji_events_rounded, label: 'Erfolge', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => _openAchievementsScreen(accentColor, brightness, community, xp, level)),
                          _MenuItem(icon: Icons.favorite_rounded, label: 'Mein Date', color: Colors.pinkAccent,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => _openMySwipes(context, ref, accentColor, brightness, community)),
                          _MenuItem(icon: Icons.bookmark_rounded, label: 'Gespeicherte Beiträge', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/saved-posts')),
                          _MenuItem(icon: Icons.archive_rounded, label: 'Archivierte Nachrichten', color: Colors.orange,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/messages')),
                          _MenuItem(icon: Icons.workspace_premium_rounded, label: 'Premium', color: Colors.amber,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () {},
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('PRO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber)),
                            )),

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity, height: 40,
                            child: TextButton(
                              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                              child: Text('Abmelden', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.errorDark)),
                            ),
                          ),
                        ],

                        // ── Other user: Follow + Message + Garage ──
                        if (!_isOwnProfile) ...[
                          // Nachricht schreiben + Folgen/Entfolgen nebeneinander
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: _startConversation,
                                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: accentColor),
                                    label: Text('Nachricht', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: accentColor)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      backgroundColor: accentColor.withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.06),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _isLoadingFollow ? null : _toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing
                                          ? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F3F4))
                                          : accentColor,
                                      foregroundColor: _isFollowing
                                          ? (brightness == Brightness.dark ? Colors.white : const Color(0xFF202124))
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: _isLoadingFollow
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Text(_isFollowing ? 'Entfolgen' : 'Folgen',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          _MenuItem(icon: Icons.garage_rounded, label: 'Garage', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/garage/${_targetUserId}')),
                          _MenuItem(icon: Icons.storefront_rounded, label: 'Marktplatz', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => context.push('/market/${_targetUserId}')),
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

  void _showXpInfoSheet(BuildContext context, int xp, int level, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final xpForNext = (level) * 100;
    final progress = xpForNext > 0 ? (xp / xpForNext) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) {
          final textCol = isDark ? Colors.white : Colors.black87;
          final subCol = isDark ? Colors.white54 : Colors.black54;
          final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);

          return SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),

                // Big XP display
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.2), accentColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('⚡', style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text('$xp', style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, color: accentColor)),
                      Text('Erfahrungspunkte', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: subCol)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Level $level', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: textCol)),
                          Text('Level ${level + 1}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: subCol)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation(accentColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Noch ${(xpForNext - xp).clamp(0, xpForNext)} XP bis ${_levelName(level + 1)}',
                        style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // XP-Abstufung title
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('XP-Abstufung', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: textCol)),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Je 100 XP steigst du ein Level auf', style: GoogleFonts.inter(fontSize: 12, color: subCol)),
                ),
                const SizedBox(height: 16),

                // Tier overview cards
                ...[
                  ('🌱', 'Rookie', 1, 4, '0 – 399 XP', 'Dein Start in die Community'),
                  ('🏍', 'Rider', 5, 9, '400 – 899 XP', 'Du bist aktiv unterwegs!'),
                  ('🔥', 'Pro', 10, 14, '900 – 1.399 XP', 'Respektiertes Community-Mitglied'),
                  ('⭐', 'Veteran', 15, 19, '1.400 – 1.899 XP', 'Erfahrener Fahrer & Kenner'),
                  ('👑', 'Legend', 20, 20, '1.900+ XP', 'Die Legende der Community'),
                ].map((tier) {
                  final isCurrentTier = level >= tier.$3 && level <= tier.$4;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrentTier ? accentColor.withValues(alpha: 0.12) : cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: isCurrentTier ? Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5) : null,
                    ),
                    child: Row(
                      children: [
                        Text(tier.$1, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(tier.$2, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800,
                                    color: isCurrentTier ? accentColor : textCol)),
                                  const SizedBox(width: 8),
                                  Text('Lv. ${tier.$3}–${tier.$4}', style: GoogleFonts.inter(fontSize: 12, color: subCol)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(tier.$5, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                color: isCurrentTier ? accentColor : subCol)),
                              Text(tier.$6, style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                            ],
                          ),
                        ),
                        if (isCurrentTier)
                          Icon(Icons.arrow_right_alt_rounded, color: accentColor, size: 24)
                        else if (level > tier.$4)
                          Icon(Icons.check_circle_rounded, color: accentColor.withValues(alpha: 0.5), size: 20),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLevelAndBadgesSheet(BuildContext context, int level, int xp, List<BadgeInfo> badges, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final xpForNext = level * 100;
    final progress = xp / xpForNext;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) {
          final textCol = isDark ? Colors.white : Colors.black87;
          final subCol = isDark ? Colors.white54 : Colors.black54;
          return SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),

                // Level icon big
                Text(_levelName(level) == 'Legend' ? '\u{1F451}' : _levelName(level) == 'Veteran' ? '\u{2B50}' : _levelName(level) == 'Pro' ? '\u{1F525}' : _levelName(level) == 'Rider' ? '\u{1F3CD}' : '\u{1F331}',
                  style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(_levelName(level), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: accentColor)),
                Text('Level $level', style: GoogleFonts.inter(fontSize: 16, color: subCol)),
                const SizedBox(height: 16),

                // XP Progress bar
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$xp XP', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textCol)),
                        Text('$xpForNext XP', style: GoogleFonts.inter(fontSize: 12, color: subCol)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(accentColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Noch ${(xpForNext - xp).clamp(0, xpForNext)} XP bis Level ${level + 1}',
                      style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                  ],
                ),

                const SizedBox(height: 28),

                // All badges
                if (badges.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Erfahrungs-Badges', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textCol)),
                  ),
                  const SizedBox(height: 16),
                  ...badges.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: b.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: b.color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Text(b.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: b.color)),
                                const SizedBox(height: 2),
                                Text(
                                  switch (b.category) {
                                    'moto' => 'Motorrad-Erfahrung',
                                    'car' => 'Auto-Erfahrung',
                                    'age' => 'Alters-Badge',
                                    'track' => 'Rennstrecken-Erfahrung',
                                    _ => 'Badge',
                                  },
                                  style: GoogleFonts.inter(fontSize: 12, color: subCol),
                                ),
                                if (b.years != null)
                                  Text('${b.years} Jahre Erfahrung', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: b.color)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ] else ...[
                  const SizedBox(height: 20),
                  Icon(Icons.emoji_events_outlined, size: 48, color: subCol),
                  const SizedBox(height: 12),
                  Text('Noch keine Badges', style: GoogleFonts.inter(fontSize: 15, color: subCol)),
                  const SizedBox(height: 4),
                  Text('Vervollst\u00e4ndige dein Profil um Badges zu erhalten', style: GoogleFonts.inter(fontSize: 12, color: subCol), textAlign: TextAlign.center),
                ],

                // Level overview — individual XP steps
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Level-Stufen', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textCol)),
                ),
                const SizedBox(height: 12),

                // Tier headers with individual levels
                ...List.generate(20, (i) {
                  final lv = i + 1;
                  final xpMin = i * 100;
                  final xpMax = xpMin + 99;
                  final isCurrent = lv == level;
                  final isReached = lv <= level;
                  final tierEmoji = lv >= 20 ? '\u{1F451}' : lv >= 15 ? '\u{2B50}' : lv >= 10 ? '\u{1F525}' : lv >= 5 ? '\u{1F3CD}' : '\u{1F331}';
                  final tierName = lv >= 20 ? 'Legend' : lv >= 15 ? 'Veteran' : lv >= 10 ? 'Pro' : lv >= 5 ? 'Rider' : 'Rookie';
                  // Show tier header at tier boundaries
                  final showTierHeader = lv == 1 || lv == 5 || lv == 10 || lv == 15 || lv == 20;

                  return Column(
                    children: [
                      if (showTierHeader) ...[
                        if (lv > 1) const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(tierEmoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(tierName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isReached ? accentColor : subCol)),
                            ],
                          ),
                        ),
                      ],
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? accentColor.withValues(alpha: 0.15)
                              : isReached
                                  ? accentColor.withValues(alpha: 0.05)
                                  : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent ? Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5) : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text('Lv.$lv', style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                color: isCurrent ? accentColor : isReached ? textCol : subCol,
                              )),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$xpMin – $xpMax XP', style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                                    color: isCurrent ? textCol : subCol,
                                  )),
                                  if (isCurrent)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ((xp - xpMin) / 100).clamp(0.0, 1.0),
                                          minHeight: 6,
                                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                          valueColor: AlwaysStoppedAnimation(accentColor),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Icon(Icons.arrow_right_rounded, size: 22, color: accentColor)
                            else if (isReached)
                              Icon(Icons.check_circle_rounded, size: 16, color: accentColor.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
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

  void _openAchievementsScreen(Color accentColor, Brightness brightness, Community? community, int xp, int level) {
    final isDark = brightness == Brightness.dark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final scaffoldBg = community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5));
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF6C757D);
    final levelName = XpCalculator.levelName(level);
    // Level = xp ~/ 100 + 1, so xpForLevel(n) = (n-1) * 100
    final xpForNext = level * 100; // XP needed for level+1
    final xpForCurrent = (level - 1) * 100;
    final xpProgress = xpForNext > xpForCurrent ? (xp - xpForCurrent) / (xpForNext - xpForCurrent) : 1.0;

    final items = [
      _AchievementTile(icon: Icons.emoji_events_rounded, color: accentColor, value: '$levelName $level', label: 'Level', numericValue: level.toDouble(), maxValue: 50),
      _AchievementTile(icon: Icons.star_rounded, color: Colors.amber, value: '$xp / $xpForNext XP', label: 'XP bis n\u00e4chstes Level', numericValue: xpProgress, maxValue: 1),
      _AchievementTile(icon: Icons.favorite_rounded, color: Colors.red, value: '$_totalLikes', label: 'Gesamtlikes', numericValue: _totalLikes.toDouble(), maxValue: (_totalLikes > 0 ? _totalLikes * 2 : 100).toDouble()),
      _AchievementTile(icon: Icons.speed_rounded, color: Colors.orange, value: '$_totalPs PS', label: 'PS gesamt', numericValue: _totalPs.toDouble(), maxValue: (_totalPs > 0 ? _totalPs * 1.5 : 500).toDouble()),
      _AchievementTile(icon: Icons.settings_rounded, color: Colors.blueGrey, value: '$_totalCcm ccm', label: 'CCM gesamt', numericValue: _totalCcm.toDouble(), maxValue: (_totalCcm > 0 ? _totalCcm * 1.5 : 2000).toDouble()),
      _AchievementTile(icon: Icons.route_rounded, color: Colors.green, value: '${_totalKm.toStringAsFixed(1)} km', label: 'Gefahrene km', numericValue: _totalKm, maxValue: _totalKm > 0 ? _totalKm * 1.5 : 1000),
      _AchievementTile(icon: Icons.sell_rounded, color: Colors.teal, value: '$_soldCount', label: 'Verkaufte Artikel', numericValue: _soldCount.toDouble(), maxValue: (_soldCount > 0 ? _soldCount * 2 : 10).toDouble()),
    ];

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: cardBg,
          title: Text('Statistiken', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textColor)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0,
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final item = items[i];
            final progress = (item.numericValue / item.maxValue).clamp(0.0, 1.0);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 22, color: item.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.label, style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                      ),
                      Text(item.value, style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800, color: item.color)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, val, __) => LinearProgressIndicator(
                        value: val,
                        minHeight: 8,
                        backgroundColor: item.color.withValues(alpha: isDark ? 0.12 : 0.08),
                        valueColor: AlwaysStoppedAnimation(item.color),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ));
  }

  Widget _buildAchievementsGrid(Color accentColor, Brightness brightness, Community? community, int xp, int level) {
    final isDark = brightness == Brightness.dark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF6C757D);
    final levelName = XpCalculator.levelName(level);

    final items = <_AchievementTile>[
      _AchievementTile(icon: Icons.favorite_rounded, color: Colors.red, value: '$_totalLikes', label: 'Gesamtlikes'),
      _AchievementTile(icon: Icons.star_rounded, color: Colors.amber, value: '$xp', label: 'XP'),
      _AchievementTile(icon: Icons.emoji_events_rounded, color: accentColor, value: '$levelName $level', label: 'Level'),
      _AchievementTile(icon: Icons.speed_rounded, color: Colors.orange, value: '$_totalPs', label: 'PS gesamt'),
      _AchievementTile(icon: Icons.settings_rounded, color: Colors.blueGrey, value: '$_totalCcm', label: 'CCM gesamt'),
      _AchievementTile(icon: Icons.route_rounded, color: Colors.green, value: '${_totalKm.toStringAsFixed(1)} km', label: 'Gefahrene km'),
      _AchievementTile(icon: Icons.sell_rounded, color: Colors.teal, value: '$_soldCount', label: 'Verkauft'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.8,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: item.color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.value, style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(item.label, style: GoogleFonts.inter(
                    fontSize: 10, color: subColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // ── "Mein Date" — Swipe-Historie Overlay ──
  void _openMySwipes(BuildContext context, WidgetRef ref, Color accentColor, Brightness brightness, Community? community) {
    final isDark = brightness == Brightness.dark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final scaffoldBg = community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5));
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => _MySwipesScreen(
        userId: uid,
        accentColor: accentColor,
        cardBg: cardBg,
        scaffoldBg: scaffoldBg,
        textColor: textColor,
        mutedColor: mutedColor,
        community: community,
      ),
    ));
  }

  Widget _miniChip(String text, Color accent, Brightness brightness) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: brightness == Brightness.dark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
      ),
    );
  }

  Widget _buildInitial(String name, Color accentColor) {
    return Container(
      width: 80,
      height: 80,
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

class _ProfileStatBadge extends StatelessWidget {
  const _ProfileStatBadge({
    required this.value,
    required this.label,
    required this.accentColor,
    this.onTap,
  });

  final String value;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mutedColor = brightness == Brightness.dark
        ? const Color(0xFF9AA0A6)
        : const Color(0xFF5F6368);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
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
    final isDark = brightness == Brightness.dark;
    final iconColor = isDark ? color : const Color(0xFF5F6368);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: isDark ? 0.10 : 0.06),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF202124),
          ),
        ),
        trailing: trailing ??
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFBDC1C6), size: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _AchievementTile {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final double numericValue; // for bar chart scaling
  final double maxValue; // max for this stat category
  const _AchievementTile({required this.icon, required this.color, required this.value, required this.label, this.numericValue = 0, this.maxValue = 100});
}

// ══════════════════════════════════════════════════════════════════════════════
// ❤️  Mein Date — Swipe-Historie (Likes & Nopes)
// ══════════════════════════════════════════════════════════════════════════════

class _MySwipesScreen extends StatefulWidget {
  const _MySwipesScreen({
    required this.userId,
    required this.accentColor,
    required this.cardBg,
    required this.scaffoldBg,
    required this.textColor,
    required this.mutedColor,
    this.community,
  });

  final String userId;
  final Color accentColor;
  final Color cardBg;
  final Color scaffoldBg;
  final Color textColor;
  final Color mutedColor;
  final Community? community;

  @override
  State<_MySwipesScreen> createState() => _MySwipesScreenState();
}

class _MySwipesScreenState extends State<_MySwipesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _likes = [];
  List<Map<String, dynamic>> _nopes = [];
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final sb = Supabase.instance.client;
      final communityName = widget.community?.name ?? 'bikergram';

      // Likes (ich habe geliked)
      final likesRes = await sb
          .from('profile_swipes')
          .select('swiped_id, created_at')
          .eq('swiper_id', widget.userId)
          .eq('community', communityName)
          .eq('is_like', true)
          .order('created_at', ascending: false)
          .limit(100);

      // Nopes (ich habe abgelehnt)
      final nopesRes = await sb
          .from('profile_swipes')
          .select('swiped_id, created_at')
          .eq('swiper_id', widget.userId)
          .eq('community', communityName)
          .eq('is_like', false)
          .order('created_at', ascending: false)
          .limit(100);

      // Matches
      final matchesRes = await sb
          .from('matches')
          .select('user1_id, user2_id, conversation_id, created_at')
          .or('user1_id.eq.${widget.userId},user2_id.eq.${widget.userId}')
          .eq('community', communityName)
          .order('created_at', ascending: false)
          .limit(100);

      // Gather all user IDs to fetch profiles
      final allIds = <String>{};
      for (final r in likesRes) allIds.add(r['swiped_id'] as String);
      for (final r in nopesRes) allIds.add(r['swiped_id'] as String);
      for (final r in matchesRes) {
        allIds.add(r['user1_id'] as String);
        allIds.add(r['user2_id'] as String);
      }
      allIds.remove(widget.userId);

      Map<String, Map<String, dynamic>> profileMap = {};
      if (allIds.isNotEmpty) {
        final profiles = await sb
            .from('profiles')
            .select('id, username, display_name, bikername, avatar_url, avatar_url_cargram, birth_year')
            .inFilter('id', allIds.toList());
        for (final p in profiles) {
          profileMap[p['id'] as String] = p;
        }
      }

      if (!mounted) return;
      setState(() {
        _likes = likesRes.map((r) {
          final p = profileMap[r['swiped_id']] ?? {};
          return {...p, 'swipe_date': r['created_at']};
        }).toList();

        _nopes = nopesRes.map((r) {
          final p = profileMap[r['swiped_id']] ?? {};
          return {...p, 'swipe_date': r['created_at']};
        }).toList();

        _matches = matchesRes.map((r) {
          final otherId = r['user1_id'] == widget.userId
              ? r['user2_id'] as String
              : r['user1_id'] as String;
          final p = profileMap[otherId] ?? {};
          return {...p, 'conversation_id': r['conversation_id'], 'match_date': r['created_at']};
        }).toList();

        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.scaffoldBg,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: widget.cardBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: widget.textColor,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: widget.textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Mein Date',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: widget.textColor,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: widget.accentColor,
          labelColor: widget.accentColor,
          unselectedLabelColor: widget.mutedColor,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: '❤️ Likes (${_likes.length})'),
            Tab(text: '🔥 Matches (${_matches.length})'),
            Tab(text: '✕ Nope (${_nopes.length})'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: widget.accentColor))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(_likes, isLikes: true),
                _buildList(_matches, isMatches: true),
                _buildList(_nopes, isNopes: true),
              ],
            ),
    );
  }

  /// Confirm deletion dialog
  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eintrag löschen?', style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: widget.textColor,
        )),
        content: Text(
          '$name aus der Liste entfernen?',
          style: GoogleFonts.inter(color: widget.mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen', style: GoogleFonts.inter(color: widget.mutedColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Löschen', style: GoogleFonts.inter(
              color: Colors.red, fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }

  /// Delete an entry from any tab (likes, matches, nopes)
  Future<void> _deleteEntry(Map<String, dynamic> item, {
    required bool isLikes, required bool isMatches, required bool isNopes, required int index,
  }) async {
    final targetId = item['id'] as String?;
    if (targetId == null) return;
    final communityName = widget.community?.name ?? 'bikergram';
    final sb = Supabase.instance.client;

    try {
      if (isLikes || isNopes) {
        // Delete swipe record
        await sb.from('profile_swipes').delete()
            .eq('swiper_id', widget.userId)
            .eq('swiped_id', targetId)
            .eq('community', communityName);
        setState(() {
          if (isLikes) _likes.removeAt(index);
          if (isNopes) _nopes.removeAt(index);
        });
      } else if (isMatches) {
        // Delete match record — need to match the pair in either order
        // (user1=me,user2=target) OR (user1=target,user2=me)
        await sb.from('matches').delete()
            .or('and(user1_id.eq.${widget.userId},user2_id.eq.$targetId),and(user1_id.eq.$targetId,user2_id.eq.${widget.userId})')
            .eq('community', communityName);
        // Also remove my swipe so the user can reappear
        await sb.from('profile_swipes').delete()
            .eq('swiper_id', widget.userId)
            .eq('swiped_id', targetId)
            .eq('community', communityName);
        setState(() => _matches.removeAt(index));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eintrag gelöscht'),
            backgroundColor: Colors.red.withValues(alpha: 0.9),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  /// Dislike (remove a like) or Entnope (change nope → like)
  Future<void> _handleSwipeAction(Map<String, dynamic> item, {required bool isLikes, required int index}) async {
    final swipedId = item['id'] as String?;
    if (swipedId == null) return;
    final communityName = widget.community?.name ?? 'bikergram';
    final sb = Supabase.instance.client;

    try {
      if (isLikes) {
        // Dislike: delete the swipe record
        await sb
            .from('profile_swipes')
            .delete()
            .eq('swiper_id', widget.userId)
            .eq('swiped_id', swipedId)
            .eq('community', communityName);
        setState(() => _likes.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Like zurückgenommen'),
              backgroundColor: Colors.red.withValues(alpha: 0.9),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Entnope: update is_like from false → true (second chance!)
        await sb
            .from('profile_swipes')
            .update({'is_like': true})
            .eq('swiper_id', widget.userId)
            .eq('swiped_id', swipedId)
            .eq('community', communityName);
        // Move from nopes to likes
        final moved = _nopes.removeAt(index);
        setState(() => _likes.insert(0, moved));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❤️ Zweite Chance! Like gesendet'),
              backgroundColor: Colors.green.withValues(alpha: 0.9),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Widget _buildList(List<Map<String, dynamic>> items, {bool isLikes = false, bool isMatches = false, bool isNopes = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMatches ? Icons.local_fire_department_rounded
                  : isLikes ? Icons.favorite_outline_rounded
                  : Icons.close_rounded,
              size: 56,
              color: widget.mutedColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              isMatches ? 'Noch keine Matches' : isLikes ? 'Noch keine Likes' : 'Noch keine Nopes',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: widget.mutedColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final name = item['display_name'] ?? item['bikername'] ?? item['username'] ?? '?';
        final avatarUrl = widget.community == Community.cargram
            ? (item['avatar_url_cargram'] ?? item['avatar_url'])
            : item['avatar_url'];
        final birthYear = item['birth_year'] as int?;
        final age = birthYear != null ? DateTime.now().year - birthYear : null;
        final convId = item['conversation_id'];
        final itemId = item['id'] as String? ?? '$i';

        return Dismissible(
          key: ValueKey('${isLikes ? 'like' : isMatches ? 'match' : 'nope'}_$itemId'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 6),
                Text('Löschen', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                )),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            return await _confirmDelete(context, name);
          },
          onDismissed: (_) => _deleteEntry(item, isLikes: isLikes, isMatches: isMatches, isNopes: isNopes, index: i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (isMatches && convId != null) {
                    Navigator.pop(context);
                    GoRouter.of(context).push('/messages/$convId');
                  } else {
                    final userId = item['id'] as String?;
                    if (userId != null) {
                      Navigator.pop(context);
                      GoRouter.of(context).push('/profile/$userId');
                    }
                  }
                },
                onLongPress: () async {
                  final confirmed = await _confirmDelete(context, name);
                  if (confirmed == true) {
                    _deleteEntry(item, isLikes: isLikes, isMatches: isMatches, isNopes: isNopes, index: i);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                        backgroundImage: avatarUrl != null && (avatarUrl as String).isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null || (avatarUrl as String).isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: widget.accentColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      // Name + Age
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: widget.textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (age != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '$age',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: widget.mutedColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              isMatches ? '💬 Nachricht schreiben'
                                  : isLikes ? '← Wischen zum Löschen'
                                  : '← Wischen zum Löschen',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isMatches ? widget.accentColor : widget.mutedColor.withValues(alpha: 0.6),
                                fontWeight: isMatches ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Action button: Dislike / Entnope / Match icon
                      if (isLikes || isNopes)
                        GestureDetector(
                          onTap: () => _handleSwipeAction(item, isLikes: isLikes, index: i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isLikes
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLikes
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLikes ? Icons.heart_broken_rounded : Icons.favorite_rounded,
                                  size: 16,
                                  color: isLikes ? Colors.red : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLikes ? 'Dislike' : 'Entnope',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isLikes ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Icon(Icons.local_fire_department_rounded,
                            color: Colors.orange, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
