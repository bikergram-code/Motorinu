import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Clean, modern reward badge:
/// - big readable icon
/// - tier colors
/// - NO tiny text inside (user asked to remove seal text)
class RewardBadgeIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final String tierLabel; // used only to pick colors

  const RewardBadgeIcon({
    super.key,
    required this.icon,
    required this.tierLabel,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _tierFromLabel(tierLabel);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BadgePainter(tier: tier),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.48,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  final _Tier tier;

  _BadgePainter({required this.tier});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);

    // shadow
    canvas.drawCircle(
      Offset(cx, cy + r * 0.08),
      r * 0.92,
      Paint()..color = const Color(0xAA000000),
    );

    // outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.92,
      Paint()..color = const Color(0xFF0B0B0D),
    );

    // glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [tier.glow.withOpacity(0.45), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.92, glowPaint);

    // white ring
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.74,
      Paint()..color = const Color(0xFFF5F5F5),
    );

    // colored core
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.62,
      Paint()..color = tier.core,
    );

    // highlight
    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.22), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy - r * 0.18), radius: r));
    canvas.drawCircle(Offset(cx, cy), r * 0.62, highlight);

    // inner ring for depth
    canvas.drawCircle(Offset(cx, cy), r * 0.46, Paint()..color = Colors.black.withOpacity(0.20));
    canvas.drawCircle(Offset(cx, cy), r * 0.42, Paint()..color = Colors.white.withOpacity(0.08));
  }

  @override
  bool shouldRepaint(covariant _BadgePainter oldDelegate) => oldDelegate.tier != tier;
}

enum _Tier { bronze, silver, gold, carbon, inferno }

_Tier _tierFromLabel(String label) {
  switch (label) {
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

extension on _Tier {
  Color get core {
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
