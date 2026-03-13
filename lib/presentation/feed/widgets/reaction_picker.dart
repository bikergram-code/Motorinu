import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Available reaction types with emoji and German label.
enum ReactionType {
  fire('fire', '🔥', 'Feuer'),
  love('love', '❤️', 'Liebe'),
  laugh('laugh', '😂', 'Haha'),
  motorcycle('motorcycle', '🏍️', 'Motorrad'),
  thumbsUp('thumbs_up', '👍', 'Top'),
  wow('wow', '😮', 'Wow');

  const ReactionType(this.value, this.emoji, this.label);
  final String value;
  final String emoji;
  final String label;

  static ReactionType? fromValue(String? value) {
    if (value == null) return null;
    return ReactionType.values.where((r) => r.value == value).firstOrNull;
  }
}

/// Shows a floating reaction picker overlay near the given anchor position.
/// Returns the selected [ReactionType], or `null` if dismissed.
class ReactionPicker {
  ReactionPicker._();

  static void show(
    BuildContext context, {
    required Offset anchorPosition,
    required Color accentColor,
    String? currentReaction,
    required void Function(String? reactionType) onSelected,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ReactionPickerOverlay(
        anchorPosition: anchorPosition,
        accentColor: accentColor,
        currentReaction: currentReaction,
        onReactionSelected: (type) {
          entry.remove();
          onSelected(type);
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ReactionPickerOverlay extends StatefulWidget {
  const _ReactionPickerOverlay({
    required this.anchorPosition,
    required this.accentColor,
    required this.currentReaction,
    required this.onReactionSelected,
    required this.onDismiss,
  });

  final Offset anchorPosition;
  final Color accentColor;
  final String? currentReaction;
  final void Function(String? reactionType) onReactionSelected;
  final VoidCallback onDismiss;

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Track which emoji is being hovered/pressed
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate position — picker should appear above the anchor
    // Width of picker: ~320px for 6 emojis
    const pickerWidth = 320.0;
    const pickerHeight = 56.0;

    // Center horizontally relative to anchor, but clamp to screen bounds
    double left = widget.anchorPosition.dx - pickerWidth / 2;
    left = left.clamp(12.0, screenWidth - pickerWidth - 12.0);

    // Position above the anchor
    double top = widget.anchorPosition.dy - pickerHeight - 16;
    if (top < 40) top = widget.anchorPosition.dy + 40; // flip below if too high

    return Stack(
      children: [
        // Dismiss barrier
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Picker
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: pickerWidth,
                  height: pickerHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(ReactionType.values.length, (index) {
                      final reaction = ReactionType.values[index];
                      final isSelected =
                          widget.currentReaction == reaction.value;
                      final isHovered = _hoveredIndex == index;

                      return GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _hoveredIndex = index),
                        onTapUp: (_) {
                          setState(() => _hoveredIndex = null);
                          if (isSelected) {
                            // Deselect (remove reaction, keep regular like)
                            widget.onReactionSelected(null);
                          } else {
                            widget.onReactionSelected(reaction.value);
                          }
                        },
                        onTapCancel: () =>
                            setState(() => _hoveredIndex = null),
                        child: AnimatedScale(
                          scale: isHovered ? 1.5 : (isSelected ? 1.2 : 1.0),
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            decoration: isSelected
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.accentColor
                                        .withValues(alpha: 0.2),
                                  )
                                : null,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    reaction.emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  if (isHovered)
                                    Text(
                                      reaction.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Utility to get the emoji for a reaction type string.
String reactionEmoji(String? reactionType) {
  if (reactionType == null) return '';
  final r = ReactionType.fromValue(reactionType);
  return r?.emoji ?? '';
}

/// Get color for a reaction type (for the like icon tint).
Color reactionColor(String? reactionType) {
  switch (reactionType) {
    case 'fire':
      return const Color(0xFFFF6B35);
    case 'love':
      return Colors.red;
    case 'laugh':
      return const Color(0xFFFFC107);
    case 'motorcycle':
      return const Color(0xFF42A5F5);
    case 'thumbs_up':
      return const Color(0xFF42A5F5);
    case 'wow':
      return const Color(0xFFFF9800);
    default:
      return Colors.red;
  }
}
