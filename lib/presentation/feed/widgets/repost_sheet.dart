import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/community.dart';
import '../../../domain/models/post.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/feed/feed_notifier.dart';

/// Bottom sheet for reposting a post with optional quote.
class RepostSheet extends ConsumerStatefulWidget {
  const RepostSheet({super.key, required this.post});

  final Post post;

  static Future<void> show(BuildContext context, Post post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepostSheet(post: post),
    );
  }

  @override
  ConsumerState<RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends ConsumerState<RepostSheet> {
  final _quoteController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }

  Future<void> _handleRepost() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final quoteBody = _quoteController.text.trim();
      await ref.read(feedNotifierProvider.notifier).repost(
            widget.post.id,
            quoteBody: quoteBody.isNotEmpty ? quoteBody : null,
          );

      HapticFeedback.mediumImpact();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reposted!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString().contains('duplicate')
            ? 'Du hast diesen Beitrag bereits repostet'
            : 'Repost fehlgeschlagen';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? const Color(0xFFFF6B35);
    final cardBg = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF9E9E9E));

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Repost',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Teile diesen Beitrag mit deinen Followern',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 16),

              // Original post preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, color: accentColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${widget.post.username}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                          if (widget.post.body != null &&
                              widget.post.body!.isNotEmpty)
                            Text(
                              widget.post.body!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: mutedColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quote input (optional)
              TextField(
                controller: _quoteController,
                maxLines: 3,
                minLines: 1,
                enabled: !_isSubmitting,
                style: GoogleFonts.inter(fontSize: 15, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Kommentar hinzufügen (optional)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15,
                    color: mutedColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.red),
                ),
              ],

              const SizedBox(height: 16),

              // Repost button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _handleRepost,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.repeat_rounded, size: 20),
                  label: Text(
                    _isSubmitting ? 'Wird repostet...' : 'Reposten',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
