import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/community.dart';
import '../../domain/xp_calculator.dart';
import '../widgets/online_status_avatar.dart';
import '../../domain/badge_calculator.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../providers/feed/feed_notifier.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../domain/models/post.dart';
import '../../providers/dating/dating_notifier.dart';
import '../../providers/marketplace/marketplace_notifier.dart';
import '../../providers/messages/messages_notifier.dart';
import '../feed/widgets/comments_sheet.dart';
import '../feed/widgets/post_card.dart';
import '../../data/repositories/ride_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../dating/widgets/swipe_card.dart';
import '../../theme/app_theme.dart';
import '../widgets/immersive_scroll_wrapper.dart';
import 'widgets/edit_profile_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId, this.showDatingCard = false});

  /// If null, shows the current user's own profile.
  /// If set, shows another user's profile.
  final String? userId;

  /// If true, automatically opens the dating card preview after loading.
  final bool showDatingCard;

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

  // Dating stats
  int _matchCount = 0;
  int _likeReceivedCount = 0;
  bool _datingActive = false;
  bool _hasAlreadySwiped = false;
  List<String> _datingPhotos = [];
  List<Map<String, dynamic>> _datingVehicles = [];

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
      _loadDatingStats(),
      if (!_isOwnProfile) _loadOtherProfile(),
      if (!_isOwnProfile) _checkFollowing(),
    ]);

    // Auto-open dating card preview if requested (from notification deep link)
    if (widget.showDatingCard && _datingActive && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final community = ref.read(communityProvider);
        final brightness = Theme.of(context).brightness;
        final authState = ref.read(authNotifierProvider);
        String username = 'User';
        String? displayName, avatarUrl, bio;
        int? birthYear;
        int xp = 0;

        if (_isOwnProfile && authState is Authenticated) {
          final user = authState.user;
          username = user.username;
          displayName = user.displayName;
          avatarUrl = user.avatarUrl;
          bio = user.bio;
          birthYear = user.birthYear;
          xp = user.xpTotal ?? 0;
        } else {
          username = _otherProfile?['username'] ?? 'User';
          displayName = _otherProfile?['display_name'];
          avatarUrl = _otherProfile?['avatar_url'];
          bio = _otherProfile?['bio'];
          birthYear = _otherProfile?['birth_year'] as int?;
          xp = _otherProfile?['xp_total'] ?? 0;
        }

        // Check for recent match — show heart rain if match within last 10 minutes
        try {
          final sb = Supabase.instance.client;
          final myId = sb.auth.currentUser?.id;
          final targetId = _targetUserId;
          if (myId != null && targetId.isNotEmpty) {
            final match = await sb.from('matches').select('id, conversation_id, created_at')
                .or('and(user1_id.eq.$myId,user2_id.eq.$targetId),and(user1_id.eq.$targetId,user2_id.eq.$myId)')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (match != null && mounted) {
              final createdAt = DateTime.tryParse(match['created_at'] as String? ?? '');
              if (createdAt != null && DateTime.now().toUtc().difference(createdAt).inMinutes <= 10) {
                _showMatchCelebration({'matched_avatar_url': avatarUrl, 'conversation_id': match['conversation_id'], 'matched_user_id': targetId});
                return; // Don't also show the card preview
              }
            }
          }
        } catch (e) {
          debugPrint('[Dating] Match check error: $e');
        }

        if (!mounted) return;
        _showDatingCardPreview(
          community: community,
          username: username,
          displayName: displayName,
          avatarUrl: avatarUrl,
          bio: bio,
          birthYear: birthYear,
          xp: xp,
        );
      });
    }
  }

  Future<void> _loadAchievementStats() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;
    final profileRepo = ref.read(profileRepositoryProvider);

    try {
      final likes = await profileRepo.getTotalLikes(userId);
      if (mounted) setState(() => _totalLikes = likes);
    } catch (_) {}

    try {
      // RLS: rides only readable by owner → for other profiles, use their userId
      // but RLS will return empty. For own profile, omit forUserId (uses current user).
      final rideStats = _isOwnProfile
          ? await RideRepository().getRideStats()
          : await RideRepository().getRideStats(forUserId: userId);
      debugPrint('[Stats] rideStats for $userId (own=$_isOwnProfile) = $rideStats');
      if (mounted) setState(() => _totalKm = (rideStats['totalKm'] as num?)?.toDouble() ?? 0);
    } catch (e) {
      debugPrint('[Stats] getRideStats ERROR: $e');
    }

    try {
      final sold = await MarketplaceRepository().getSoldCount(userId);
      debugPrint('[Stats] soldCount for $userId = $sold');
      if (mounted) setState(() => _soldCount = sold);
    } catch (e) {
      debugPrint('[Stats] getSoldCount ERROR: $e');
    }
  }

  Future<void> _loadDatingStats() async {
    final userId = _targetUserId;
    debugPrint('[Dating] _loadDatingStats called for userId=$userId');
    if (userId.isEmpty) return;
    final sb = Supabase.instance.client;

    // Load dating photos from profile (independent of matches/swipes)
    try {
      final profile = await sb.from('profiles').select('dating_photos,dating_tos_accepted_at').eq('id', userId).maybeSingle();
      if (!mounted) return;
      final photos = profile?['dating_photos'];
      setState(() {
        _datingActive = profile?['dating_tos_accepted_at'] != null;
        if (photos is List && photos.isNotEmpty) {
          _datingPhotos = List<String>.from(photos);
        }
      });
      debugPrint('[Dating] photos loaded, datingActive=$_datingActive');
    } catch (e) {
      debugPrint('[Dating] Photos error: $e');
    }

    // Load match/like counts
    try {
      final matches = await sb.from('matches').select('id').or('user1_id.eq.$userId,user2_id.eq.$userId');
      debugPrint('[Dating] matches query OK: ${(matches as List).length}');
      final communityName = ref.read(communityProvider)?.name ?? 'bikergram';
      final likes = await sb.from('profile_swipes').select('id').eq('swiped_id', userId).eq('is_like', true);
      debugPrint('[Dating] likes query OK: ${(likes as List).length}');
      if (!mounted) return;
      // Likes received = direct likes + matches (match implies partner liked you, swipe may be consumed by RPC)
      final totalLikesReceived = (likes as List).length + matches.length;
      setState(() {
        _matchCount = matches.length;
        _likeReceivedCount = totalLikesReceived;
      });
      debugPrint('[Dating] SET matchCount=$_matchCount likeReceivedCount=$_likeReceivedCount');

      // Check if current user already swiped on this profile
      if (!_isOwnProfile) {
        final myId = sb.auth.currentUser?.id;
        if (myId != null) {
          final existingSwipe = await sb.from('profile_swipes')
              .select('id')
              .eq('swiper_id', myId)
              .eq('swiped_id', userId)
              .eq('community', communityName)
              .maybeSingle();
          if (mounted) {
            setState(() => _hasAlreadySwiped = existingSwipe != null);
          }
          debugPrint('[Dating] hasAlreadySwiped=$_hasAlreadySwiped');
        }
      }
    } catch (e) {
      debugPrint('[Dating] Stats error: $e');
    }
  }

  Future<void> _loadDatingVehicles() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;
    try {
      final sb = Supabase.instance.client;
      final profile = await sb.from('profiles').select('dating_vehicle_ids').eq('id', userId).maybeSingle();
      final rawIds = profile?['dating_vehicle_ids'] as List?;
      if (rawIds == null || rawIds.isEmpty) return;
      final ids = rawIds.map((e) => e as int).toSet();
      final vehicles = await VehicleRepository().getMyVehicles(userId: userId);
      if (!mounted) return;
      setState(() {
        _datingVehicles = vehicles.where((v) => ids.contains(v.id)).map((v) => <String, dynamic>{
          'brand': v.brand,
          'model': v.model,
          'horsepower': v.horsepower,
          'community': v.community,
        }).toList();
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
                            context.push('/post/${post['id']}');
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
    int? birthYear;
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
      birthYear = user?.birthYear;
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
      birthYear = _otherProfile?['birth_year'] as int?;
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
          : ImmersiveScrollWrapper(child: CustomScrollView(
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
                            // Avatar with online status ring
                            OnlineStatusAvatar(
                              userId: _targetUserId,
                              avatarUrl: avatarUrl,
                              size: 86,
                              borderWidth: 3.0,
                              fallbackIcon: _buildInitial(shownName, accentColor),
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
                                        onTap: () => _showXpInfoSheet(context, xp, level, accentColor, badges),
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

                        // ── LOVO/DATE Section (18+ only) ──
                        if (birthYear != null && (DateTime.now().year - birthYear) >= 18) ...[
                          const SizedBox(height: 12),
                          _buildDatingSection(
                            accentColor: accentColor,
                            brightness: brightness,
                            community: community,
                            username: username,
                            displayName: displayName,
                            avatarUrl: avatarUrl,
                            bio: bio,
                            birthYear: birthYear,
                            xp: xp,
                          ),
                        ],

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
                          if (birthYear != null && (DateTime.now().year - birthYear) >= 18)
                            _MenuItem(icon: Icons.favorite_rounded, label: 'Mein Date', color: Colors.pinkAccent,
                              cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                              onTap: () => _openMySwipes(context, ref, accentColor, brightness, community)),
                          _MenuItem(icon: Icons.archive_rounded, label: 'Mein Archiv', color: Colors.orange,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => _openArchiveScreen(accentColor, brightness, community)),
                          _MenuItem(icon: Icons.workspace_premium_rounded, label: 'Premium', color: Colors.amber,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => _showPremiumSheet(accentColor, brightness),
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
                          _MenuItem(icon: Icons.emoji_events_rounded, label: 'Erfolge', color: accentColor,
                            cardColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                            onTap: () => _openAchievementsScreen(accentColor, brightness, community, xp, level)),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            )),
    );
  }

  Widget _buildDatingSection({
    required Color accentColor,
    required Brightness brightness,
    required Community? community,
    required String username,
    required String? displayName,
    required String? avatarUrl,
    required String? bio,
    required int? birthYear,
    required int xp,
  }) {
    final isDark = brightness == Brightness.dark;
    final cardColor = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.pinkAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tap to go to Dating platform
          GestureDetector(
            onTap: () {
              // Navigate to Feed Dating tab (tab index 4)
              context.go('/feed');
              // Use a small delay so the feed loads, then switch to dating tab
              Future.delayed(const Duration(milliseconds: 200), () {
                // The FeedScreen listens for this — we'll pass via extra or just navigate
              });
            },
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, size: 18, color: Colors.pinkAccent),
                const SizedBox(width: 6),
                Text(
                  'LOVO',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.pinkAccent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: 12, color: Colors.pinkAccent.withValues(alpha: 0.5)),
                const Spacer(),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Aktiv',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Stats chips — tappable to open Mein Date
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GestureDetector(
                onTap: () => _openMatchesList(accentColor, brightness, community),
                child: _datingChip('$_matchCount', 'Matches', Icons.people_rounded, Colors.pinkAccent),
              ),
              GestureDetector(
                onTap: () => _openReceivedLikes(accentColor, brightness, community),
                child: _datingChip('$_likeReceivedCount', 'Likes', Icons.favorite_border_rounded, Colors.redAccent),
              ),
            ],
          ),
          // Card preview button
          ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDatingCardPreview(
                  community: community,
                  username: username,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  bio: bio,
                  birthYear: birthYear,
                  xp: xp,
                ),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: Text(_isOwnProfile ? 'Vorschau deiner Karte' : 'Dating-Karte ansehen', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.pinkAccent,
                  side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _datingChip(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  void _showDatingCardPreview({
    required Community? community,
    required String username,
    required String? displayName,
    required String? avatarUrl,
    required String? bio,
    required int? birthYear,
    required int xp,
  }) async {
    // Load vehicles if not yet loaded
    if (_datingVehicles.isEmpty) {
      await _loadDatingVehicles();
    }

    final authState = ref.read(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;

    final previewCandidate = <String, dynamic>{
      'display_name': displayName ?? username,
      'bio': bio,
      'birth_year': birthYear,
      'dating_photos': _datingPhotos,
      'avatar_url': avatarUrl,
      'xp_total': xp,
      'is_premium': user?.isPremium ?? false,
      'dating_vehicles': _datingVehicles,
      'total_feed_likes': _totalLikes,
    };

    if (!mounted) return;
    final isOwn = _isOwnProfile;
    final targetId = _targetUserId;
    showDialog(
      context: context,
      builder: (dCtx) {
        final screenH = MediaQuery.of(dCtx).size.height;
        final maxCardH = screenH - 200; // Leave room for buttons + padding
        return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOwn && !_hasAlreadySwiped)
              Dismissible(
                key: const ValueKey('dating_preview_swipe'),
                direction: DismissDirection.horizontal,
                dismissThresholds: const {DismissDirection.startToEnd: 0.3, DismissDirection.endToStart: 0.3},
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 48),
                    Text('LIKE', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.pinkAccent)),
                  ]),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.close_rounded, color: Colors.red, size: 48),
                    Text('NOPE', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red)),
                  ]),
                ),
                confirmDismiss: (direction) async {
                  final isLike = direction == DismissDirection.startToEnd;
                  try {
                    final notifier = ref.read(datingNotifierProvider.notifier);
                    await notifier.swipe(
                      swipedId: targetId,
                      isLike: isLike,
                      community: community?.name ?? 'bikergram',
                      matchedAvatarUrl: isLike ? avatarUrl : null,
                    );
                    if (isLike) {
                      final dState = ref.read(datingNotifierProvider);
                      if (dState.lastMatch != null && mounted) {
                        final matchData = dState.lastMatch!;
                        ref.read(datingNotifierProvider.notifier).clearMatch();
                        Navigator.pop(dCtx);
                        _showMatchCelebration(matchData);
                        _loadDatingStats();
                        return false;
                      }
                    }
                    _loadDatingStats();
                  } catch (_) {}
                  return true; // dismiss the card
                },
                onDismissed: (direction) {
                  Navigator.pop(dCtx);
                  final isLike = direction == DismissDirection.startToEnd;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isLike ? '❤️ Like gesendet!' : '✕ Nope'),
                      backgroundColor: isLike ? Colors.pinkAccent : Colors.grey.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ));
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxCardH),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 0.65,
                      child: SwipeCard(
                        candidate: previewCandidate,
                        community: community ?? Community.bikergram,
                      ),
                    ),
                  ),
                ),
              ),
            if (isOwn || _hasAlreadySwiped)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxCardH),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 0.65,
                    child: SwipeCard(
                      candidate: previewCandidate,
                      community: community ?? Community.bikergram,
                    ),
                  ),
                ),
              ),
            if (_hasAlreadySwiped && !isOwn) ...[
              const SizedBox(height: 12),
              Text('✓ Bereits bewertet', style: GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
            ],
            // Like/Nope buttons (only for other users who haven't been swiped yet)
            if (!isOwn && !_hasAlreadySwiped) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nope
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(dCtx);
                      try {
                        final notifier = ref.read(datingNotifierProvider.notifier);
                        await notifier.swipe(
                          swipedId: targetId,
                          isLike: false,
                          community: community?.name ?? 'bikergram',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('✕ Nope'),
                            backgroundColor: Colors.grey.shade700,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ));
                        }
                      } catch (_) {}
                    },
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.red, size: 36),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Like
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(dCtx);
                      try {
                        final notifier = ref.read(datingNotifierProvider.notifier);
                        await notifier.swipe(
                          swipedId: targetId,
                          isLike: true,
                          community: community?.name ?? 'bikergram',
                          matchedAvatarUrl: avatarUrl,
                        );
                        // Check if match happened via state
                        final dState = ref.read(datingNotifierProvider);
                        if (dState.lastMatch != null && mounted) {
                          final matchData = dState.lastMatch!;
                          ref.read(datingNotifierProvider.notifier).clearMatch();
                          _showMatchCelebration(matchData);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('❤️ Like gesendet!'),
                            backgroundColor: Colors.pinkAccent,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ));
                        }
                        // Reload dating stats to update counts
                        _loadDatingStats();
                      } catch (_) {}
                    },
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 36),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      );
      },
    );
  }

  /// Heart-shaped particle path
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

  void _showMatchCelebration(Map<String, dynamic> matchResult) {
    final confettiCtrl = ConfettiController(duration: const Duration(seconds: 12));
    confettiCtrl.play();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final convId = matchResult['conversation_id'];
    // Use matched_user_id from result, fallback to _targetUserId (when on other's profile)
    final matchedUserId = (matchResult['matched_user_id'] as String?) ?? _targetUserId;
    debugPrint('[Match] celebration: convId=$convId matchedUserId=$matchedUserId targetUserId=$_targetUserId');
    final community = ref.read(communityProvider);
    final msgCtrl = TextEditingController();

    // Resolve conversation ID — IMMER client-seitig holen, Server-ID ist unzuverlässig!
    int? _resolvedChatId;
    Future<int?> _getChatId() async {
      if (_resolvedChatId != null) return _resolvedChatId!;

      debugPrint('[Match] _getChatId: convId=$convId matchedUserId=$matchedUserId');

      // ⚠️ Server-convId NICHT vertrauen — kann falsche Teilnehmer haben!
      // Stattdessen IMMER client-seitig die korrekte Konversation holen:
      if (matchedUserId.isNotEmpty) {
        try {
          _resolvedChatId = await MessageRepository()
              .getOrCreateConversation(matchedUserId, community: community?.name);
          debugPrint('[Match] ✓ Client convId: $_resolvedChatId (matchedUserId=$matchedUserId)');
          return _resolvedChatId!;
        } catch (e) {
          debugPrint('[Match] ✗ getOrCreateConversation failed: $e');
        }
      }

      // Fallback: convId aus matchResult wenn vorhanden (nur als letzter Ausweg)
      if (convId != null) {
        final parsed = convId is int ? convId : int.tryParse(convId.toString());
        if (parsed != null && parsed > 0) {
          _resolvedChatId = parsed;
          debugPrint('[Match] ⚠️ Fallback auf Server-convId: $_resolvedChatId');
          return _resolvedChatId!;
        }
      }

      debugPrint('[Match] ✗ KEIN conversation_id gefunden!');
      return null;
    }

    // Quick-send emoji/text to the match chat → then navigate to chat
    Future<void> sendQuickMsg(String text, BuildContext ctx) async {
      try {
        final chatId = await _getChatId();
        if (chatId == null) {
          debugPrint('[Match] ✗ Kein Chat-ID — Nachricht NICHT gesendet');
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
              content: Text('⚠️ Chat konnte nicht gefunden werden. Versuche es über die Nachrichtenliste.'),
              backgroundColor: Colors.orange,
            ));
          }
          return;
        }
        // Send the message
        await MessageRepository().sendMessage(chatId, text);
        debugPrint('[Match] ✓ Sent "$text" to chatId=$chatId (matchedUserId=$matchedUserId)');
        // Close dialog + navigate to chat
        try { confettiCtrl.dispose(); } catch (_) {}
        if (ctx.mounted) Navigator.pop(ctx);
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) context.push('/messages/$chatId');
      } catch (e) {
        debugPrint('[Match] ✗ Send error: $e');
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
                  // Quick emoji buttons
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
                  // Text input for custom message
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
                            if (text.trim().isNotEmpty) sendQuickMsg(text.trim(), ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final text = msgCtrl.text.trim();
                          if (text.isNotEmpty) sendQuickMsg(text, ctx);
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
                  const SizedBox(height: 16),
                  // Chat öffnen Button direkt im Content (kein Overlap mit Send)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final chatId = await _getChatId();
                          if (ctx.mounted) Navigator.pop(ctx);
                          try { confettiCtrl.dispose(); } catch (_) {}
                          if (chatId != null && mounted) {
                            context.push('/messages/$chatId');
                          } else if (mounted) {
                            debugPrint('[Match] ✗ Kein Chat-ID — öffne Nachrichtenliste');
                            context.push('/messages');
                          }
                        } catch (e) {
                          debugPrint('[Match] Chat open error: $e');
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: Text('Chat öffnen', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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
          // Heart confetti — 3 sources
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

  void _openArchiveScreen(Color accentColor, Brightness brightness, Community? community) {
    final isDark = brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subCol = isDark ? Colors.white54 : Colors.black54;
    final cardCol = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final scaffoldBg = community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5));

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: scaffoldBg,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_rounded, color: textCol),
            ),
            title: Text('Mein Archiv', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textCol)),
            bottom: TabBar(
              labelColor: accentColor,
              unselectedLabelColor: subCol,
              indicatorColor: accentColor,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(icon: Icon(Icons.bookmark_rounded, size: 20), text: 'Beiträge'),
                Tab(icon: Icon(Icons.chat_bubble_rounded, size: 20), text: 'Nachrichten'),
                Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Artikel'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // ── Tab 1: Gespeicherte Beiträge ──
              _ArchiveSavedPostsTab(accentColor: accentColor, community: community),
              // ── Tab 2: Archivierte Nachrichten ──
              _ArchiveMessagesTab(accentColor: accentColor, textCol: textCol, subCol: subCol, scaffoldBg: scaffoldBg),
              // ── Tab 3: Archivierte Artikel ──
              _ArchiveListingsTab(accentColor: accentColor, textCol: textCol, subCol: subCol, cardCol: cardCol, isDark: isDark),
            ],
          ),
        ),
      ),
    ));
  }

  void _showArchivedListings(Color accentColor, Brightness brightness, Community? community) {
    final isDark = brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subCol = isDark ? Colors.white54 : Colors.black54;
    final cardCol = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.inventory_2_rounded, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 10),
                  Text('Archivierte Artikel', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: textCol)),
                ]),
              ]),
            ),
            Expanded(
              child: FutureBuilder<List<MarketplaceListing>>(
                future: MarketplaceRepository().getArchivedListings(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: subCol),
                        const SizedBox(height: 12),
                        Text('Keine archivierten Artikel', style: GoogleFonts.inter(fontSize: 15, color: subCol)),
                        const SizedBox(height: 4),
                        Text('Wische im Marktplatz nach rechts zum Archivieren', style: GoogleFonts.inter(fontSize: 12, color: subCol), textAlign: TextAlign.center),
                      ],
                    ));
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final listing = items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardCol,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 60, height: 60,
                                child: listing.images.isNotEmpty
                                    ? Image.network(listing.images.first, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.05), child: Icon(Icons.image_outlined, size: 24, color: subCol)))
                                    : Container(color: Colors.white.withValues(alpha: 0.05), child: Icon(Icons.image_outlined, size: 24, color: subCol)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(listing.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textCol), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (listing.price != null)
                                  Text('${listing.price!.toStringAsFixed(2)} ${listing.currency}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor)),
                                if (listing.createdAt != null)
                                  Text('${listing.createdAt!.day.toString().padLeft(2, '0')}.${listing.createdAt!.month.toString().padLeft(2, '0')}.${listing.createdAt!.year}',
                                    style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                              ],
                            )),
                            // Reactivate button
                            IconButton(
                              icon: Icon(Icons.unarchive_rounded, color: accentColor, size: 22),
                              tooltip: 'Wiederherstellen',
                              onPressed: () async {
                                try {
                                  await MarketplaceRepository().reactivateListing(listing.id);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('„${listing.title}" wiederhergestellt'), duration: const Duration(seconds: 2)),
                                    );
                                    // Reload marketplace
                                    ref.read(marketplaceNotifierProvider.notifier).loadListings();
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                            ),
                            // Delete button
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 22),
                              tooltip: 'Endgültig löschen',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: cardCol,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('Endgültig löschen?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textCol)),
                                    content: Text('„${listing.title}" wird unwiderruflich gelöscht.', style: GoogleFonts.inter(color: subCol)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text('Abbrechen', style: TextStyle(color: subCol))),
                                      TextButton(onPressed: () => Navigator.pop(dCtx, true), child: Text('Löschen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await MarketplaceRepository().deleteListing(listing.id);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('„${listing.title}" gelöscht'), duration: const Duration(seconds: 2)),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumSheet(Color accentColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text('Premium kommt bald!', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 8),
            Text('Wir arbeiten an exklusiven Features für Premium-Mitglieder:', style: GoogleFonts.inter(fontSize: 13, color: mutedColor), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _premiumFeature(Icons.verified_rounded, 'Verifiziertes Profil', 'Blauer Haken für dein Profil', textColor, mutedColor),
            _premiumFeature(Icons.trending_up_rounded, 'Profil-Boost', 'Mehr Sichtbarkeit im Feed & Dating', textColor, mutedColor),
            _premiumFeature(Icons.navigation_rounded, 'Pro Navigation', 'Erweiterte Routenplanung & Offroad-Karten', textColor, mutedColor),
            _premiumFeature(Icons.place_rounded, 'Exklusive POIs', 'Geheime Biker-Spots, Scenic Routes & Treffpunkte', textColor, mutedColor),
            _premiumFeature(Icons.block_rounded, 'Keine Werbung', 'Werbefreie Nutzung der App', textColor, mutedColor),
            _premiumFeature(Icons.palette_rounded, 'Exklusive Themes', 'Besondere Farbdesigns für dein Profil', textColor, mutedColor),
            _premiumFeature(Icons.analytics_rounded, 'Detaillierte Statistiken', 'Erweiterte Einblicke in dein Profil', textColor, mutedColor),
            const SizedBox(height: 16),
            Text('Benachrichtigung folgt, sobald Premium verfügbar ist.', style: GoogleFonts.inter(fontSize: 12, color: mutedColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _premiumFeature(IconData icon, String title, String subtitle, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showXpInfoSheet(BuildContext context, int xp, int level, Color accentColor, [List<BadgeInfo> badges = const []]) {
    _showUnifiedXpSheet(context, xp, level, badges, accentColor);
  }

  void _showLevelAndBadgesSheet(BuildContext context, int level, int xp, List<BadgeInfo> badges, Color accentColor) {
    _showUnifiedXpSheet(context, xp, level, badges, accentColor);
  }

  void _showUnifiedXpSheet(BuildContext context, int xp, int level, List<BadgeInfo> badges, Color accentColor) {
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

                // So verdienst du XP
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('So verdienst du XP', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: textCol)),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Bleib aktiv und steige schneller auf!', style: GoogleFonts.inter(fontSize: 12, color: subCol)),
                ),
                const SizedBox(height: 12),

                ...[
                  ('🏍', 'Fahren', '+1 XP/km', 'Jeder gefahrene Kilometer zählt'),
                  ('🎯', 'Distanz-Bonus', '+100 XP/1000 km', 'Bonus für Vielfahrer'),
                  ('📸', 'Beitrag posten', '+5 XP', 'Zeig dein Bike & deine Touren'),
                  ('❤️', 'Like geben', '+1 XP', 'Unterstütze andere Biker'),
                  ('💖', 'Like erhalten', '+2 XP', 'Teile tolle Inhalte'),
                  ('💬', 'Kommentar', '+2 XP', 'Beteilige dich an Diskussionen'),
                  ('📖', 'Story liken', '+1 XP', 'Reagiere auf Stories'),
                  ('📖', 'Story kommentieren', '+2 XP', 'Schreib was zur Story'),
                  ('👥', 'Neuer Follower', '+2 XP', 'Werde bekannter in der Community'),
                  ('💰', 'Artikel verkaufen', '+10 XP', 'Handel auf dem Marktplatz'),
                  ('📅', 'Täglicher Login', '+3 XP', 'Komm jeden Tag vorbei'),
                  ('🔥', '7-Tage-Streak', '+50 XP', '7 Tage am Stück eingeloggt'),
                  ('🔥', '30-Tage-Streak', '+200 XP', '30 Tage am Stück — Respekt!'),
                ].map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(item.$1, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: textCol)),
                            Text(item.$4, style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(item.$3, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 28),

                // XP-Abstufung
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
                      color: isCurrentTier ? accentColor.withValues(alpha: 0.12) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
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
                              Row(children: [
                                Text(tier.$2, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isCurrentTier ? accentColor : textCol)),
                                const SizedBox(width: 8),
                                Text('Lv. ${tier.$3}–${tier.$4}', style: GoogleFonts.inter(fontSize: 12, color: subCol)),
                              ]),
                              const SizedBox(height: 2),
                              Text(tier.$5, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isCurrentTier ? accentColor : subCol)),
                              Text(tier.$6, style: GoogleFonts.inter(fontSize: 11, color: subCol)),
                            ],
                          ),
                        ),
                        if (isCurrentTier) Icon(Icons.arrow_right_alt_rounded, color: accentColor, size: 24)
                        else if (level > tier.$4) Icon(Icons.check_circle_rounded, color: accentColor.withValues(alpha: 0.5), size: 20),
                      ],
                    ),
                  );
                }),

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
    ];

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (routeContext) => Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: cardBg,
          title: Text('Statistiken', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textColor)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => Navigator.of(routeContext).pop(),
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

  void _openMeinDate(Color accentColor, Brightness brightness, Community? community, {int initialTab = 0}) {
    _openMySwipes(context, ref, accentColor, brightness, community, initialTab: initialTab);
  }

  void _openMatchesList(Color accentColor, Brightness brightness, Community? community) {
    final isDark = brightness == Brightness.dark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final scaffoldBg = community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5));
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final uid = _targetUserId;
    if (uid.isEmpty) return;

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => _MatchesListScreen(
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

  void _openReceivedLikes(Color accentColor, Brightness brightness, Community? community) {
    final isDark = brightness == Brightness.dark;
    final cardBg = community?.cardFor(brightness) ?? (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final scaffoldBg = community?.scaffoldFor(brightness) ?? (isDark ? Colors.black : const Color(0xFFF5F5F5));
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D);
    final uid = _targetUserId;
    if (uid.isEmpty) return;

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => _ReceivedLikesScreen(
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

  // ── "Mein Date" — Swipe-Historie Overlay ──
  void _openMySwipes(BuildContext context, WidgetRef ref, Color accentColor, Brightness brightness, Community? community, {int initialTab = 0}) {
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
        initialTab: initialTab,
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
    this.initialTab = 0,
  });

  final String userId;
  final Color accentColor;
  final Color cardBg;
  final Color scaffoldBg;
  final Color textColor;
  final Color mutedColor;
  final Community? community;
  final int initialTab;

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
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
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

      // Filter: Minderjährige komplett ausschließen
      bool _isAdult(Map<String, dynamic> entry) {
        final by = entry['birth_year'] as int?;
        if (by == null) return true; // kein Geburtsjahr = anzeigen
        return (DateTime.now().year - by) >= 18;
      }

      setState(() {
        _likes = likesRes.map((r) {
          final p = profileMap[r['swiped_id']] ?? {};
          return {...p, 'swipe_date': r['created_at']};
        }).where(_isAdult).toList();

        _nopes = nopesRes.map((r) {
          final p = profileMap[r['swiped_id']] ?? {};
          return {...p, 'swipe_date': r['created_at']};
        }).where(_isAdult).toList();

        _matches = matchesRes.map((r) {
          final otherId = r['user1_id'] == widget.userId
              ? r['user2_id'] as String
              : r['user1_id'] as String;
          final p = profileMap[otherId] ?? {};
          return {...p, 'conversation_id': r['conversation_id'], 'match_date': r['created_at']};
        }).where(_isAdult).toList();

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

  Future<void> _handleUnmatch(Map<String, dynamic> item, int index) async {
    final targetId = item['id'] as String?;
    if (targetId == null) return;
    final name = item['display_name'] ?? item['bikername'] ?? item['username'] ?? '?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Entmatchen', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Möchtest du $name wirklich entmatchen? Das Match und die Konversation werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Abbrechen', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Entmatchen', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sb = Supabase.instance.client;
    final communityName = widget.community?.name ?? 'bikergram';

    try {
      // Delete match row (both directions)
      await sb.from('matches').delete().or(
        'and(user1_id.eq.${widget.userId},user2_id.eq.$targetId),'
        'and(user1_id.eq.$targetId,user2_id.eq.${widget.userId})',
      );

      // Delete swipe records (both directions)
      await sb.from('profile_swipes').delete()
          .eq('swiper_id', widget.userId)
          .eq('swiped_id', targetId)
          .eq('community', communityName);
      await sb.from('profile_swipes').delete()
          .eq('swiper_id', targetId)
          .eq('swiped_id', widget.userId)
          .eq('community', communityName);

      setState(() => _matches.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name wurde entmatcht'),
            backgroundColor: Colors.orange.withValues(alpha: 0.9),
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
                              isMatches ? '💬 Tippen → Chat · Wischen → Löschen'
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
                      // Action button: Dislike / Entnope / Entmatchen
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
                      else if (isMatches)
                        GestureDetector(
                          onTap: () => _handleUnmatch(item, i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link_off_rounded, size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'Entmatchen',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

// ─────────────────────────────────────────────────────
// Archive Tab Widgets
// ─────────────────────────────────────────────────────

/// Tab 1: Gespeicherte Beiträge (reuses saved-posts logic)
class _ArchiveSavedPostsTab extends ConsumerStatefulWidget {
  final Color accentColor;
  final Community? community;
  const _ArchiveSavedPostsTab({required this.accentColor, this.community});

  @override
  ConsumerState<_ArchiveSavedPostsTab> createState() => _ArchiveSavedPostsTabState();
}

class _ArchiveSavedPostsTabState extends ConsumerState<_ArchiveSavedPostsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _page = 1; });
    try {
      final repo = ref.read(feedRepositoryProvider);
      final result = await repo.getSavedPosts(page: 1);
      if (!mounted) return;
      setState(() { _posts = result.posts; _hasMore = result.hasMore; _isLoading = false; });
    } catch (e) {
      debugPrint('[ArchivePosts] $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final repo = ref.read(feedRepositoryProvider);
      final next = _page + 1;
      final result = await repo.getSavedPosts(page: next);
      if (!mounted) return;
      setState(() { _posts = [..._posts, ...result.posts]; _hasMore = result.hasMore; _page = next; _isLoadingMore = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_posts.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Keine gespeicherten Beiträge', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey)),
        ],
      ));
    }
    return RefreshIndicator(
      color: widget.accentColor,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))));
          }
          final post = _posts[i];
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            accentColor: widget.accentColor,
            communityName: widget.community?.name,
            onLike: () async {
              final lockSecs = await ref.read(feedNotifierProvider.notifier).toggleLike(post.id);
              if (lockSecs != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bitte warte $lockSecs Sekunden'), backgroundColor: Colors.orange.shade700, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
                return;
              }
              final idx = _posts.indexWhere((p) => p.id == post.id);
              if (idx != -1) setState(() { _posts[idx] = _posts[idx].copyWith(likedByMe: !_posts[idx].likedByMe, likeCount: _posts[idx].likeCount + (_posts[idx].likedByMe ? -1 : 1)); });
            },
            onSave: () async {
              try {
                await ref.read(feedRepositoryProvider).toggleSave(post.id);
                if (!mounted) return;
                setState(() => _posts = _posts.where((p) => p.id != post.id).toList());
                ref.read(feedNotifierProvider.notifier).toggleSave(post.id);
              } catch (_) {}
            },
            onComment: () => CommentsSheet.show(context, post.id, postUserId: post.userId),
            onEdit: () {},
            onDelete: () {},
          );
        },
      ),
    );
  }
}

/// Tab 2: Archivierte Nachrichten
class _ArchiveMessagesTab extends ConsumerStatefulWidget {
  final Color accentColor;
  final Color textCol;
  final Color subCol;
  final Color scaffoldBg;
  const _ArchiveMessagesTab({required this.accentColor, required this.textCol, required this.subCol, required this.scaffoldBg});

  @override
  ConsumerState<_ArchiveMessagesTab> createState() => _ArchiveMessagesTabState();
}

class _ArchiveMessagesTabState extends ConsumerState<_ArchiveMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(messagesNotifierProvider);

    if (state.isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final archived = state.conversations.where((c) => c.archivedAt != null && c.deletedAt == null).toList();

    if (archived.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Keine archivierten Nachrichten', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey)),
        ],
      ));
    }

    return RefreshIndicator(
      color: widget.accentColor,
      onRefresh: () => ref.read(messagesNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: archived.length,
        itemBuilder: (ctx, i) {
          final conv = archived[i];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dismissible(
            key: ValueKey('arch_msg_${conv.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.green.withValues(alpha: 0.15),
              child: const Icon(Icons.unarchive_rounded, color: Colors.green),
            ),
            onDismissed: (_) => ref.read(messagesNotifierProvider.notifier).unarchiveConversation(conv.id),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: conv.otherAvatarUrl != null ? NetworkImage(conv.otherAvatarUrl!) : null,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                child: conv.otherAvatarUrl == null ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black38, size: 22) : null,
              ),
              title: Text(conv.otherUsername ?? 'Unbekannt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: widget.textCol)),
              subtitle: conv.lastMessageBody != null
                  ? Text(conv.lastMessageBody!, style: GoogleFonts.inter(fontSize: 12, color: widget.subCol), maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: Icon(Icons.chevron_right_rounded, color: widget.subCol, size: 20),
              onTap: () => context.push('/messages/${conv.id}'),
            ),
          );
        },
      ),
    );
  }
}

/// Tab 3: Archivierte Marketplace-Artikel
class _ArchiveListingsTab extends ConsumerStatefulWidget {
  final Color accentColor;
  final Color textCol;
  final Color subCol;
  final Color cardCol;
  final bool isDark;
  const _ArchiveListingsTab({required this.accentColor, required this.textCol, required this.subCol, required this.cardCol, required this.isDark});

  @override
  ConsumerState<_ArchiveListingsTab> createState() => _ArchiveListingsTabState();
}

class _ArchiveListingsTabState extends ConsumerState<_ArchiveListingsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<MarketplaceListing>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = MarketplaceRepository().getArchivedListings();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<MarketplaceListing>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('Keine archivierten Artikel', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey)),
            ],
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final listing = items[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.cardCol,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08)),
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 60, height: 60,
                    child: listing.images.isNotEmpty
                        ? Image.network(listing.images.first, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.05), child: Icon(Icons.image_outlined, size: 24, color: widget.subCol)))
                        : Container(color: Colors.white.withValues(alpha: 0.05), child: Icon(Icons.image_outlined, size: 24, color: widget.subCol)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: widget.textCol), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (listing.price != null)
                      Text('${listing.price!.toStringAsFixed(2)} ${listing.currency}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: widget.accentColor)),
                    if (listing.createdAt != null)
                      Text('${listing.createdAt!.day.toString().padLeft(2, '0')}.${listing.createdAt!.month.toString().padLeft(2, '0')}.${listing.createdAt!.year}',
                        style: GoogleFonts.inter(fontSize: 11, color: widget.subCol)),
                  ],
                )),
                IconButton(
                  icon: Icon(Icons.unarchive_rounded, color: widget.accentColor, size: 22),
                  tooltip: 'Wiederherstellen',
                  onPressed: () async {
                    try {
                      await MarketplaceRepository().reactivateListing(listing.id);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('„${listing.title}" wiederhergestellt'), duration: const Duration(seconds: 2)));
                        ref.read(marketplaceNotifierProvider.notifier).loadListings();
                        setState(() { _future = MarketplaceRepository().getArchivedListings(); });
                      }
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 22),
                  tooltip: 'Endgültig löschen',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: widget.cardCol,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Endgültig löschen?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: widget.textCol)),
                        content: Text('„${listing.title}" wird unwiderruflich gelöscht.', style: GoogleFonts.inter(color: widget.subCol)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text('Abbrechen', style: TextStyle(color: widget.subCol))),
                          TextButton(onPressed: () => Navigator.pop(dCtx, true), child: Text('Löschen', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await MarketplaceRepository().deleteListing(listing.id);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('„${listing.title}" gelöscht'), duration: const Duration(seconds: 2)));
                          setState(() { _future = MarketplaceRepository().getArchivedListings(); });
                        }
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 💕 Received Likes — Wer hat mich geliked?
// ══════════════════════════════════════════════════════════════════════════════

class _ReceivedLikesScreen extends StatefulWidget {
  const _ReceivedLikesScreen({
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
  State<_ReceivedLikesScreen> createState() => _ReceivedLikesScreenState();
}

class _ReceivedLikesScreenState extends State<_ReceivedLikesScreen> {
  List<Map<String, dynamic>> _likers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sb = Supabase.instance.client;
    try {
      // Get users who liked me (from profile_swipes)
      final swipes = await sb
          .from('profile_swipes')
          .select('swiper_id, created_at')
          .eq('swiped_id', widget.userId)
          .eq('is_like', true)
          .order('created_at', ascending: false)
          .limit(100);

      // Also get matches (partner liked me too)
      final matches = await sb
          .from('matches')
          .select('user1_id, user2_id, created_at')
          .or('user1_id.eq.${widget.userId},user2_id.eq.${widget.userId}')
          .order('created_at', ascending: false)
          .limit(100);

      final allIds = <String>{};
      for (final s in swipes) allIds.add(s['swiper_id'] as String);
      for (final m in matches) {
        final u1 = m['user1_id'] as String;
        final u2 = m['user2_id'] as String;
        allIds.add(u1 == widget.userId ? u2 : u1);
      }

      if (allIds.isEmpty) {
        if (mounted) setState(() { _likers = []; _loading = false; });
        return;
      }

      final profiles = await sb
          .from('profiles')
          .select('id, username, display_name, avatar_url, birth_year')
          .inFilter('id', allIds.toList());

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) profileMap[p['id'] as String] = Map<String, dynamic>.from(p);

      final result = <Map<String, dynamic>>[];
      final seen = <String>{};

      // Add match partners first (they liked me + we matched)
      for (final m in matches) {
        final u1 = m['user1_id'] as String;
        final u2 = m['user2_id'] as String;
        final partnerId = u1 == widget.userId ? u2 : u1;
        if (seen.contains(partnerId)) continue;
        seen.add(partnerId);
        final profile = profileMap[partnerId];
        if (profile != null) {
          result.add({...profile, 'is_match': true, 'liked_at': m['created_at']});
        }
      }

      // Add likers who are not matches
      for (final s in swipes) {
        final swiperId = s['swiper_id'] as String;
        if (seen.contains(swiperId)) continue;
        seen.add(swiperId);
        final profile = profileMap[swiperId];
        if (profile != null) {
          result.add({...profile, 'is_match': false, 'liked_at': s['created_at']});
        }
      }

      if (mounted) setState(() { _likers = result; _loading = false; });
    } catch (e) {
      debugPrint('[Dating] ReceivedLikes error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.scaffoldBg,
      appBar: AppBar(
        backgroundColor: widget.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: widget.textColor),
        ),
        title: Text(
          '❤️ Likes erhalten',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: widget.textColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _likers.isEmpty
              ? Center(child: Text('Noch keine Likes erhalten', style: GoogleFonts.inter(color: widget.mutedColor)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _likers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final liker = _likers[i];
                    final username = liker['username'] as String? ?? 'User';
                    final displayName = liker['display_name'] as String?;
                    final avatarUrl = liker['avatar_url'] as String?;
                    final isMatch = liker['is_match'] as bool? ?? false;
                    final uid = liker['id'] as String;

                    return GestureDetector(
                      onTap: () => GoRouter.of(context).push('/profile/$uid?showDating=true'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: widget.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: isMatch ? Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)) : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              backgroundColor: widget.accentColor.withValues(alpha: 0.1),
                              child: avatarUrl == null ? Icon(Icons.person_rounded, color: widget.mutedColor) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName ?? username,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: widget.textColor),
                                  ),
                                  Text(
                                    '@$username',
                                    style: GoogleFonts.inter(fontSize: 12, color: widget.mutedColor),
                                  ),
                                ],
                              ),
                            ),
                            if (isMatch)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Match 🔥', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.pinkAccent)),
                              )
                            else
                              Icon(Icons.favorite_rounded, color: Colors.redAccent.withValues(alpha: 0.5), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔥 Matches Liste
// ══════════════════════════════════════════════════════════════════════════════

class _MatchesListScreen extends StatefulWidget {
  const _MatchesListScreen({
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
  State<_MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends State<_MatchesListScreen> {
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sb = Supabase.instance.client;
    try {
      final matches = await sb
          .from('matches')
          .select('user1_id, user2_id, conversation_id, created_at')
          .or('user1_id.eq.${widget.userId},user2_id.eq.${widget.userId}')
          .order('created_at', ascending: false)
          .limit(100);

      final partnerIds = <String>[];
      final matchData = <String, Map<String, dynamic>>{};
      for (final m in matches) {
        final u1 = m['user1_id'] as String;
        final u2 = m['user2_id'] as String;
        final partnerId = u1 == widget.userId ? u2 : u1;
        partnerIds.add(partnerId);
        matchData[partnerId] = Map<String, dynamic>.from(m);
      }

      if (partnerIds.isEmpty) {
        if (mounted) setState(() { _matches = []; _loading = false; });
        return;
      }

      final profiles = await sb
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .inFilter('id', partnerIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) profileMap[p['id'] as String] = Map<String, dynamic>.from(p);

      final result = <Map<String, dynamic>>[];
      for (final pid in partnerIds) {
        final profile = profileMap[pid];
        if (profile != null) {
          result.add({
            ...profile,
            'conversation_id': matchData[pid]?['conversation_id'],
            'matched_at': matchData[pid]?['created_at'],
          });
        }
      }

      if (mounted) setState(() { _matches = result; _loading = false; });
    } catch (e) {
      debugPrint('[Dating] MatchesList error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.scaffoldBg,
      appBar: AppBar(
        backgroundColor: widget.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: widget.textColor),
        ),
        title: Text(
          '🔥 Meine Matches',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: widget.textColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _matches.isEmpty
              ? Center(child: Text('Noch keine Matches', style: GoogleFonts.inter(color: widget.mutedColor)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final match = _matches[i];
                    final username = match['username'] as String? ?? 'User';
                    final displayName = match['display_name'] as String?;
                    final avatarUrl = match['avatar_url'] as String?;
                    final uid = match['id'] as String;
                    final convId = match['conversation_id'];

                    return GestureDetector(
                      onTap: () {
                        if (convId != null) {
                          GoRouter.of(context).push('/messages/$convId');
                        } else {
                          GoRouter.of(context).push('/profile/$uid');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: widget.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              backgroundColor: Colors.pinkAccent.withValues(alpha: 0.1),
                              child: avatarUrl == null ? Icon(Icons.person_rounded, color: widget.mutedColor) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName ?? username,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: widget.textColor),
                                  ),
                                  Text(
                                    '@$username',
                                    style: GoogleFonts.inter(fontSize: 12, color: widget.mutedColor),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              convId != null ? Icons.chat_bubble_rounded : Icons.person_rounded,
                              color: Colors.pinkAccent.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
