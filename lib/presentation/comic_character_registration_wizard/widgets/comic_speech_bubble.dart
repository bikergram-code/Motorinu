import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Comic bubbles should stay WHITE, independent of dark/light theme.
/// Your app theme uses dark surfaces (premium black), so we force white fill here.
class ComicSpeechBubble extends StatefulWidget {
  final String text;
  final bool tailOnRight;

  /// Opacity of the white bubble fill.
  final double opacity;

  /// Visual shift downwards (overlay look). Positive values move bubble down.
  final double overlayShiftY;

  /// Optional overrides.
  final Color? bubbleColor;
  final Color? borderColor;

  /// Extra padding inside the bubble.
  final EdgeInsets padding;

  // --- Interactivity (backward compatible) ---
  /// When enabled, the bubble shows a typewriter animation.
  /// Defaults to true (this restores the previous interactive feel).
  final bool enableTypewriter;

  /// Time between typing ticks.
  final Duration typingSpeed;

  /// Automatically start typing when the widget appears.
  final bool autoStart;

  /// Tap to immediately show the full text while typing.
  final bool tapToSkip;

  /// Upper bound for the whole typing animation. If the text is long,
  /// we type multiple characters per tick so it still completes quickly.
  final Duration maxTypingDuration;

  const ComicSpeechBubble({
    super.key,
    required this.text,
    this.tailOnRight = true,
    this.opacity = 0.95,
    this.overlayShiftY = 26.0,
    this.bubbleColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.enableTypewriter = true,
    this.typingSpeed = const Duration(milliseconds: 16),
    this.autoStart = true,
    this.tapToSkip = true,
    this.maxTypingDuration = const Duration(milliseconds: 3200),
  });

  @override
  State<ComicSpeechBubble> createState() => _ComicSpeechBubbleState();
}

class _ComicSpeechBubbleState extends State<ComicSpeechBubble> {
  Timer? _timer;
  int _visibleUnits = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reset(start: widget.autoStart);
  }

  @override
  void didUpdateWidget(covariant ComicSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.enableTypewriter != widget.enableTypewriter ||
        oldWidget.typingSpeed != widget.typingSpeed ||
        oldWidget.maxTypingDuration != widget.maxTypingDuration ||
        oldWidget.autoStart != widget.autoStart) {
      _reset(start: widget.autoStart);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset({required bool start}) {
    _timer?.cancel();
    _visibleUnits = widget.enableTypewriter ? 0 : widget.text.length;
    _done = !widget.enableTypewriter;
    if (widget.enableTypewriter && start) {
      _startTyping();
    }
    if (mounted) setState(() {});
  }

  void _startTyping() {
    _timer?.cancel();

    final fullLen = widget.text.length;
    if (fullLen <= 0) {
      _done = true;
      return;
    }

    final tickMs = widget.typingSpeed.inMilliseconds.clamp(1, 1000);
    final maxMs = widget.maxTypingDuration.inMilliseconds.clamp(100, 20000);
    final approxTotal = fullLen * tickMs;
    final charsPerTick = math.max(1, (approxTotal / maxMs).ceil());

    _timer = Timer.periodic(Duration(milliseconds: tickMs), (t) {
      if (!mounted) return;
      if (_visibleUnits >= fullLen) {
        _visibleUnits = fullLen;
        _done = true;
        t.cancel();
        setState(() {});
        return;
      }
      _visibleUnits = math.min(fullLen, _visibleUnits + charsPerTick);
      setState(() {});
    });
  }

  void _revealAll() {
    _timer?.cancel();
    _visibleUnits = widget.text.length;
    _done = true;
    if (mounted) setState(() {});
  }

  String _safePrefix(String s, int end) {
    end = end.clamp(0, s.length);
    if (end <= 0) return '';

    // Avoid splitting UTF-16 surrogate pairs.
    final last = s.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) {
      end = math.max(0, end - 1);
    }
    return s.substring(0, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fill = (widget.bubbleColor ?? Colors.white).withOpacity(widget.opacity);
    final border = (widget.borderColor ?? Colors.black).withOpacity(0.18);

    final visibleText = widget.enableTypewriter
        ? _safePrefix(widget.text, _visibleUnits)
        : widget.text;

    final textStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: Colors.black87,
      height: 1.12,
    );

    final bubble = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: fill,
        // More "comic" than a simple rounded rect
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(0.25),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Reserve final layout size to avoid jumpy reflows while typing.
          Opacity(
            opacity: 0.0,
            child: Text(widget.text, style: textStyle),
          ),
          Text(
            visibleText,
            style: textStyle,
          ),
        ],
      ),
    );

    // Tail: rounded "speech pointer"
    final tail = Transform.rotate(
      angle: widget.tailOnRight ? 0.35 : -0.35,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    final content = Transform.translate(
      offset: Offset(0, widget.overlayShiftY),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubble,
          Positioned(
            right: widget.tailOnRight ? 26 : null,
            left: widget.tailOnRight ? null : 26,
            bottom: -10,
            child: tail,
          ),
        ],
      ),
    );

    if (!widget.enableTypewriter || !widget.tapToSkip) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_done) {
          _revealAll();
        }
      },
      onLongPress: () {
        // Replay the typewriter (nice for "interactive" feel) without changing any business logic.
        _reset(start: true);
      },
      child: content,
    );
  }
}

/// Thought bubble (rounded like before) + comic dots.
/// Used for hints/warnings (e.g. NameStep).
class ComicThoughtBubble extends StatefulWidget {
  final String text;

  /// Back-compat: NameStep passes textStyle (optional).
  final TextStyle? textStyle;

  final Color textColor;
  final double opacity;

  /// Keep default at 0 for thought bubbles (they are usually positioned via Positioned()).
  final double overlayShiftY;

  /// Dots on right = dots point to the character on the right side.
  final bool dotsOnRight;

  /// Back-compat: NameStep passes padding.
  final EdgeInsets padding;

  /// Optional overrides.
  final Color? bubbleColor;
  final Color? borderColor;

  /// Roundedness of the bubble body (comic look).
  final double radius;

  /// Width of the bubble body (helps consistent positioning). Set null for auto width.
  final double? bubbleWidth;

  // --- Interactivity ---
  /// Enable typewriter animation for thought bubbles too.
  /// Default true to match the older interactive feel.
  final bool enableTypewriter;
  final Duration typingSpeed;
  final bool autoStart;
  final bool tapToSkip;
  final Duration maxTypingDuration;

  const ComicThoughtBubble({
    super.key,
    required this.text,
    this.textStyle,
    this.textColor = Colors.redAccent,
    this.opacity = 0.95,
    this.overlayShiftY = 0.0,
    this.dotsOnRight = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.bubbleColor,
    this.borderColor,
    this.radius = 28,
    this.bubbleWidth,
    this.enableTypewriter = true,
    this.typingSpeed = const Duration(milliseconds: 16),
    this.autoStart = true,
    this.tapToSkip = true,
    this.maxTypingDuration = const Duration(milliseconds: 2200),
  });

  @override
  State<ComicThoughtBubble> createState() => _ComicThoughtBubbleState();
}

class _ComicThoughtBubbleState extends State<ComicThoughtBubble> {
  Timer? _timer;
  int _visibleUnits = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reset(start: widget.autoStart);
  }

  @override
  void didUpdateWidget(covariant ComicThoughtBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.enableTypewriter != widget.enableTypewriter ||
        oldWidget.typingSpeed != widget.typingSpeed ||
        oldWidget.maxTypingDuration != widget.maxTypingDuration ||
        oldWidget.autoStart != widget.autoStart) {
      _reset(start: widget.autoStart);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset({required bool start}) {
    _timer?.cancel();
    _visibleUnits = widget.enableTypewriter ? 0 : widget.text.length;
    _done = !widget.enableTypewriter;
    if (widget.enableTypewriter && start) {
      _startTyping();
    }
    if (mounted) setState(() {});
  }

  void _startTyping() {
    _timer?.cancel();
    final fullLen = widget.text.length;
    if (fullLen <= 0) {
      _done = true;
      return;
    }

    final tickMs = widget.typingSpeed.inMilliseconds.clamp(1, 1000);
    final maxMs = widget.maxTypingDuration.inMilliseconds.clamp(100, 20000);
    final approxTotal = fullLen * tickMs;
    final charsPerTick = math.max(1, (approxTotal / maxMs).ceil());

    _timer = Timer.periodic(Duration(milliseconds: tickMs), (t) {
      if (!mounted) return;
      if (_visibleUnits >= fullLen) {
        _visibleUnits = fullLen;
        _done = true;
        t.cancel();
        setState(() {});
        return;
      }
      _visibleUnits = math.min(fullLen, _visibleUnits + charsPerTick);
      setState(() {});
    });
  }

  void _revealAll() {
    _timer?.cancel();
    _visibleUnits = widget.text.length;
    _done = true;
    if (mounted) setState(() {});
  }

  String _safePrefix(String s, int end) {
    end = end.clamp(0, s.length);
    if (end <= 0) return '';
    final last = s.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) {
      end = math.max(0, end - 1);
    }
    return s.substring(0, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fill = (widget.bubbleColor ?? Colors.white).withOpacity(widget.opacity);
    final border = (widget.borderColor ?? Colors.black).withOpacity(0.18);

    final defaultStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w900,
      color: widget.textColor,
      height: 1.12,
    );

    final finalStyle = (widget.textStyle ?? defaultStyle);
    final visibleText = widget.enableTypewriter
        ? _safePrefix(widget.text, _visibleUnits)
        : widget.text;

    final body = Container(
      padding: widget.padding,
      constraints: BoxConstraints(
        minWidth: 160,
        maxWidth: widget.bubbleWidth ?? 260,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(0.25),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: 0.0,
            child: Text(widget.text, textAlign: TextAlign.center, style: finalStyle),
          ),
          Text(
            visibleText,
            textAlign: TextAlign.center,
            style: finalStyle,
          ),
        ],
      ),
    );

    Widget dot(double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
        );

    // 4 comic dots (bigger -> smaller), arranged diagonally downwards.
    // Right-side dots use "right:" positioning; left-side dots use "left:".
    final dots = <Widget>[
      Positioned(
        right: widget.dotsOnRight ? -10 : null,
        left: widget.dotsOnRight ? null : -10,
        bottom: -6,
        child: dot(16),
      ),
      Positioned(
        right: widget.dotsOnRight ? -24 : null,
        left: widget.dotsOnRight ? null : -24,
        bottom: -22,
        child: dot(12),
      ),
      Positioned(
        right: widget.dotsOnRight ? -36 : null,
        left: widget.dotsOnRight ? null : -36,
        bottom: -34,
        child: dot(9),
      ),
      Positioned(
        right: widget.dotsOnRight ? -46 : null,
        left: widget.dotsOnRight ? null : -46,
        bottom: -44,
        child: dot(7),
      ),
    ];

    final content = Transform.translate(
      offset: Offset(0, widget.overlayShiftY),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          ...dots,
        ],
      ),
    );

    if (!widget.enableTypewriter || !widget.tapToSkip) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_done) {
          _revealAll();
        }
      },
      onLongPress: () {
        _reset(start: true);
      },
      child: content,
    );
  }
}
