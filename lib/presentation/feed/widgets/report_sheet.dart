import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/core/providers.dart';

/// Bottom sheet for reporting posts, users, or comments.
/// Shows a list of reasons and optional details text field.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetLabel,
    this.community,
    this.accentColor = const Color(0xFFFF6B35),
  });

  /// 'post', 'user', 'comment'
  final String targetType;
  final String targetId;
  final String? targetLabel;
  final String? community;
  final Color accentColor;

  /// Show the report sheet.
  static Future<bool?> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    String? targetLabel,
    String? community,
    Color accentColor = const Color(0xFFFF6B35),
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
        community: community,
        accentColor: accentColor,
      ),
    );
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSending = false;

  static const _reasons = [
    ('spam', 'Spam', Icons.report_gmailerrorred_rounded),
    ('harassment', 'Belästigung', Icons.person_off_rounded),
    ('hate_speech', 'Hassrede', Icons.speaker_notes_off_rounded),
    ('violence', 'Gewalt', Icons.dangerous_rounded),
    ('nudity', 'Nacktheit / Sexuelle Inhalte', Icons.visibility_off_rounded),
    ('misinformation', 'Falschinformationen', Icons.fact_check_rounded),
    ('copyright', 'Urheberrechtsverletzung', Icons.copyright_rounded),
    ('other', 'Sonstiges', Icons.more_horiz_rounded),
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _isSending = true);

    try {
      final repo = ref.read(moderationRepositoryProvider);

      switch (widget.targetType) {
        case 'post':
          await repo.reportPost(
            postId: int.parse(widget.targetId),
            reason: _selectedReason!,
            details: _detailsController.text.trim().isNotEmpty
                ? _detailsController.text.trim()
                : null,
            community: widget.community,
          );
          break;
        case 'user':
          await repo.reportUser(
            targetUserId: widget.targetId,
            reason: _selectedReason!,
            details: _detailsController.text.trim().isNotEmpty
                ? _detailsController.text.trim()
                : null,
            community: widget.community,
          );
          break;
        case 'comment':
          await repo.reportComment(
            commentId: int.parse(widget.targetId),
            reason: _selectedReason!,
            details: _detailsController.text.trim().isNotEmpty
                ? _detailsController.text.trim()
                : null,
            community: widget.community,
          );
          break;
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Meldung gesendet. Wir prüfen das so schnell wie möglich.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        // Check for duplicate report
        if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Du hast dies bereits gemeldet.',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e', style: GoogleFonts.inter(fontSize: 13)),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final typeLabel = switch (widget.targetType) {
      'post' => 'Beitrag',
      'user' => 'Nutzer',
      'comment' => 'Kommentar',
      _ => 'Inhalt',
    };

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, color: Colors.red.shade400, size: 22),
                const SizedBox(width: 10),
                Text(
                  '$typeLabel melden',
                  style: GoogleFonts.inter(
                    fontSize: 18,
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

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Warum möchtest du diesen $typeLabel melden?',
              style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
            ),
          ),

          Divider(height: 1, color: faint),

          // Reasons list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final (value, label, icon) in _reasons)
                  _buildReasonTile(value, label, icon, textColor, mutedColor),

                // Details text field (visible when reason is selected)
                if (_selectedReason != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Details (optional)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _detailsController,
                      maxLines: 3,
                      maxLength: 500,
                      style: GoogleFonts.inter(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Beschreibe das Problem genauer...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: textColor.withValues(alpha: 0.2),
                        ),
                        filled: true,
                        fillColor: textColor.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Submit button
          if (_selectedReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Meldung absenden',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReasonTile(
    String value,
    String label,
    IconData icon,
    Color textColor,
    Color mutedColor,
  ) {
    final isSelected = _selectedReason == value;
    return ListTile(
      onTap: () => setState(() => _selectedReason = value),
      leading: Icon(
        icon,
        size: 22,
        color: isSelected ? Colors.red.shade400 : mutedColor,
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? textColor : textColor.withValues(alpha: 0.75),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded,
              color: Colors.red.shade400, size: 22)
          : Icon(Icons.circle_outlined,
              color: textColor.withValues(alpha: 0.12), size: 22),
      dense: true,
    );
  }
}
