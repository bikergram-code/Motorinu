import 'package:flutter/material.dart';

class BikergramCarbonBackground extends StatelessWidget {
  final Widget child;
  final String assetPath;
  final double opacity;

  const BikergramCarbonBackground({
    super.key,
    required this.child,
    this.assetPath = 'assets/images/carbon.png',
    this.opacity = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white54))),
        Container(color: Colors.black.withOpacity(1 - opacity)),
        child,
      ],
    );
  }
}
