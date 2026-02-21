import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/repositories/feed_repository.dart';

/// Bottom sheet that shows which users liked a post.
class LikersSheet extends StatefulWidget {
  const LikersSheet({
    super.key,
    required this.postId,
    required this.accentColor,
  });

  final int postId;
  final Color accentColor;

  /// Show the likers sheet.
  static void show(BuildContext context, int postId, {required Color accentColor}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => LikersSheet(
          postId: postId,
          accentColor: accentColor,
        ),
      ),
    );
  }

  @override
  State<LikersSheet> createState() => _LikersSheetState();
}

class _LikersSheetState extends State<LikersSheet> {
  List<Map<String, dynamic>>? _likers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  Future<void> _loadLikers() async {
    try {
      final repo = FeedRepository();
      final likers = await repo.getPostLikers(widget.postId);
      if (mounted) {
        setState(() {
          _likers = likers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF6C757D);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: mutedColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Gefällt mir',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (_likers != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_likers!.length}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: mutedColor.withValues(alpha: 0.1)),

          // List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.accentColor,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          'Fehler beim Laden',
                          style: GoogleFonts.inter(color: mutedColor),
                        ),
                      )
                    : _likers!.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_border_rounded,
                                    color: mutedColor, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Noch keine Likes',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _likers!.length,
                            itemBuilder: (_, index) {
                              final liker = _likers![index];
                              final profile =
                                  liker['profiles'] as Map<String, dynamic>?;
                              final username =
                                  profile?['username'] as String? ?? '?';
                              final displayName =
                                  profile?['display_name'] as String?;
                              final avatarUrl =
                                  profile?['avatar_url'] as String?;
                              final userId = liker['user_id'] as String? ?? '';

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push('/profile/$userId');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        ClipOval(
                                          child: avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: avatarUrl,
                                                  width: 44,
                                                  height: 44,
                                                  fit: BoxFit.cover,
                                                  errorWidget:
                                                      (_, __, ___) =>
                                                          _buildFallbackAvatar(
                                                              username),
                                                )
                                              : _buildFallbackAvatar(
                                                  username),
                                        ),
                                        const SizedBox(width: 14),
                                        // Name
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName ?? username,
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '@$username',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: mutedColor,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Chevron
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color:
                                              mutedColor.withValues(alpha: 0.3),
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String username) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accentColor.withValues(alpha: 0.2),
      ),
      child: Center(
        child: Text(
          (username.isNotEmpty ? username[0] : '?').toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: widget.accentColor,
          ),
        ),
      ),
    );
  }
}
