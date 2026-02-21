import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/community.dart';
import '../../../data/repositories/comment_repository.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/feed/feed_notifier.dart';
import '../../../theme/app_theme.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.postId, this.postUserId});

  final int postId;
  final String? postUserId;

  static Future<void> show(BuildContext context, int postId, {String? postUserId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId, postUserId: postUserId),
    );
  }

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(commentRepositoryProvider);
      final comments = await repo.getComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
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

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(commentRepositoryProvider);
      final comment = await repo.addComment(widget.postId, text);
      _controller.clear();
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _isSending = false;
      });
      ref.read(feedNotifierProvider.notifier).updateCommentCount(widget.postId, 1);
      // Create notification for the post author
      if (widget.postUserId != null && widget.postUserId!.isNotEmpty) {
        final authState = ref.read(authNotifierProvider);
        final myId = authState is Authenticated ? authState.user.id : '';
        final myName = authState is Authenticated
            ? (authState.user.displayName ?? authState.user.username)
            : '';
        final community = ref.read(communityProvider);
        debugPrint('[CommentsSheet] communityProvider = $community, name = ${community?.name}');
        ref.read(notificationRepositoryProvider).createNotification(
          targetUserId: widget.postUserId!,
          type: 'comment',
          title: '$myName hat kommentiert',
          body: text.length > 80 ? '${text.substring(0, 80)}...' : text,
          data: {'post_id': widget.postId, 'actor_id': myId},
          community: community?.name,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    try {
      final repo = ref.read(commentRepositoryProvider);
      await repo.deleteComment(comment.id, widget.postId);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });
      ref.read(feedNotifierProvider.notifier).updateCommentCount(widget.postId, -1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    return 'vor ${diff.inDays} Tagen';
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final brightness = Theme.of(context).brightness;
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textOnCard.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                Text('Kommentare',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textOnCard)),
                if (_comments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${_comments.length}',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textOnCard.withValues(alpha: 0.35))),
                ],
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: textMuted),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: faint),

          // Comments list
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_error!,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.red)),
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: 40,
                                      color:
                                          textOnCard.withValues(alpha: 0.12)),
                                  const SizedBox(height: 12),
                                  Text('Noch keine Kommentare',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: textOnCard
                                              .withValues(alpha: 0.3))),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) =>
                                _buildComment(_comments[i], accentColor, textOnCard),
                          ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: faint),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isSending,
                      style:
                          GoogleFonts.inter(fontSize: 15, color: textOnCard),
                      decoration: InputDecoration(
                        hintText: 'Kommentar schreiben...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 15,
                            color: textOnCard.withValues(alpha: 0.2)),
                        filled: true,
                        fillColor: textOnCard.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          onPressed: _sendComment,
                          icon: Icon(Icons.send_rounded,
                              color: accentColor, size: 22),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Comment comment, Color accentColor, Color textOnCard) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                comment.username.isNotEmpty
                    ? comment.username[0].toUpperCase()
                    : '?',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(comment.username,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textOnCard),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (comment.createdAt != null)
                      Text(_timeAgo(comment.createdAt!),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: textOnCard.withValues(alpha: 0.3))),
                    const Spacer(),
                    if (comment.isMine)
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: Icon(Icons.close_rounded,
                            size: 16,
                            color: textOnCard.withValues(alpha: 0.25)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: textOnCard.withValues(alpha: 0.75),
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
