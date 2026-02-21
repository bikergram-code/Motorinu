import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Minimal-Animation ohne externe Libs:
/// - leichtes "Bobbing" (hoch/runter)
/// - zeigt ein PNG aus assets/images/
///
/// Lege z.B. diese Datei an:
/// assets/images/bikerin_idle.png
class AnimatedBikerCharacter extends StatefulWidget {
  final String assetPath;
  final double height;

  const AnimatedBikerCharacter({
    super.key,
    required this.assetPath,
    this.height = 220,
  });

  @override
  State<AnimatedBikerCharacter> createState() => _AnimatedBikerCharacterState();
}

class _AnimatedBikerCharacterState extends State<AnimatedBikerCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // leichte Bewegung: -6px..+6px
        final t = _c.value;
        final dy = math.sin(t * math.pi) * 6;

        return Transform.translate(
          offset: Offset(0, -dy),
          child: child,
        );
      },
      child: Image.asset(
        widget.assetPath,
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) {
          // Fallback falls Asset noch fehlt
          return Container(
            height: widget.height,
            alignment: Alignment.center,
            child: const Text(
              '👱‍♀️📝',
              style: TextStyle(fontSize: 72),
            ),
          );
        },
      ),
    );
  }
}
