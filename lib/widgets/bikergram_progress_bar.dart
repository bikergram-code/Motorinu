import 'package:flutter/material.dart';

class BikergramProgressBar extends StatelessWidget {
  final double progress;
  final double height;

  const BikergramProgressBar({
    super.key,
    required this.progress,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    final double barHeight = height;
    final double mopedSize = barHeight * 1.3; // +30%

    return SizedBox(
      height: barHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(barHeight / 2),
              ),
            ),
          ),
          Positioned(
            left: (progress.clamp(0.0, 1.0) * MediaQuery.of(context).size.width)
                .clamp(0.0, MediaQuery.of(context).size.width - mopedSize),
            child: Image.asset(
              'assets/icons/moped.png',
              width: mopedSize,
              height: mopedSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
