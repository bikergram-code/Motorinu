import 'package:flutter/material.dart';

import 'typewriter_text.dart';

enum ComicDialogueBubbleType { speech, thought }

/// Comic-Sprechblase (UI) mit „Pop-In“ Animation + Typewriter Text.
/// Tipp auf die Blase: Text sofort anzeigen / erneut abspielen.
class ComicDialogueBubble extends StatefulWidget {
  final String message;
  final bool visible;

  /// Wenn true: Typewriter startet automatisch (Standard).
  /// Wenn false: Text wird sofort komplett angezeigt.
  final bool autoStart;

  /// speech = normale Sprechblase (Dreieck-Tail)
  /// thought = Gedankenblase (Punkte-Tail)
  final ComicDialogueBubbleType type;

  final EdgeInsets padding;
  final double tailWidth;
  final double radius;
  final Duration typingSpeed;

  const ComicDialogueBubble({
    super.key,
    required this.message,
    this.visible = true,
    this.autoStart = true,
    this.type = ComicDialogueBubbleType.speech,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 28, 14),
    this.tailWidth = 18,
    this.radius = 16,
    this.typingSpeed = const Duration(milliseconds: 16),
  });

  @override
  State<ComicDialogueBubble> createState() => _ComicDialogueBubbleState();
}

class _ComicDialogueBubbleState extends State<ComicDialogueBubble> {
  bool _showAll = false;
  int _replayNonce = 0;

  @override
  void initState() {
    super.initState();
    // Wenn autoStart=false, zeige Text sofort komplett.
    _showAll = !widget.autoStart;
  }

  @override
  void didUpdateWidget(covariant ComicDialogueBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sichtbarkeit aus -> kein Typewriter nötig
    if (!widget.visible) {
      _showAll = true;
      return;
    }

    // autoStart geändert -> ggf. Anzeige-Mode anpassen
    if (oldWidget.autoStart != widget.autoStart && oldWidget.message == widget.message) {
      _showAll = !widget.autoStart;
      _replayNonce++;
    }

    // neue Nachricht -> Typewriter neu starten (oder sofort zeigen, wenn autoStart=false)
    if (oldWidget.message != widget.message) {
      _showAll = !widget.autoStart;
      _replayNonce++;
    }
  }

  void _onTap() {
    setState(() {
      if (!_showAll) {
        _showAll = true; // sofort zeigen
      } else {
        // Replay: Typewriter nochmal starten (nur wenn autoStart=true)
        if (widget.autoStart) {
          _showAll = false;
          _replayNonce++;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message.trim();
    if (!widget.visible || msg.isEmpty) return const SizedBox.shrink();

    final extraRight = widget.type == ComicDialogueBubbleType.speech ? widget.tailWidth : 0.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: 1.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1.0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: CustomPaint(
            painter: _SpeechBubblePainter(
              radius: widget.radius,
              tailWidth: widget.tailWidth,
              type: widget.type,
            ),
            child: Padding(
              padding: widget.padding.copyWith(right: widget.padding.right + extraRight),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Colors.black,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypewriterText(
                      key: ValueKey('tw:${_replayNonce}_$msg'),
                      text: msg,
                      enabled: widget.autoStart && !_showAll,
                      durationPerChar: widget.typingSpeed,
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: 0.55,
                      child: Text(
                        widget.autoStart
                            ? (_showAll ? 'Tippen = nochmal abspielen' : 'Tippen = sofort anzeigen')
                            : 'Tippen = keine Animation',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Circle {
  final Offset center;
  final double radius;
  const _Circle(this.center, this.radius);
}

class _SpeechBubblePainter extends CustomPainter {
  final double radius;
  final double tailWidth;
  final ComicDialogueBubbleType type;

  _SpeechBubblePainter({
    required this.radius,
    required this.tailWidth,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius;
    final tw = tailWidth;
    final tailSpace = type == ComicDialogueBubbleType.speech ? tw : 0.0;

    final rect = Rect.fromLTWH(0, 0, size.width - tailSpace, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    final path = Path()..addRRect(rrect);

    if (type == ComicDialogueBubbleType.speech) {
      // Tail rechts (kleines Dreieck)
      final tailBaseY = size.height * 0.62;
      final tailHalf = tw * 0.38;
      path.moveTo(size.width - tw, tailBaseY);
      path.lineTo(size.width, tailBaseY - tailHalf);
      path.lineTo(size.width - tw, tailBaseY + tailHalf);
      path.close();
    }

    // Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.25), 6, true);

    // Fill
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawPath(path, fill);

    // Border (Comic Line)
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.black;
    canvas.drawPath(path, stroke);

    if (type == ComicDialogueBubbleType.thought) {
      // "Gedanken"-Tail: 3 Punkte rechts-unten
      final cx = rect.right;
      final cy = rect.bottom - r * 0.55;
      final circles = <_Circle>[
        _Circle(Offset(cx + 6, cy + 10), 3),
        _Circle(Offset(cx + 12, cy + 18), 5),
        _Circle(Offset(cx + 20, cy + 28), 7),
      ];

      for (final c in circles) {
        final p = Path()..addOval(Rect.fromCircle(center: c.center, radius: c.radius));
        canvas.drawShadow(p, Colors.black.withOpacity(0.22), 4, true);
        canvas.drawCircle(c.center, c.radius, fill);
        canvas.drawCircle(c.center, c.radius, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.tailWidth != tailWidth ||
        oldDelegate.type != type;
  }
}
