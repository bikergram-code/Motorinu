import 'package:flutter/widgets.dart';
import 'package:characters/characters.dart';

/// Leichtgewichtiger Typewriter-Text über AnimationController (keine Timer).
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool enabled;
  final Duration durationPerChar;
  final int maxCharsForTypewriter;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.durationPerChar = const Duration(milliseconds: 20),
    this.maxCharsForTypewriter = 220,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _count;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final textLen = widget.text.characters.length;
    final safeLen = textLen.clamp(0, widget.maxCharsForTypewriter);
    final duration = Duration(milliseconds: safeLen * widget.durationPerChar.inMilliseconds);

    _controller = AnimationController(vsync: this, duration: duration);
    _count = StepTween(begin: 0, end: safeLen).animate(_controller);

    if (widget.enabled && safeLen > 0) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.enabled != widget.enabled) {
      _controller.dispose();
      _init();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.text.characters.length > widget.maxCharsForTypewriter) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final len = _count.value;
        final shown = widget.text.characters.take(len).toString();
        return Text(shown, style: widget.style);
      },
    );
  }
}
