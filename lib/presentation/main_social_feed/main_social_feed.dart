import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_export.dart';
import '../../core/api_client.dart';
import '../../core/auth/token_store.dart';
import '../../core/auth/bikergram_auth_api.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/create_post_fab_widget.dart';
import './widgets/post_card_widget.dart';
import './widgets/likes_sheet_widget.dart';
import './widgets/comments_sheet_widget.dart';
import './widgets/story_item_widget.dart';
import 'utils/saved_posts_store.dart';
import 'widgets/share_sheet_widget.dart';

class MainSocialFeed extends StatefulWidget {
  const MainSocialFeed({super.key});

  @override
  State<MainSocialFeed> createState() => _MainSocialFeedState();
}

class _MainSocialFeedState extends State<MainSocialFeed> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isRefreshing = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _feedError;

  AuthUser? _me;
  bool _meLoading = false;

  // Mock data for stories
  final List<Map<String, dynamic>> _stories = [
    {
      "id": 1,
      "username": "MaxPower",
      "avatar":
          "https://img.rocket.new/generatedImages/rocket_gen_img_12edd2a4d-1763295490616.png",
      "semanticLabel":
          "Profile photo of a man with short brown hair wearing a blue shirt",
      "bikeThumb":
          "https://images.unsplash.com/photo-1692286132944-7f19f3ed8381",
      "bikeSemanticLabel": "Red sports motorcycle parked on street",
      "hasNewStory": true,
    },
    {
      "id": 2,
      "username": "RiderGirl",
      "avatar":
          "https://img.rocket.new/generatedImages/rocket_gen_img_151fc3125-1763293506871.png",
      "semanticLabel": "Profile photo of a woman with long dark hair smiling",
      "bikeThumb":
          "https://images.unsplash.com/photo-1658984559610-b6f45f7d1c52",
      "bikeSemanticLabel": "Black cruiser motorcycle on mountain road",
      "hasNewStory": true,
    },
    {
      "id": 3,
      "username": "TrackDemon",
      "avatar":
          "https://img.rocket.new/generatedImages/rocket_gen_img_11898c483-1763296181751.png",
      "semanticLabel": "Profile photo of a man with beard wearing racing gear",
      "bikeThumb":
          "https://images.unsplash.com/photo-1637657445067-bcd0d93b9086",
      "bikeSemanticLabel": "Yellow racing motorcycle on track",
      "hasNewStory": false,
    },
    {
      "id": 4,
      "username": "DIYMechanic",
      "avatar":
          "https://img.rocket.new/generatedImages/rocket_gen_img_1f2746db7-1763296313857.png",
      "semanticLabel": "Profile photo of a man with short hair in workshop",
      "bikeThumb":
          "https://images.unsplash.com/photo-1649878974663-c9269069bf87",
      "bikeSemanticLabel": "Custom modified motorcycle in garage",
      "hasNewStory": true,
    },
  ];

  List<Map<String, dynamic>> _posts = [];

  // Prevent duplicate items when paging & handle optimistic operations safely
  final Set<int> _seenPostIds = <int>{};

  // Like requests in-flight (prevents double-tap race)
  final Set<int> _likeInFlight = <int>{};

  final Set<int> _hiddenPostIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadFeed(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  void _applyMineFlagsToPosts() {
    final myId = _me?.id;
    if (myId == null) return;

    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    for (final p in _posts) {
      final uid = toInt(p['userId'] ?? p['user_id']);
      if (uid != null) {
        p['isMine'] = (uid == myId);
      }
    }
  }

  Future<void> _loadMe({bool silent = true}) async {
    if (_meLoading) return;
    setState(() => _meLoading = true);

    try {
      final pair = await TokenStore().read();
      if (pair == null) {
        if (!mounted) return;
        setState(() {
          _me = null;
          _meLoading = false;
        });
        return;
      }

      final api = BikergramAuthApi();
      final user = await api.me(accessToken: pair.accessToken);

      if (!mounted) return;
      setState(() {
      _me = user;
      _meLoading = false;
      _applyMineFlagsToPosts();
    });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _me = null;
        _meLoading = false;
      });
      if (!silent) rethrow;
    }
  }

  Future<void> _loadFeed({required bool reset}) async {
    if (_isLoading || _isRefreshing) return;

    if (reset) {
      _currentPage = 1;
      _hasMore = true;
    } else {
      if (!_hasMore) return;
    }

    setState(() {
      _feedError = null;
      if (reset) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final page = _currentPage;
      const limit = 20;

      final res = await ApiClient.instance
          .getJson('/feed.php?page=$page&limit=$limit', withAuth: true);

      final ok = res['ok'] == true;
      if (!ok) {
        final msg = (res['error']?['message'] ?? res['message'] ?? 'Feed error')
            .toString();
        throw StateError(msg);
      }

      final dynamic data = res['data'];
      bool? hasMoreFromApi;
      int? pageFromApi;
      if (data is Map) {
        final hm = data['hasMore'];
        if (hm is bool) hasMoreFromApi = hm;
        final pg = data['page'];
        if (pg is int) pageFromApi = pg;
        if (pg is num) pageFromApi = pg.toInt();
      }
      dynamic list;

      if (data is Map) {
        list = data['posts'] ?? data['items'] ?? data['feed'];
      } else {
        list = data;
      }

      if (list is! List) {
        // If API returns ok but no list, treat as empty feed.
        list = const [];
      }

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          parsed.add(_postFromApi(item.cast<String, dynamic>()));
        }
      }

      if (!mounted) return;
      setState(() {
        if (reset) {
          _posts = parsed;
          _seenPostIds
            ..clear()
            ..addAll(parsed.map((e) => (e['id'] as int?) ?? 0).where((id) => id != 0));
        } else {
          for (final p in parsed) {
            final id = (p['id'] as int?) ?? 0;
            if (id == 0) continue;
            if (_seenPostIds.add(id)) {
              _posts.add(p);
            }
          }
        }

        _applyMineFlagsToPosts();

        // Pagination: prefer API's hasMore flag if available (most accurate).
        final receivedCount = parsed.length;
        final more = hasMoreFromApi ?? (receivedCount >= limit);
        _hasMore = more;

        if (more) {
          final basePage = pageFromApi ?? page;
          _currentPage = basePage + 1;
        }

        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.toString().replaceFirst('Bad state: ', '');
        _isLoading = false;
        _isRefreshing = false;
        _hasMore = false;
      });
    }
  }

  Map<String, dynamic> _postFromApi(Map<String, dynamic> p) {
    // Supports both legacy feed shape and the new API shape:
    // - new: { id, author:{id,username,displayName,...}, body, imageUrl, createdAt, likeCount, commentCount, likedByMe/viewerLiked, isMine }
    // - old: { id, user:{...} / username, caption/text, postImage/imageUrl, likes, comments, timestamp ... }
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    bool _toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes' || s == 'y';
      }
      return false;
    }

    final id = _toInt(p['id']);

    final author = (p['author'] is Map)
        ? (p['author'] as Map).cast<String, dynamic>()
        : (p['user'] is Map)
            ? (p['user'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

    final displayName = (author['displayName'] ??
            author['display_name'] ??
            author['username'] ??
            author['name'] ??
            p['displayName'] ??
            p['display_name'] ??
            p['username'] ??
            p['user'] ??
            'user')
        .toString();

    final avatar = (p['userAvatar'] ??
            p['avatarUrl'] ??
            p['avatar_url'] ??
            author['avatarUrl'] ??
            author['avatar_url'] ??
            author['avatar'] ??
            '')
        .toString();

    final postImage = (p['imageUrl'] ??
            p['image_url'] ??
            p['postImage'] ??
            p['photoUrl'] ??
            p['image'] ??
            p['mediaUrl'] ??
            p['media_url'] ??
            '')
        .toString();

    final bodyText = (p['body'] ??
            p['caption'] ??
            p['text'] ??
            p['content'] ??
            p['message'] ??
            '')
        .toString();

    final likes = _toInt(p['likes'] ?? p['likeCount'] ?? p['like_count'] ?? 0);
    final comments =
        _toInt(p['comments'] ?? p['commentCount'] ?? p['comment_count'] ?? 0);

    final tsRaw = (p['createdAt'] ??
            p['created_at'] ??
            p['timestamp'] ??
            p['time'] ??
            p['date'] ??
            '')
        .toString();
    final ts = DateTime.tryParse(tsRaw) ?? DateTime.now();

    final editedRaw = (p['editedAt'] ??
            p['edited_at'] ??
            p['updatedAt'] ??
            p['updated_at'] ??
            '')
        .toString();
    final editedAt = DateTime.tryParse(editedRaw);
    final isEdited = editedAt != null && editedRaw.isNotEmpty
        ? editedAt.isAfter(ts.add(const Duration(seconds: 1)))
        : false;

    final userId = (() {
      final v = p['userId'] ??
          p['user_id'] ??
          p['uid'] ??
          p['authorId'] ??
          p['author_id'] ??
          author['id'];
      final i = _toInt(v);
      return i == 0 ? null : i;
    })();

    // Like flag from API (new/old). UI uses "isLiked".
    final liked = _toBool(p['isLiked'] ??
        p['likedByMe'] ??
        p['viewerLiked'] ??
        p['viewer_liked'] ??
        p['liked']);

    // isMine from API or computed later by _applyMineFlagsToPosts()
    final mine = _toBool(p['isMine']);

    final postImageRaw = postImage;
    final postVideo = (p['videoUrl'] ?? p['video_url'] ?? '').toString();

    // sensible placeholders (avoid blank cards)
    final avatarFinal = avatar.isNotEmpty
        ? avatar
        : 'https://images.unsplash.com/photo-1520975693411-b3a8a4b3a2d9';
    // Only set image placeholder when there is no video – otherwise it hides the video
    final postImageFinal = postImage.isNotEmpty
        ? postImage
        : (postVideo.isEmpty
            ? 'https://images.unsplash.com/photo-1712491875739-58ad63377117'
            : '');

    return {
      'id': id,
      'userId': userId,
      'username': displayName,
      'displayName': displayName,
      'user': displayName, // legacy widgets sometimes read this
      'userAvatar': avatarFinal,
      'userAvatarLabel': 'User avatar',
      'postImage': postImageFinal,
      'postImageRaw': postImageRaw,
      'postImageLabel': 'Post image',
      'postVideo': postVideo,
      'caption': bodyText,
      'likes': likes,
      'comments': comments,
      'timestamp': ts,
      'editedAt': editedAt?.toIso8601String(),
      'isEdited': isEdited,
      'isMine': mine,
      'isLiked': liked,
      'isSaved': SavedPostsStore.instance.isSaved(id) || _toBool(p['isSaved']),
    };
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isRefreshing) return;
    if (!_hasMore) return;

    // Trigger load-more slightly before the end for smoother UX.
    final threshold = 350.0;
    final pos = _scrollController.position;
    if (pos.pixels >= (pos.maxScrollExtent - threshold)) {
      _loadFeed(reset: false);
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadMe();
    await _loadFeed(reset: true);
  }

  Future<void> _handleLike(int postId) async {
    if (_likeInFlight.contains(postId)) return;

    int findIndex() => _posts.indexWhere((post) => post["id"] == postId);

    final postIndex0 = findIndex();
    if (postIndex0 == -1) return;

    _likeInFlight.add(postId);

    final prevLiked = _posts[postIndex0]["isLiked"] as bool? ?? false;
    final prevCount = _posts[postIndex0]["likes"] as int? ?? 0;

    // Optimistic UI update (instant feedback)
    setState(() {
      _posts[postIndex0]["isLiked"] = !prevLiked;
      _posts[postIndex0]["likes"] = prevCount + (prevLiked ? -1 : 1);
    });

    HapticFeedback.lightImpact();

    try {
      final res = await ApiClient.instance.postJson(
        '/like_toggle.php',
        body: {'postId': postId, 'post_id': postId},
        withAuth: true,
      );

      if (res['ok'] != true) {
        throw Exception((res['error']?['message'] ?? 'Like fehlgeschlagen').toString());
      }

      final data = (res['data'] as Map?) ?? const {};
      final liked = (data['likedByMe'] ?? data['viewerLiked'] ?? data['liked']) == true;

      int? likeCount;
      final lc = data['likeCount'] ?? data['total'] ?? data['count'];
      if (lc is int) likeCount = lc;
      if (lc is num) likeCount = lc.toInt();
      if (lc is String) likeCount = int.tryParse(lc);

      if (!mounted) return;
      final idx = findIndex();
      if (idx == -1) return;

      setState(() {
        _posts[idx]["isLiked"] = liked;
        if (likeCount != null) {
          _posts[idx]["likes"] = likeCount;
        }
      });
    } catch (_) {
      if (!mounted) return;
      final idx = findIndex();
      if (idx == -1) return;

      setState(() {
        _posts[idx]["isLiked"] = prevLiked;
        _posts[idx]["likes"] = prevCount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Like fehlgeschlagen'),
          duration: Duration(seconds: 1),
        ),
      );
    } finally {
      _likeInFlight.remove(postId);
      if (mounted) setState(() {});
    }
  }


  void _openLikes(int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LikesSheet(
        postId: postId,
        myUserId: _me?.id,
      ),
    );
  }

  void _handleSave(int postId) {
  HapticFeedback.lightImpact();

  final nowSaved = SavedPostsStore.instance.toggle(postId);

  if (!mounted) return;
  setState(() {
    final postIndex = _posts.indexWhere((post) => post["id"] == postId);
    if (postIndex != -1) {
      _posts[postIndex]["isSaved"] = nowSaved;
    }
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(nowSaved ? 'Gespeichert ✅' : 'Aus Speicher entfernt'),
      duration: const Duration(milliseconds: 900),
    ),
  );
}

  Future<void> _handleComment(int postId) async {
    HapticFeedback.lightImpact();

    final idx = _posts.indexWhere((p) => p["id"] == postId);
    final initialCount = idx == -1 ? 0 : (_posts[idx]["comments"] as int? ?? 0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(
        postId: postId,
        myUserId: _me?.id,
        initialCount: initialCount,
        onCountChanged: (count) {
          if (!mounted) return;
          if (idx == -1) return;
          setState(() => _posts[idx]["comments"] = count);
        },
      ),
    );
  }


  void _handleShare(int postId) async {
  HapticFeedback.lightImpact();

  final post = _posts.firstWhere(
    (p) => (p['id'] as int?) == postId,
    orElse: () => <String, dynamic>{'id': postId},
  );

  final username = (post['username'] ?? post['displayName'] ?? 'user').toString();
  final caption = (post['caption'] ?? '').toString();

  // Prefer a real permalink if you have one; otherwise share the image URL; otherwise fallback.
  String link = (post['postPermalink'] ?? post['postLink'] ?? post['link'] ?? '').toString().trim();
  if (link.isEmpty) {
    final img = (post['postImageRaw'] ?? post['postImage'] ?? '').toString().trim();
    if (img.isNotEmpty) {
      link = img;
    } else {
      link = 'https://bikergram.com/post/$postId';
    }
  }

  final shareText = caption.trim().isEmpty ? 'Bikergram Post von $username' : '$username: $caption';
  final fullText = '$shareText\n$link';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => ShareSheetWidget(
      shareText: shareText,
      shareLink: link,
      fullText: fullText,
    ),
  );
}


  void _hidePost(int postId) {
    setState(() => _hiddenPostIds.add(postId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Post verborgen'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () {
            if (!mounted) return;
            setState(() => _hiddenPostIds.remove(postId));
          },
        ),
      ),
    );
  }

  void _showReportPostSheet(int postId) {
    final reasons = <String>[
      'Spam',
      'Nacktheit',
      'Gewalt',
      'Hass / Belästigung',
      'Falsche Informationen',
      'Sonstiges',
    ];

    String reason = reasons.first;
    final detailsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx2, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Post melden',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: reason,
                    items: reasons
                        .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() => reason = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Grund',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final payload = <String, dynamic>{
                          'postId': postId,
                          'reason': reason,
                          'details': detailsCtrl.text.trim(),
                        };

                        try {
                          final res = await ApiClient.instance.postJson(
                            '/report_post.php',
                            body: payload,
                            withAuth: true,
                          );

                          if (res['ok'] != true) {
                            final msg = (res['error']?['message'] ??
                                    res['message'] ??
                                    'Report error')
                                .toString();
                            throw StateError(msg);
                          }

                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Danke! Meldung gesendet ✅')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fehler: ${e.toString().replaceFirst('Bad state: ', '')}')),
                          );
                        }
                      },
                      child: const Text('Melden'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _handlePostOptions(int postId) {
  HapticFeedback.mediumImpact();

  final post = _posts.firstWhere(
    (p) => (p['id'] as int?) == postId,
    orElse: () => <String, dynamic>{},
  );

  final myId = _me?.id;
  final postUserId = post['userId'] as int?;
  final myUsername = _me?.username;

    final isMine = (post['isMine'] == true) || (myId != null && postUserId != null && myId == postUserId);

showModalBottomSheet(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine) ...[
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'edit',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text('Post bearbeiten', style: theme.textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _openEditPostSheet(post);
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'delete_outline',
                  color: theme.colorScheme.error,
                  size: 24,
                ),
                title: Text('Post löschen', style: theme.textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndDeletePost(postId);
                },
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: CustomIconWidget(
                iconName: 'report',
                color: theme.colorScheme.error,
                size: 24,
              ),
              title: Text('Melden', style: theme.textTheme.bodyLarge),
              onTap: () {
              Navigator.pop(context);
              _showReportPostSheet(postId);
            },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'visibility_off',
                color: theme.colorScheme.onSurface,
                size: 24,
              ),
              title: Text('Verbergen', style: theme.textTheme.bodyLarge),
              onTap: () {
              Navigator.pop(context);
              _hidePost(postId);
            },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'link',
                color: theme.colorScheme.onSurface,
                size: 24,
              ),
              title: Text('Link kopieren', style: theme.textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _handleShare(postId);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openEditPostSheet(Map<String, dynamic> post) async {
  final postId = (post['id'] as int?) ?? 0;
  if (postId <= 0) return;

  final initialCaption = (post['caption'] ?? '').toString();
  final initialImageUrl = (post['postImageRaw'] ?? '').toString();

  final captionCtrl = TextEditingController(text: initialCaption);
  final imageCtrl = TextEditingController(text: initialImageUrl);

  final picker = ImagePicker();

  Uint8List? pickedBytes;
  String? pickedName;
  String? pickedMime;

  bool removeImage = false;
  bool isSubmitting = false;
  String? err;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

      return StatefulBuilder(
        builder: (ctx2, setModalState) {
          Future<void> pickImage(ImageSource src) async {
            try {
              final x = await picker.pickImage(source: src, imageQuality: 88);
              if (x == null) return;
              final bytes = await x.readAsBytes();
              if (bytes.isEmpty) return;
              setModalState(() {
                pickedBytes = bytes;
                pickedName = x.name;
                pickedMime = x.mimeType;
                removeImage = false;
                err = null;
              });
            } catch (e) {
              setModalState(() {
                err = e.toString();
              });
            }
          }

          Future<void> submit() async {
            final cap = captionCtrl.text.trim();
            var img = imageCtrl.text.trim();

            // If user cleared image url manually -> treat as remove when there was an image.
            if (initialImageUrl.isNotEmpty && img.isEmpty && pickedBytes == null) {
              removeImage = true;
            }

            // Detect if anything changed
            final captionChanged = cap != initialCaption;
            final imageChanged =
                removeImage || pickedBytes != null || img != initialImageUrl;

            if (!captionChanged && !imageChanged) {
              setModalState(() => err = 'Nichts geändert.');
              return;
            }

            setModalState(() {
              isSubmitting = true;
              err = null;
            });

            try {
              // If user picked a local image, upload it first and use returned URL.
              if (pickedBytes != null) {
                final up = await ApiClient.instance.postJson(
                  '/upload_image.php',
                  body: {
                    'filename': (pickedName?.isNotEmpty == true)
                        ? pickedName
                        : 'upload.jpg',
                    'mime': pickedMime ?? 'image/jpeg',
                    'dataBase64': base64Encode(pickedBytes!),
                  },
                  withAuth: true,
                );
                if (up['ok'] != true) {
                  final msg = (up['error']?['message'] ??
                          up['message'] ??
                          'Upload error')
                      .toString();
                  throw StateError(msg);
                }
                final url = (up['data']?['url'] ?? '').toString();
                if (url.isEmpty) throw StateError('Upload returned empty url');
                img = url;
                imageCtrl.text = url;
              }

              final body = <String, dynamic>{'id': postId};

              if (captionChanged) {
                // send multiple keys for schema-compatibility
                body['caption'] = cap;
                body['body'] = cap;
                body['text'] = cap;
              }

              if (removeImage) {
                body['removeImage'] = true;
              } else if (img != initialImageUrl) {
                // When image url differs -> update image url (can be empty only when no previous image)
                body['imageUrl'] = img;
              }

              final res = await ApiClient.instance.postJson(
                '/post_update.php',
                body: body,
                withAuth: true,
              );

              if (res['ok'] != true) {
                final msg = (res['error']?['message'] ??
                        res['message'] ??
                        'Update error')
                    .toString();
                throw StateError(msg);
              }

              if (!mounted) return;
              Navigator.of(ctx2).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post aktualisiert ✅')),
              );

              await _loadFeed(reset: true);
            } catch (e) {
              setModalState(() {
                err = e.toString().replaceFirst('Bad state: ', '');
                isSubmitting = false;
              });
            }
          }

          final showNetworkImage =
              !removeImage && pickedBytes == null && imageCtrl.text.trim().isNotEmpty;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomInset + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Post bearbeiten',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(ctx2).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: captionCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Was möchtest du ändern?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Bild wählen'),
                        ),
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Kamera'),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (pickedBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: Image.memory(
                              pickedBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.surface.withOpacity(0.85),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setModalState(() {
                                        pickedBytes = null;
                                        pickedName = null;
                                        pickedMime = null;
                                      });
                                    },
                              icon: const Icon(Icons.close),
                              tooltip: 'Entfernen',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (showNetworkImage) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: Image.network(
                              imageCtrl.text.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                alignment: Alignment.center,
                                child: const Text('Bild konnte nicht geladen werden'),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.surface.withOpacity(0.85),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setModalState(() {
                                        removeImage = true;
                                        imageCtrl.text = '';
                                      });
                                    },
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Bild löschen',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (removeImage && initialImageUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        'Bild wird entfernt.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bild-URL (optional)',
                      hintText: 'oder Upload benutzen',
                    ),
                    onChanged: (_) {
                      if (removeImage) {
                        setModalState(() => removeImage = false);
                      }
                    },
                  ),

                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      err!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  captionCtrl.dispose();
  imageCtrl.dispose();
}

Future<void> _confirmAndDeletePost(int postId) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Post löschen?'),
        content: const Text('Dieser Post wird dauerhaft gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Abbrechen',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      );
    },
  );

  if (ok != true) return;
  await _deletePost(postId);
}

Future<void> _deletePost(int postId) async {
  try {
    final res = await ApiClient.instance.postJson(
      '/post_delete.php',
      body: {'id': postId},
      withAuth: true,
    );

    if (res['ok'] != true) {
      final msg = (res['error']?['message'] ??
              res['message'] ??
              'Delete error')
          .toString();
      throw StateError(msg);
    }

    if (!mounted) return;
    setState(() {
      _posts.removeWhere((p) => (p['id'] as int?) == postId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post gelöscht ✅')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Löschen fehlgeschlagen: ${e.toString().replaceFirst('Bad state: ', '')}',
        ),
      ),
    );
  }
}

  void _handleStoryTap(int storyId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Story-Viewer wird geladen...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleCreatePostPlus() {
    HapticFeedback.mediumImpact();
    _openCreatePostSheet();
  }

  void _handleCreatePostCamera() {
    HapticFeedback.mediumImpact();
    final src = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    _openCreatePostSheet(autoPickImage: true, pickSource: src);
  }

  Future<void> _openCreatePostSheet({bool autoPickImage = false, ImageSource pickSource = ImageSource.gallery}) async {
    final captionCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final picker = ImagePicker();

    Uint8List? pickedBytes;
    String? pickedName;
    String? pickedMime;
    bool didAutoPick = false;

    bool isSubmitting = false;
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            Future<void> pickImage(ImageSource src) async {
              try {
                final x = await picker.pickImage(source: src, imageQuality: 88);
                if (x == null) return;
                final bytes = await x.readAsBytes();
                if (bytes.isEmpty) return;
                setModalState(() {
                  pickedBytes = bytes;
                  pickedName = x.name;
                  pickedMime = x.mimeType;
                  err = null;
                });
              } catch (e) {
                setModalState(() {
                  err = e.toString();
                });
              }
            }

            // Auto-open picker when user tapped the camera FAB.
            if (autoPickImage && !didAutoPick) {
              didAutoPick = true;
              Future.microtask(() => pickImage(pickSource));
            }

            Future<void> submit() async {
              final cap = captionCtrl.text.trim();
              var img = imageCtrl.text.trim();

              if (cap.isEmpty && img.isEmpty && pickedBytes == null) {
                setModalState(() {
                  err = 'Bitte Caption oder ein Bild angeben.';
                });
                return;
              }

              setModalState(() {
                isSubmitting = true;
                err = null;
              });

              try {
                // If user selected a local image, upload it first and use returned URL.
                if (pickedBytes != null && img.isEmpty) {
                  final up = await ApiClient.instance.postJson(
                    '/upload_image.php',
                    body: {
                      'filename': (pickedName?.isNotEmpty == true) ? pickedName : 'upload.jpg',
                      'mime': pickedMime ?? 'image/jpeg',
                      'dataBase64': base64Encode(pickedBytes!),
                    },
                    withAuth: true,
                  );
                  if (up['ok'] != true) {
                    final msg = (up['error']?['message'] ?? up['message'] ?? 'Upload error').toString();
                    throw StateError(msg);
                  }
                  final url = (up['data']?['url'] ?? '').toString();
                  if (url.isEmpty) throw StateError('Upload returned empty url');
                  img = url;
                  imageCtrl.text = url;
                }

                final res = await ApiClient.instance.postJson(
                  '/post_create.php',
                  body: {
                    // send multiple keys for schema-compatibility (server may expect body or caption)
                    'caption': cap,
                    'body': cap,
                    'text': cap,
                    'imageUrl': img,
                  },
                  withAuth: true,
                );

                final ok = res['ok'] == true;
                if (!ok) {
                  final msg = (res['error']?['message'] ??
                          res['message'] ??
                          'Post error')
                      .toString();
                  throw StateError(msg);
                }

                if (!mounted) return;
                Navigator.of(ctx2).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post erstellt ✅')),
                );

                await _loadFeed(reset: true);
              } catch (e) {
                setModalState(() {
                  err = e.toString().replaceFirst('Bad state: ', '');
                  isSubmitting = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomInset + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Neuer Post',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx2).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    controller: captionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Was geht ab? 🏍️',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Bild wählen'),
                        ),
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Kamera'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (pickedBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: Image.memory(
                              pickedBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setModalState(() {
                                        pickedBytes = null;
                                        pickedName = null;
                                        pickedMime = null;
                                      });
                                    },
                              icon: const Icon(Icons.close),
                              tooltip: 'Entfernen',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bild-URL (optional)',
                      hintText: 'oder Upload benutzen',
                    ),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      err!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Posten'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    captionCtrl.dispose();
    imageCtrl.dispose();
  }


  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Abmelden?'),
          content: const Text('Du wirst ausgeloggt und kommst zurück zum Wizard.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Abbrechen',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abmelden'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    HapticFeedback.mediumImpact();

    await TokenStore().clear(reason: 'logout');
    await ApiClient.instance.setToken(null);

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.wizard,
      (_) => false,
    );
  }

  Widget _buildFeedTitle(ThemeData theme) {
    final name = _me?.username.trim();
    final email = _me?.email.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BikerGram',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (name != null && name.isNotEmpty)
          Text(
            '@$name',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else if (email != null && email.isNotEmpty)
          Text(
            email,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final visiblePosts = _posts.where((p) {
      final id = p['id'];
      return id is int ? !_hiddenPostIds.contains(id) : true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        variant: AppBarVariant.standard,
        titleWidget: _buildFeedTitle(theme),
        centerTitle: false,
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'notifications_outlined',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, '/notifications');
            },
            tooltip: 'Benachrichtigungen',
          ),
          PopupMenuButton<String>(
            tooltip: 'Menü',
            icon: CustomIconWidget(
              iconName: 'more_vert',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.userProfile);
                return;
              }
              if (value == 'logout') {
                await _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'profile',
                child: Text('Profil'),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Abmelden'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 120,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _stories.length,
                  itemBuilder: (context, index) {
                    return StoryItemWidget(
                      story: _stories[index],
                      onTap: () => _handleStoryTap(_stories[index]["id"] as int),
                    );
                  },
                ),
              ),
            ),

            if (_feedError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feed konnte nicht geladen werden',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _feedError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () => _loadFeed(reset: true),
                            child: const Text('Nochmal versuchen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_posts.isEmpty && !_isLoading && !_isRefreshing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Noch keine Posts',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sobald Posts im Backend vorhanden sind, erscheinen sie hier.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = visiblePosts[index];
                  final postId = post["id"] as int;

                  final likeBusy = _likeInFlight.contains(postId);

                  return PostCardWidget(
                    post: post,
                    likeBusy: likeBusy,
                    onLike: () => _handleLike(postId),
                    onViewLikes: () => _openLikes(postId),
                    onComment: () => _handleComment(postId),
                    onSave: () => _handleSave(postId),
                    onShare: () => _handleShare(postId),
                    onOptions: () => _handlePostOptions(postId),
                  );
                },
                childCount: visiblePosts.length,
              ),
            ),

            if (_isRefreshing && _posts.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              )
            else if (_isLoading)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              )
            else if (!_hasMore && visiblePosts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Keine weiteren Posts',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      // Post-Button ist jetzt in der Bottom Navigation Bar
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 0,
        onTap: (index) {
          BottomBarNavigation.navigateToIndex(context, index);
        },
      ),
    );
  }
}