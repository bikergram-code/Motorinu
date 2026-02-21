import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/core/providers.dart';
import 'report_sheet.dart';

/// Bottom sheet showing moderation options for a user:
/// Block, Mute, Report.
class UserModerationSheet extends ConsumerStatefulWidget {
  const UserModerationSheet({
    super.key,
    required this.userId,
    required this.username,
    this.community,
    this.accentColor = const Color(0xFFFF6B35),
    this.onBlockChanged,
    this.onMuteChanged,
  });

  final String userId;
  final String username;
  final String? community;
  final Color accentColor;
  final VoidCallback? onBlockChanged;
  final VoidCallback? onMuteChanged;

  /// Show the moderation sheet.
  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String username,
    String? community,
    Color accentColor = const Color(0xFFFF6B35),
    VoidCallback? onBlockChanged,
    VoidCallback? onMuteChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UserModerationSheet(
        userId: userId,
        username: username,
        community: community,
        accentColor: accentColor,
        onBlockChanged: onBlockChanged,
        onMuteChanged: onMuteChanged,
      ),
    );
  }

  @override
  ConsumerState<UserModerationSheet> createState() =>
      _UserModerationSheetState();
}

class _UserModerationSheetState extends ConsumerState<UserModerationSheet> {
  bool _isBlocked = false;
  bool _isMuted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final repo = ref.read(moderationRepositoryProvider);
    try {
      final blocked = await repo.isBlocked(widget.userId);
      final muted = widget.community != null
          ? await repo.isMuted(widget.userId, community: widget.community!)
          : false;
      if (mounted) {
        setState(() {
          _isBlocked = blocked;
          _isMuted = muted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlock() async {
    final repo = ref.read(moderationRepositoryProvider);
    final willBlock = !_isBlocked;

    // Confirm blocking
    if (willBlock) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '@${widget.username} blockieren?',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Blockierte Nutzer können dein Profil, deine Beiträge und Stories nicht sehen. '
            'Du siehst auch keine Inhalte von diesem Nutzer.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Abbrechen',
                  style: GoogleFonts.inter(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Blockieren',
                  style: GoogleFonts.inter(
                      color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      if (willBlock) {
        await repo.blockUser(widget.userId);
      } else {
        await repo.unblockUser(widget.userId);
      }
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() => _isBlocked = willBlock);
        widget.onBlockChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _toggleMute() async {
    if (widget.community == null) return;
    final repo = ref.read(moderationRepositoryProvider);
    final willMute = !_isMuted;

    try {
      if (willMute) {
        await repo.muteUser(widget.userId, community: widget.community!);
      } else {
        await repo.unmuteUser(widget.userId, community: widget.community!);
      }
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() => _isMuted = willMute);
        widget.onMuteChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willMute
                  ? '@${widget.username} stumm geschaltet'
                  : '@${widget.username} nicht mehr stumm',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
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

  void _reportUser() {
    Navigator.pop(context);
    ReportSheet.show(
      context,
      targetType: 'user',
      targetId: widget.userId,
      targetLabel: '@${widget.username}',
      community: widget.community,
      accentColor: widget.accentColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);
    final faint = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Text(
                    '@${widget.username}',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: mutedColor),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: faint),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              // Block
              ListTile(
                onTap: _toggleBlock,
                leading: Icon(
                  _isBlocked
                      ? Icons.person_add_rounded
                      : Icons.block_rounded,
                  color: _isBlocked ? Colors.green : Colors.red.shade400,
                  size: 24,
                ),
                title: Text(
                  _isBlocked ? 'Entblocken' : 'Blockieren',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _isBlocked ? Colors.green : Colors.red.shade400,
                  ),
                ),
                subtitle: Text(
                  _isBlocked
                      ? 'Nutzer kann deine Inhalte wieder sehen'
                      : 'Beiträge, Stories und Profil werden gegenseitig verborgen',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: mutedColor,
                  ),
                ),
              ),

              // Mute
              if (widget.community != null)
                ListTile(
                  onTap: _toggleMute,
                  leading: Icon(
                    _isMuted
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: _isMuted
                        ? widget.accentColor
                        : Colors.orange.shade400,
                    size: 24,
                  ),
                  title: Text(
                    _isMuted ? 'Stummschaltung aufheben' : 'Stumm schalten',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    _isMuted
                        ? 'Beiträge werden wieder im Feed angezeigt'
                        : 'Beiträge werden aus dem Feed ausgeblendet',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: mutedColor,
                    ),
                  ),
                ),

              Divider(height: 1, color: faint),

              // Report
              ListTile(
                onTap: _reportUser,
                leading: Icon(Icons.flag_rounded,
                    color: Colors.red.shade400, size: 24),
                title: Text(
                  'Nutzer melden',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade400,
                  ),
                ),
                subtitle: Text(
                  'Verstöße gegen Richtlinien melden',
                  style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                ),
              ),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
