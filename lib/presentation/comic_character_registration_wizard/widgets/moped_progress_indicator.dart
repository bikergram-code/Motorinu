import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// A compact progress indicator used at the top of the comic registration wizard.
///
/// Fixes: prevents "BoxConstraints forces an infinite height" by always giving the
/// internal Stack a finite height via SizedBox.
class MopedProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const MopedProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Finite height is CRITICAL: without this, Stack/Positioned can receive h=Infinity
    // depending on parent constraints.
    final double barHeight = (6.0).h.clamp(44.0, 72.0);

    final int denom = (totalSteps - 1) <= 0 ? 1 : (totalSteps - 1);
    final double progress = (currentStep / denom).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      child: SizedBox(
        height: barHeight,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            // Make the moped knob visibly bigger.
            final double knobSize = (barHeight * 0.86).clamp(30.0, 56.0);
            final double knobX = (w - knobSize) * progress;

            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(barHeight),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.6),
                      ),
                    ),
                  ),
                ),

                // Filled progress
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: w * progress,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(barHeight),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),

                // BIKERGRAM text overlay (reveals with progress)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final p = progress.clamp(0.0, 1.0);

                      final text = SizedBox(
                        width: w,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'BIKERGRAM',
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      );

                      return ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: p,
                          child: text,
                        ),
                      );
                    },
                  ),
                ),

// Knob / icon
                Positioned(
                  left: knobX,
                  top: (barHeight - knobSize) / 2,
                  width: knobSize,
                  height: knobSize,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                          color: Colors.black.withOpacity(0.18),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        size: (knobSize * 0.68).clamp(18.0, 36.0),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                // Step text (right)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '${(currentStep + 1).clamp(1, totalSteps)} / $totalSteps',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
