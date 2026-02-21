import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vector "test seal" badge (no assets).
/// v4: optional icon overlay (trophy/medal/fire etc.) to make levels instantly recognizable.
class RewardSeal extends StatelessWidget {
  final String label;
  final double size;
  final bool compact;

  /// If true, paints an icon badge on top-right of the seal.
  final bool showIcon;
  final IconData? icon;

  const RewardSeal({
    super.key,
    required this.label,
    this.size = 72,
    this.compact = false,
    this.showIcon = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final seal = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RewardSealPainter(label: label, compact: compact),
      ),
    );

    if (!showIcon || icon == null) return seal;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        seal,
        Positioned(
          right: -2,
          top: -2,
          child: _IconBadge(icon: icon!, diameter: size * 0.36),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double diameter;

  const _IconBadge({required this.icon, required this.diameter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.65),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.35),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: diameter * 0.52),
      ),
    );
  }
}

class _RewardSealPainter extends CustomPainter {
  final String label;
  final bool compact;

  _RewardSealPainter({required this.label, required this.compact});

  _Tier _tierForLabel(String l) {
    switch (l) {
      case 'Baby Biker':
      case 'Pocket Rocket':
      case 'Moped Rebell':
        return _Tier.bronze;
      case 'Road Ready':
      case 'Asphalt Junkie':
        return _Tier.silver;
      case 'Touren König':
      case 'Asphalt Veteran':
        return _Tier.gold;
      case 'Oldschool Legend':
        return _Tier.carbon;
      case 'Hardcore Biker':
      case 'Grabsteher Biker':
        return _Tier.inferno;
      default:
        return _Tier.silver;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);

    const outer = Color(0xFF0B0B0D);
    const ring = Color(0xFFF5F5F5);
    const shadow = Color(0xAA000000);

    final tier = _tierForLabel(label);
    final inner = tier.inner;
    final glow = tier.glow;

    // Shadow
    canvas.drawCircle(Offset(cx, cy + r * 0.06), r * 0.92, Paint()..color = shadow);

    // Outer jagged edge
    final spikes = compact ? 18 : 22;
    final path = Path();
    for (int i = 0; i < spikes; i++) {
      final a0 = (i / spikes) * math.pi * 2;
      final a1 = ((i + 0.5) / spikes) * math.pi * 2;
      final a2 = ((i + 1) / spikes) * math.pi * 2;

      final p0 = Offset(cx + math.cos(a0) * r * 0.92, cy + math.sin(a0) * r * 0.92);
      final p1 = Offset(cx + math.cos(a1) * r * 0.80, cy + math.sin(a1) * r * 0.80);
      final p2 = Offset(cx + math.cos(a2) * r * 0.92, cy + math.sin(a2) * r * 0.92);

      if (i == 0) path.moveTo(p0.dx, p0.dy);
      path.lineTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = outer);

    // Glow ring
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glow.withOpacity(0.35), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.86, glowPaint);

    // White ring + colored center
    canvas.drawCircle(Offset(cx, cy), r * 0.70, Paint()..color = ring);
    canvas.drawCircle(Offset(cx, cy), r * 0.58, Paint()..color = inner);

    // Highlight
    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.20), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy - r * 0.14), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.58, highlight);

    if (compact) {
      // Minimal inner detail (no tiny text)
      canvas.drawCircle(Offset(cx, cy), r * 0.42, Paint()..color = Colors.black.withOpacity(0.22));
      canvas.drawCircle(Offset(cx, cy), r * 0.38, Paint()..color = Colors.white.withOpacity(0.10));
      return;
    }

    // Text (normal mode)
    const topText = 'TEST-SIEGEL';
    const yearText = '2026';

    String main = label.trim();
    if (main.length > 14 && main.contains(' ')) {
      final parts = main.split(' ');
      final mid = (parts.length / 2).ceil();
      main = parts.take(mid).join(' ') + '\n' + parts.skip(mid).join(' ');
    }

    final topPainter = TextPainter(
      text: TextSpan(
        text: topText,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: r * 0.17,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: r * 1.1);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: main.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: r * 0.16,
          height: 1.02,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: r * 1.15);

    final yearPainter = TextPainter(
      text: TextSpan(
        text: yearText,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontWeight: FontWeight.w900,
          fontSize: r * 0.17,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: r * 0.95);

    topPainter.paint(canvas, Offset(cx - topPainter.width / 2, cy - r * 0.48));
    labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, cy - labelPainter.height / 2));
    yearPainter.paint(canvas, Offset(cx - yearPainter.width / 2, cy + r * 0.30));
  }

  @override
  bool shouldRepaint(covariant _RewardSealPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.compact != compact;
}

enum _Tier { bronze, silver, gold, carbon, inferno }

extension on _Tier {
  Color get inner {
    switch (this) {
      case _Tier.bronze:
        return const Color(0xFFB45309);
      case _Tier.silver:
        return const Color(0xFF94A3B8);
      case _Tier.gold:
        return const Color(0xFFF59E0B);
      case _Tier.carbon:
        return const Color(0xFF111827);
      case _Tier.inferno:
        return const Color(0xFFE11D2E);
    }
  }

  Color get glow {
    switch (this) {
      case _Tier.bronze:
        return const Color(0xFFF97316);
      case _Tier.silver:
        return const Color(0xFFCBD5E1);
      case _Tier.gold:
        return const Color(0xFFFBBF24);
      case _Tier.carbon:
        return const Color(0xFF60A5FA);
      case _Tier.inferno:
        return const Color(0xFFFF3D00);
    }
  }
}
